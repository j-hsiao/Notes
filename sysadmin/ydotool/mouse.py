import argparse
import time
import tkinter as tk
import sys

import ydo

class Macro(object):
    """Class for outputting macro sequence."""
    def __init__(self, ydotool):
        self.ydotool = ydotool
        self.x = None
        self.y = None
        self.t = None

    def print_click(self, t):
        """Print a click command.

        click delay(ms)
        """
        print('click', int(t) - self.t)
        self.t = int(t)

    def print_move(self, x, y, t):
        """Print a move command.

        move x y delay(ms)
        """
        if self.t is None:
            if int(x) == self.x and int(y) == self.y:
                self.t = int(t)
        else:
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
            self.t = None
            self.ydotool.move(self.x, self.y, 'br', 0)

    def pause_macro(self, x, y):
        """Pause mouse recording."""
        print('pause', x, y, file=sys.stderr)
        self.x = int(x)
        self.y = int(y)

    def run(self):
        with ydo.NoMouseAccel():
            r = tk.Tk()
            r.createcommand('print_click', self.print_click)
            r.createcommand('print_move', self.print_move)
            r.createcommand('begin_macro', self.begin_macro)
            r.createcommand('pause_macro', self.pause_macro)

            r.bind('<space>', 'print_click %t')
            r.bind('<B1-Motion>', 'print_move %X %Y %t')

            r.bind('<ButtonPress-1>', 'begin_macro %X %Y %t')
            r.bind('<ButtonRelease-1>', 'pause_macro %X %Y')
            r.bind('<Escape>', 'destroy {}'.format(r))
            r.title('macro')
            r.wait_window()


def run(args, ydotool):
    if args.record:
        Macro(ydotool).run()
    else:
        pass

if __name__ == '__main__':
    p = argparse.ArgumentParser()
    p.add_argument('-r', '--record', help='record a script.', action='store_true')
    p.add_argument('-i', '--input', help='input file.')
    args = p.parse_args()

    with ydo.ydotoold() as d:
        with ydo.ydotool(d.path) as ydotool:
            run(args, ydotool)
