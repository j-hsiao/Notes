import tkinter as tk
import random
import argparse
p = argparse.ArgumentParser()
p.add_argument('-d', '--delay', type=float, help='repeat delay in seconds', default=10)
p.add_argument('-j', '--jitter', type=int, default=2)
p.add_argument('-v', '--verbose', action='store_true')
args = p.parse_args()
args.delay = str(int(args.delay * 1000))

sized = '{}x10+0+0'.format(args.jitter+10)


class Callback(object):
    DEFS = {}
    def __init__(self, func):
        self.func = func
        self.name = '{}{}'.format(self.func.__name__, id(self.func))
        if self.DEFS.setdefault(self.name, self) is not self:
            raise ValueError('{} already defined'.format(self.name))

    def __str__(self):
        return self.name

    def __call__(self, *args, **kwargs):
        self.func(*args, **kwargs)

    def create(self, r):
        r.createcommand(self.name, self)

    @classmethod
    def create_all(cls, r):
        for cb in cls.DEFS.values():
            cb.create(r)

# loc: location as indicated by winfo_pointerxy()
state = {
    'pos': (),
}
# offset when calculating warp values.
offset = []


@Callback
def left():
    r.geometry('1x1+0+0')

@Callback
def enterred():
    r.geometry(sized)

@Callback
def check(shift=1):
    shift = int(shift)
    x, y = r.winfo_pointerxy()
    if args.verbose:
        print('at', x, y)
    if state['pos'] == (x,y):
        x = max(x+shift, 0)
        if args.verbose:
            print('\tto', x, y)
        r.event_generate('<Motion>', x=x, y=y, warp=True)
    state['pos'] = x,y
    r.tk.call('after', args.delay, check, str(-shift))

r = tk.Tk()
r.overrideredirect(True)
r.geometry('1x1+0+0')
r.attributes('-topmost', True)
Callback.create_all(r)
r.tk.call('after', '1', check, str(args.jitter))
r.bind('<Escape>', 'destroy .')
r.bind('<Double-Button-1>', 'destroy .')
r.bind('<Leave>', str(left))
r.bind('<Enter>', str(enterred))
r.mainloop()
