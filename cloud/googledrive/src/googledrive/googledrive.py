from .util import command

py_googledrive = command.Commands(['auth', 'app'])

# import argparse
# import json
# import mimetypes
# import os
# import shlex
# import sys
# import textwrap

# def touch(args):
#     if args.mime is None:
#         args.mime, encoding = mimetypes.guess_type(args.file)
#         if args.mime is None:
#             raise ValueError('Unknown mime for {}'.format(args.file))
#     return requests.post(
#         'https://www.googleapis.com/drive/v3/files',
#         headers=args.auth({'Content-Type': args.mime}))

# class Drive(object):
#     def __init__(self, auth=None):
#         if auth is None:
#             self.auth = None
#         else:
#             self.auth = Auth(auth)

#     def bash_setup(self):
#         """Return a setup string.

#         choices: subs.choices from the subparsers.
#         """
#         setup = textwrap.dedent(r'''
#             drive() {
#                 if ! declare -p __PYDRIVE__ &>/dev/null
#                 then
#                     [[ "${1}" = exit ]] && return
#                     coproc __PYDRIVE__ { %REINITIALIZE% ; }
#                 fi
#                 local result
#                 { echo "${@@Q}"; read result; } >&${__PYDRIVE__[1]} <&${__PYDRIVE__[0]}
#                 return "${result:-1}"
#             }
#             __drive_completer() {
#                 COMPREPLY=()
#                 if ((${COMP_CWORD} == 1))
#                 then
#                     local choices=(%CHOICES%)
#                     local candidate
#                     for candidate in "${choices[@]}"
#                     do
#                         if [[ "${candidate}" = "${2}"* ]]
#                         then
#                             COMPREPLY+=("${candidate}")
#                         fi
#                     done
#                 fi
#             }
#             complete -F __drive_completer -o filenames -o default -o bashdefault drive
#             ''')
#         return setup.replace('%CHOICES%', ' '.join(
#             map(shlex.quote, self.parser()[1].choices))).replace(
#                 '%REINITIALIZE%', ' '.join(
#                     map(shlex.quote, [sys.executable, os.path.abspath(sys.argv[0]), '-r'])))

#     def setup(self):
#         shell = os.environ.get('SHELL', None)
#         if shell is None:
#             raise ValueError('Unrecognized shell')
#         func = getattr(self, os.path.basename(shell) + '_setup', None)
#         if func is None:
#             raise RuntimeError('Shell {} not supported'.format(shell))
#         else:
#             return func()


#     def run(self):
#         """Run the shell with custom commands."""
#         try:
#             out = sys.stdout
#             sys.stdout = sys.stderr

#             auth = self.auth
#             parser, subs = self.parser()

#             command = sys.stdin.readline()
#             while command:
#                 try:
#                     args = parser.parse_args(shlex.split(command))
#                 except SystemExit:
#                     print(1, file=out, flush=True)
#                 else:
#                     try:
#                         if auth is None:
#                             auth = getattr(args, 'auth', None)
#                         args.auth = auth
#                         response = args.func(args)
#                     except self.FinishedError:
#                         code = 0
#                     except Exception:
#                         traceback.print_exc()
#                         code = 1
#                     else:
#                         if response is None:
#                             code = 0
#                         else:
#                             print(response)
#                             try:
#                                 j = response.json()
#                             except Exception:
#                                 print(response.content.decode('utf-8', errors='replace'))
#                                 code = 1
#                             else:
#                                 print(json.dumps(j, indent=4))
#                                 code = int(response.status_code != 200)
#                     finally:
#                         print(code, file=out, flush=True)
#                 command = sys.stdin.readline()
#         finally:
#             sys.stdout = sys.__stdout__

#     class FinishedError(Exception):
#         pass
#     def finish(self, args):
#         raise self.FinishedError

#     def parser(self):
#         """Return (argparse.ArgumentParser, subparsers)."""
#         parser = argparse.ArgumentParser()
#         subs = parser.add_subparsers()

#         xit = subs.add_parser('exit')
#         xit.set_defaults(func=self.finish)

#         tst = subs.add_parser('tst')
#         tst.add_argument('x')
#         tst.add_argument('y')
#         tst.set_defaults(func=print)

#         return parser, subs

# if __name__ == '__main__':
#     p = argparse.ArgumentParser(description='print a sourceable script to setup.')
#     p.add_argument('auth', nargs='?')
#     p.add_argument('-r', '--run', action='store_true', help='run the program')
#     args = p.parse_args()
#     if args.run:
#         Drive(args.auth).run()
#     else:
#         print(Drive(args.auth).setup())
