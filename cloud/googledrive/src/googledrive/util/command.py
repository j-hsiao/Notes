import argparse
import os
import shlex
import sys
import textwrap
import traceback

class Command(object):
    def get_parser(self):
        p = argparse.ArgumentParser(add_help=False, formatter_class=argparse.ArgumentDefaultsHelpFormatter)
        p.set_defaults(func=self)
        p.add_argument('--current_working_dir')
        return p

    def __call__(self, args):
        """Handle parsed args and return success True/False."""
        raise NotImplementedError

class Exit(Command):
    def __init__(self):
        self.parser = self.get_parser()
    def __call__(self, args):
        sys.exit()

class Commands(object):
    """Manage commands."""
    def __init__(self, cache=None):
        """Initialize Commands.

        cache: a dict of cached values or a list of keys to cache.
        Cache will track the most recent non-None value for the
        given keys.
        """
        self.parser = p = argparse.ArgumentParser()
        self.sub = p.add_subparsers()
        if cache is None:
            self.cache = {}
        elif isinstance(cache, dict):
            self.cache = cache.copy()
        elif hasattr(cache, '__iter__'):
            self.cache = {_:None for _ in cache}
        else:
            raise ValueError('Bad cache value {}'.format(cache))
        self(Exit)

    def __call__(self, commandclass, *args, **kwargs):
        """Add a command class.  Use as a decorator"""
        inst = commandclass(*args, **kwargs)
        sub = self.sub.add_parser(commandclass.__name__.lower(), parents=[inst.parser])
        return commandclass

    def bash_setup(self, package, filename=None, flags=()):
        """Return a bash script to create a "drive" command to access drive apis.

        package: the __package__ for the __main__.py  The package should be run as __main__
                 for the apis.
        filename: the filename of the __main__.py to find the directory to set PYTHONPATH
                  if applicable.
        flags: sequence of str flags or single str flag to actually run.
        """
        command = []
        if filename is not None:
            os.path.dirname(filename)
            drivepath = os.path.join(
                os.path.dirname(filename),
                *['..' for _ in package.split('.')])
            pypath = os.environ.get('PYTHONPATH', None)
            if pypath:
                pypath = os.pathsep.join([drivepath, pypath])
            else:
                pypath = drivepath
            command.append('PYTHONPATH=' + pypath)
        script = textwrap.dedent(r'''
            drive() {{
                if ! declare -p __PY_GOOGLEDRIVE__ &>/dev/null
                then
                    [[ "${{1}}" = exit ]] && return
                    coproc __PY_GOOGLEDRIVE__ {{ {COMMAND} ;}}
                fi
                local result
                {{
                    printf '%q %s\n' "${{PWD}}" "${{*@Q}}"
                    while ! read -r -t 1 -u ${{__PY_GOOGLEDRIVE__[0]}} result
                    do
                        if read -t 0
                        then
                            read -r result
                            printf '%s\n' "${{result}}"
                        fi
                    done
                }} >&${{__PY_GOOGLEDRIVE__[1]}}
                return "${{result:-1}}"
            }}
            __drive_completer() {{
                COMPREPLY=()
                if ((${{COMP_CWORD}} == 1))
                then
                    local candidate
                    for candidate in {CHOICES}
                    do
                        if [[ "${{candidate}}" = "${{2}}"* ]]
                        then
                            COMPREPLY+=("${{candidate}}")
                        fi
                    done
                fi
            }}
            complete -F __drive_completer -o filenames -o default -o bashdefault drive
            ''')
        command.extend([sys.executable, '-m', package])
        if isinstance(flags, str):
            command.append(flags)
        else:
            command.extend(flags)
        return script.format(
            CHOICES=shlex.join(self.sub.choices),
            COMMAND=shlex.join(command),
        )

    def main(self, package, filename=None):
        p = argparse.ArgumentParser()
        p.add_argument('-r', '--run', action='store_true')
        args = p.parse_args()
        if args.run:
            self.run()
        else:
            shell = os.environ.get('SHELL', None)
            if shell is None:
                raise ValueError('Unknown shell')
            func = getattr(self, os.path.basename(shell) + '_setup', None)
            if func is None:
                raise RuntimeError('Shell {} is not supported.'.format(shell))
            else:
                print(func(package, filename, '-r'))

    def run(self):
        """Read commands from stdin and output result to stdout."""
        out = sys.stdout
        try:
            sys.stdout = sys.stderr
            command = sys.stdin.readline()
            try:
                while command:
                    print(
                        (0 if self.handle(command) else 1),
                        file=out, flush=True)
                    command = sys.stdin.readline()
            except SystemExit:
                print(0, file=out, flush=True)
                return
        finally:
            sys.stdout = out

    def handle(self, commandline):
        """Handle a commandline.  Return True/False successful or not."""
        parsed = shlex.split(commandline)
        if os.path.isdir(parsed[0]) and parsed[0].startswith('/'):
            os.chdir(parsed[0])
            parsed = parsed[1:]
        try:
            args = self.parser.parse_args(parsed)
        except SystemExit:
            return ('-h' in parsed) or ('--help' in parsed)
        for key, value in self.cache.items():
            argval = getattr(args, key, None)
            if argval is None:
                setattr(args, key, value)
        try:
            return args.func(args)
        except Exception:
            traceback.print_exc()
            return False
        finally:
            for key, value in self.cache.items():
                postval = getattr(args, key, None)
                if postval is not None:
                    self.cache[key] = postval
