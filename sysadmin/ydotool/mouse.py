import argparse
import time
import tkinter as tk
import sys
import traceback

import ydo

class Macro(object):
    """Class for outputting macro sequence."""
    def __init__(self, ydotool):
        self.ydotool = ydotool
        self.x = None
        self.y = None
        self.t = None
        self.r = None

        # Distinguish between X11 autorepeat or press/hold, then release
        self.kstate = {}

    def print_click(self, t):
        """Print a click command.

        click delay(ms)
        """
        print('click', int(t) - self.t)
        self.t = int(t)

    def parse_state(self, state, keysym):
        mods = []
        for idx, value in ((0, 'Shift'), (2, 'Control'), (17, 'Alt')):
            if state & (1 << idx):
                mods.append(value)
        mods.append(keysym)
        return mods

    def ignore(self, keysym):
        return any([keysym.startswith(_) for _ in ('Control', 'Shift', 'Alt')])

    def key_down(self, kcode, keysym, state, t):
        """Mouse button down."""
        try:
            if self.ignore(keysym):
                print('ignored down', keysym, file=sys.stderr)
                return
            if self.kstate.get(keysym, None) is None:
                print('keydown', '-'.join(self.parse_state(int(state), keysym)), int(t)-self.t)
                self.t = int(t)
            self.kstate[keysym] = 1
        except Exception:
            traceback.print_exc()

    def key_up(self, kcode, keysym, state, t):
        """Mouse button up."""
        try:
            if self.ignore(keysym):
                print('ignored release', keysym, file=sys.stderr)
                return
            self.kstate[keysym] = 0
            self.r.update()
            if not self.kstate[keysym]:
                print('keyup', '-'.join(self.parse_state(int(state), keysym)), int(t)-self.t)
                self.kstate[keysym] = None
                self.t = int(t)
        except Exception:
            traceback.print_exc()

    def print_move(self, x, y, t):
        """Print a move command.

        move x y delay(ms)
        """
        if self.t is not None:
            print('move', int(x), int(y), int(t) - self.t)
            self.t = int(t)


    def begin_macro(self, x, y, t):
        """Start mouse recording.

        Use ydotool to warp mouse into the last released position.
        """
        print('resume', x, y, t, file=sys.stderr)
        if self.x is None:
            self.x = int(x)
            self.y = int(y)
            self.t = int(t)
        else:
            previous = self.t
            self.t = None
            # TODO: change to checking version?
            self.ydotool.move(self.x, self.y, 'br', 0)
            self.t = previous

    def pause_macro(self, x, y):
        """Pause mouse recording."""
        print('pause', x, y, file=sys.stderr)
        self.x = int(x)
        self.y = int(y)

    def run(self):
        with ydo.NoMouseAccel():
            self.r = r = self.ydotool.pos.tk
            t = tk.Toplevel(r)
            t.bindtags((self.ydotool.pos.tk,) + t.bindtags())
            r.createcommand('print_click', self.print_click)
            r.createcommand('print_move', self.print_move)
            r.createcommand('begin_macro', self.begin_macro)
            r.createcommand('pause_macro', self.pause_macro)
            r.createcommand('key_up', self.key_up)
            r.createcommand('key_down', self.key_down)

            t.bind('<Control-space>', 'print_click %t')

            t.bind('<KeyPress>', 'key_down %k %K %s %t')
            t.bind('<KeyRelease>', 'key_up %k %K %s %t')


            t.bind('<B1-Motion>', 'print_move %X %Y %t')
            t.bind('<ButtonPress-1>', 'begin_macro %X %Y %t')
            t.bind('<ButtonRelease-1>', 'pause_macro %X %Y')
            t.bind('<Escape>', 'destroy ' + str(t))
            t.title('macro')
            t.wait_window()

def parse_time(timespec):
    """Parse time as seconds."""
    if timespec:
        parts = timespec.split(':')
        if len(parts) == 1:
            return float(parts[0]) * 60
        elif len(parts) == 2:
            return float(parts[0])*3600 + float(parts[1])*60
        else:
            return (
                float(parts[0])*3600
                + float(parts[1])*60
                + float(parts[2]))
    else:
        return 0

def run(args, ydotool):
    if args.record:
        Macro(ydotool).run()
    else:
        delay = parse_time(args.repeat)
        with open(args, 'r') as f:
            lines = f.readlines()
        while 1:
            if delay:
                time.sleep(delay)
            else:
                return


if __name__ == '__main__':
    p = argparse.ArgumentParser()
    p.add_argument('-r', '--record', help='record a script.', action='store_true')
    p.add_argument('-i', '--input', help='input file.')
    p.add_argument(
        '--repeat', default = '', help='repeat delay, SS, HH:MM, or HH:MM:SS (each can be float)'
    )
    args = p.parse_args()

    with ydo.ydotoold(verbose=False) as d:
        with ydo.ydotool(d.path) as ydotool:
            run(args, ydotool)
