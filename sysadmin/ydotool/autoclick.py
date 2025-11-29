import argparse
import select

import ydo


p = argparse.ArgumentParser()
p.add_argument('-s', '--sock')
p.add_argument('-d', '--delay', help='delay between clicks', default=1, type=float)
args = p.parse_args()

prompt = 'Press return to toggle. Type exit to stop.'
with ydo.ydotoold(args.sock) as ydod:
    with ydo.Bash(sudo=True) as bash:
        bash.write(f'export YDOTOOL_SOCKET="{ydod}"')
        while input(prompt) not in ('exit', 'quit', 'q'):
            while not select.select([0], (), (), args.delay)[0]:
                bash.write('ydotool click 0xc0')
            if input() in ('exit', 'quit', 'q'):
                break
