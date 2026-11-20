import argparse
import ast
import logging
import os
import sys

import tomli
import tomli_w

lg = logging.getLogger(__name__)


def kv(item):
    """Split a key=value string into (key, value)."""
    key, value = item.split('=', 1)
    try:
        return key, ast.literal_eval(value)
    except (ValueError, SyntaxError):
        return key, value

def setup_logging(lvls):
    logging.basicConfig(
        stream=sys.stderr,
        format='%(asctime)s|%(name)s|%(levelname)s: %(message)s',
    )
    if not lvls:
        return
    for item in lvls.split(','):
        try:
            name, level = item.split('=', 1)
        except Exception:
            name = 'cyfy'
            level = item
        if not level:
            level = 'warning'
        level = level.upper()
        try:
            level = int(level)
        except ValueError:
            level = getattr(logging, level)
        logging.getLogger(name).setLevel(level)

def parser(**kwargs):
    kwargs.setdefault('formatter_class', argparse.ArgumentDefaultsHelpFormatter)
    p = argparse.ArgumentParser(**kwargs)
    p.add_argument('-o', '--out', help='out dir')
    p.add_argument('-n', '--name', help='package name, detect if absent.')
    p.add_argument('-v', '--version', help='package version. detect if absent.')
    p.add_argument('modules', nargs='+', help='modules to add or dir.')
    p.add_argument('-p', '--project', nargs='*', default=[], help='additional name=value for project section.', type=kv)
    p.add_argument('-d', '--dryrun', action='store_true', help='only print')
    p.add_argument('-l', '--loglevel', help='[name=]loglevel,...  Omitted name defaults to cyfy.')
    return p

def dget(dct, dotname, *default):
    try:
        for part in dotname.split('.'):
            dct = dct[part]
    except KeyError:
        if default:
            return default[0]
        raise KeyError('{}: {}'.format(dotname, part))
    else:
        return dct

def parse_toml(ret, path):
    try:
        with open(path, 'rb') as f:
            return {'toml': tomli.load(f)}
    except Exception:
        return {}

def parse_setup(ret, path):
    # TODO
    return {}


def is_root(path):
    return any([os.path.isfile(os.path.join(path, _)) for _ in ('pyproject.toml', 'setup.py')])
def find_root(path):
    path = os.path.abspath(path)
    if os.path.isdir(os.path.join(path, 'src')):
        srcdir = os.path.join(path, 'src')
        return dict(
            root=path,
            modules=[os.path.join(srcdir, _) for _ in os.listdir(srcdir)])
    if is_root(path):
        mdir = os.path.join(path, os.path.basename(path))
        if os.path.isdir(mdir):
            return dict(root=path, modules=[mdir])
        if os.path.isfile(mdir + '.py'):
            return dict(root=path, modules=[mdir + '.py'])
    dn = os.path.dirname(path)
    if is_root(dn):
        return dict(root=dn, modules=[path])
    parts = os.path.normpath(path).split(os.sep)
    if 'src' in parts:
        return find_root(os.sep.join(parts[:parts.index('src')]))
    return dict(modules=[path])

def find_info(path):
    ret = find_root(path)
    root = ret.get('root')
    if root is None:
        return ret
    ret = merge(ret, parse_toml(ret, os.path.join(root, 'pyproject.toml')))
    ret = merge(ret, parse_setup(ret, os.path.join(root, 'setup.py')))
    return ret

def merge(a, b):
    """Return merged result of and b."""
    if isinstance(a, list):
        ret = set(a)
        ret.update(b)
        return list(ret)
    elif isinstance(a, dict):
        ret = dict(a)
        for k, v in b.items():
            if k in ret:
                try:
                    ret[k] = merge(ret[k], v)
                except Exception:
                    raise ValueError('Merge {} failed: {} vs {}', k, ret[k], v)
            else:
                ret[k] = v
        return ret
    else:
        if a != b:
            raise ValueError('Invalid merge {} vs {}'.format(a, b))
        return a

def merged(key, dcts, *default):
    """Return key merged from seq of dicts."""
    ret = None
    start = False
    for item in dcts:
        try:
            v = dget(item, key)
        except KeyError:
            continue
        if start:
            ret = merge(ret, v)
        else:
            ret = v
            start = True
    if start:
        return ret
    elif default:
        return default[0]
    else:
        raise KeyError(key)

def calc_name(args, infos):
    if args.name:
        return args.name
    try:
        name = merged('project.name', infos)
        if name:
            return name
    except Exception:
        pass
    if len(infos) == 1:
        try:
            return os.path.basename(infos[0]['root'])
        except KeyError:
            pass
        if len(infos[0]['modules']) == 1:
            return os.path.basename(infos[0]['modules'][0]).split('.', 1)[0]
    raise ValueError('Ambiguous project name.')

def mkdir(dname):
    if not os.path.isdir(dname):
        try:
            os.makedirs(dname)
        except Exception:
            lg.exception('Failed to make dir %r', dname)

def mklink(src, dst):
    try:
        os.symlink(src, dst, os.path.isdir(src))
    except Exception:
        try:
            current = os.readlink(dst)
        except Exception:
            lg.error('symlink failed but readlink failed too.')
        else:
            if current != src:
                lg.error('link %r points to %r instead of %r', dst, current, src)

def handle_package(src, cydir, srcdir):
    """Walk through src and create dirs/links into corresponding dirs.

    Link files for cython compilation in cydir.
    Link data files in srcdir.
    """
    src = os.path.abspath(src)
    npre = len(src.split(os.sep))-1
    if os.path.isfile(src):
        mkdir(cydir)
        mklink(src, os.path.join(cydir, os.path.basename(src)))
        return

    for pkgpath, dns, fns in os.walk(src, followlinks=True):
        pkgp = pkgpath.split(os.sep)
        if '__pycache__' in pkgp or any([_.endswith('.egg_info') for _ in pkgp]):
            continue
        sub = pkgp[npre:]
        lg.info('Search package %s', sub)
        for fn in fns:
            if fn == '__main__.py':
                tgt = srcdir
            elif fn.endswith('.py') or fn.endswith('.pyx'):
                tgt = cydir
            elif fn.endswith('.pyc'):
                continue
            else:
                tgt = srcdir
            dname = os.path.join(tgt, *sub)
            mkdir(dname)
            mklink(os.path.join(pkgpath, fn), os.path.join(dname, fn))

def run(args=None):
    if args is None:
        args = parser().parse_args()

    setup_logging(args.loglevel)
    infos = [find_info(item) for item in args.modules]
    for md, info in zip(args.modules, infos):
        lg.debug('module: %r : %s', md, info)
    project_name = calc_name(args, infos)
    if not args.out:
        if not os.path.isdir(project_name):
            args.out = project_name
        else:
            lg.error('output exists: %r', project_name)
            return 1

    toml = merged('toml', infos, {})
    build_system = toml.setdefault('build-system', {})
    buildreqs = build_system.setdefault('requires', [])
    build_system.setdefault('build-backend', 'setuptools.build_meta')
    for req in ('setuptools', 'wheel', 'cython'):
        if req not in buildreqs:
            buildreqs.append(req)
    project = toml.setdefault('project', {})
    project['name'] = project_name
    if args.version is not None:
        project['version'] = args.version
    project.setdefault('version', '0.0.1')
    toml.setdefault('tool', {}).setdefault('distutils', {}).setdefault('egg_info', {}).setdefault('egg_base', '.egg')

    print('output    :', args.out, file=sys.stderr)
    for top, dct in toml.items():
        print(top, file=sys.stderr)
        for k,v in dct.items():
            print('   ', k, ':', v, file=sys.stderr)
    if args.dryrun:
        return

    eggbase = dget(toml, 'tool.distutils.egg_info.egg_base', None)
    if eggbase:
        mkdir(os.path.join(args.out, eggbase))

    cydir = os.path.join(args.out, 'cysrc')
    srcdir = os.path.join(args.out, 'src')
    mkdir(cydir)
    mkdir(srcdir)
    for info in infos:
        for item in info['modules']:
            handle_package(item, cydir, srcdir)
    with open(os.path.join(args.out, 'pyproject.toml'), 'wb') as f:
        tomli_w.dump(toml, f)
    with open(os.path.join(os.path.dirname(__file__), 'setup.template'), 'r') as sf:
        with open(os.path.join(args.out, 'setup.py'), 'w') as df:
            df.write(sf.read())
    return 0
