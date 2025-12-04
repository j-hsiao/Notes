import argparse
import time
import tkinter as tk
import sys
import traceback
import ast
import select

import ydo
eprint = ydo.eprint

class Macro(object):
    """Class for outputting macro sequence."""
    def __init__(self):
        self.ydotool = None
        self.file = None
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
        print('click', int(t) - self.t, file=self.file)
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
                eprint('ignored down', keysym)
                return
            if self.kstate.get(keysym, None) is None:
                print(
                    'keydown', '-'.join(
                        self.parse_state(int(state), keysym)),
                    int(t)-self.t, file=self.file)
                self.t = int(t)
            self.kstate[keysym] = 1
        except Exception:
            traceback.print_exc()

    def key_up(self, kcode, keysym, state, t):
        """Mouse button up."""
        try:
            if self.ignore(keysym):
                eprint('ignored release', keysym)
                return
            self.kstate[keysym] = 0
            self.r.update()
            if not self.kstate[keysym]:
                print(
                    'keyup', '-'.join(
                        self.parse_state(int(state), keysym)),
                    int(t)-self.t, file=self.file)
                self.kstate[keysym] = None
                self.t = int(t)
        except Exception:
            traceback.print_exc()

    def print_move(self, x, y, t):
        """Print a move command.

        move x y delay(ms)
        """
        x = int(x)
        y = int(y)
        if self.x is None:
            t = int(t)
            print('move', x, y, t - self.t, file=self.file)
            self.t = t
        else:
            if x == self.x and y == self.y:
                self.x = None
                self.y = None
            else:
                eprint('resuming to', self.x, self.y, 'currently at', x, y)

    def begin_macro(self, x, y, t):
        """Start mouse recording.

        Use ydotool to warp mouse into the last released position.
        """
        eprint('resume', x, y, t)
        if self.x is None:
            self.t = int(t)
        else:
            # self.ydotool.move(self.x, self.y, True)
            self.ydotool.move(self.x, self.y, 'br', 0)

    def pause_macro(self, x, y):
        """Pause mouse recording."""
        eprint('pause', x, y)
        self.x = int(x)
        self.y = int(y)


    class TeePrint(object):
        class dummyio(object):
            def write(self, data):
                return len(data)
            def flush(self):
                pass
            def __enter__(self):
                return self
            def __exit__(self, tp, exc, tb):
                pass
        def __init__(self, f=None):
            if f is None:
                self.f = self.dummyio()
            else:
                self.f = f
        def write(self, data):
            sys.stdout.write(data)
            return self.f.write(data)
        def flush(self):
            sys.stdout.flush()
            self.f.flush()
        def __enter__(self):
            self.f.__enter__()
            return self
        def __exit__(self, tp, exc, tb):
            self.f.__exit__(tp, exc, tb)


    def run(self, ydotool, out):
        self.file = self.TeePrint(open(out, 'w') if out else None)
        self.ydotool = ydotool
        with self.file:
            self.r = r = self.ydotool.pos.tk
            t = tk.Toplevel(r)
            t.bindtags((self.ydotool.pos.tk,) + t.bindtags())
            r.createcommand('print_click', self.print_click)
            r.createcommand('print_move', self.print_move)
            r.createcommand('begin_macro', self.begin_macro)
            r.createcommand('pause_macro', self.pause_macro)
            # r.createcommand('key_up', self.key_up)
            # r.createcommand('key_down', self.key_down)

            t.bind('<Control-space>', 'print_click %t')

            # t.bind('<KeyPress>', 'key_down %k %K %s %t')
            # t.bind('<KeyRelease>', 'key_up %k %K %s %t')


            t.bind('<B1-Motion>', 'print_move %X %Y %t')
            t.bind('<ButtonPress-1>', 'begin_macro %X %Y %t')
            t.bind('<ButtonRelease-1>', 'pause_macro %X %Y')
            t.bind('<Escape>', 'destroy ' + str(t))
            t.title('macro')
            t.wait_window()
        self.file = None
        self.ydotool = None

def parse_time(timespec):
    """Parse time as seconds."""
    if timespec:
        parts = timespec.split(':')
        if len(parts) == 1:
            return float(parts[0])
        elif len(parts) == 2:
            return float(parts[0])*3600 + float(parts[1])*60
        else:
            return (
                float(parts[0])*3600
                + float(parts[1])*60
                + float(parts[2]))
    else:
        return 0


def handle_input():
    """Handle input

    Return (elapsed_seconds, quit?)
    """
    now = time.time()
    ncmd = 0
    while True:
        cmd = input()
        if not cmd:
            if ncmd:
                cmd = 'help'
            else:
                eprint('paused')
        if cmd == 'help':
            eprint('c: continue')
            eprint('quit: quit')
        elif cmd == 'c':
            return time.time() - now, False
        elif cmd == 'quit':
            return time.time() - now, True
        elif cmd:
            eprint('unrecognized command:', cmd)
        ncmd += 1

def sleep(t, period=1):
    """Wait on stdin while sleeping and print sleep progress.

    t: float, sleep duration (seconds).
    period: update period, default 1 second.
            If t < period, then no progress will be printed.

    Return True if quit.
    """
    if t > period:
        clear_to_end = '\x1b[K'
        while t:
            eprint('\rsleeping', t, end=clear_to_end, flush=True)
            if select.select([sys.stdin], (), (), min(period, t))[0]:
                elapsed, end = handle_input()
                if end:
                    return True
                t = max(0, t - elapsed)
                continue
            t = max(0, t-period)
        eprint('\r', end=clear_to_end)
    else:
        if select.select([sys.stdin], (), (), t)[0]:
            elapsed, end = handle_input()
            if end:
                return True
            t = max(0, t - elapsed)


def run(args, ydotool):
    if args.record:
        Macro().run(ydotool, args.fname)
    else:
        reps = 0
        repdelay = parse_time(args.repeat)
        eprint('repeat delay', repdelay)
        with open(args.fname, 'r') as f:
            lines = f.readlines()
        while 1:
            eprint('reps:', reps)
            reps += 1
            for lno, line in enumerate(lines):
                eprint(lno, '/', len(lines), ':', line.strip())
                parts = line.strip().split()
                if parts[0] == 'click':
                    delay = int(parts[1]) / 1000.0
                    if sleep(delay):
                        return
                    ydotool.click()
                elif parts[0] == 'move':
                    x = int(parts[1])
                    y = int(parts[2])
                    delay = int(parts[3]) / 1000.0
                    if sleep(delay):
                        return
                    # ydotool.move(x, y, True)
                    ydotool.move(x, y, 'br', 0)
                elif parts[0] == 'type':
                    remainder = line.split(None, 1)[-1]
                    text = remainder.rsplit(None, 1)[0]
                    delay = int(parts[-1]) / 1000.0
                    if sleep(delay):
                        return
                    ydotool.type(ast.literal_eval(text))
                else:
                    eprint('Unsupported command:', line)
            if repdelay:
                if sleep(repdelay):
                    return
            else:
                return


if __name__ == '__main__':
    p = argparse.ArgumentParser()
    p.add_argument('fname', help='macro file to run or record.')
    p.add_argument('-r', '--record', help='record a script.', action='store_true')
    p.add_argument(
        '--repeat', default = '', help='repeat delay, SS, HH:MM, or HH:MM:SS (each can be float)'
    )
    args = p.parse_args()

    with ydo.ydotoold(verbose=False) as d:
        with ydo.ydotool(d.path, noaccel=True) as ydotool:
            run(args, ydotool)
