import numpy as np
import tkinter as tk

colornames = 'black red green yellow blue magenta cyan white'.split()

textcolors = {}
bgcolors = {}
for i in range(len(colornames)):
    textcolors[colornames[i]] = 30+i
    print(f'\x1b[{i+30}m{colornames[i]}\x1b[0m', sep='')
    print(f'\x1b[{i+90}m{colornames[i]}\x1b[0m', sep='')

    print(f'\x1b[{30 if i else 37};{i+40}mbg {colornames[i]}\x1b[0m', sep='')
    print(f'\x1b[{30 if i else 37};{i+100}mbg {colornames[i]}\x1b[0m', sep='')


def clip(val, lo, hi):
    return min(max(lo, val), hi)

def makecode(*values):
    return f'\x1b[{";".join(map(str, values))}m'
def clearansi():
    return '\x1b[0m'
def fgansi(r, g, b):
    return f'\x1b[38;2;{r};{g};{b}m'
def bgansi(r, g, b):
    return f'\x1b[48;2;{r};{g};{b}m'


def setcolor(fg, bg, bold=False, faint=False, italic=False, underline=False):
    return ''.join((
        fgansi(*fg),
        bgansi(*bg),
        makecode(1),
        makecode(2),
        makecode(3),
        makecode(4),
    ))




def print_settings(r, g, b, br, bg, bb):
    print(f'\rfg: ', setcolor((r,g,b), (br,bg,bb)), f'{r:03d}, {g:03d}, {b:03d}, #{r:02x}{g:02x}{b:02x}', clearansi(), end='', sep='')
    print(f'  bg: ', setcolor((r,g,b), (br,bg,bb)), f'{br:03d}, {bg:03d}, {bb:03d}, #{br:02x}{bg:02x}{bb:02x}', clearansi(), end='', sep='')
    print(f'  bold:', setcolor((r,g,b), (br,bg,bb), True), f'bold text', clearansi(), end='', sep='')


class LabeledScale(tk.Scale):
    def __init__(self, root, name, row, col, orient=tk.HORIZONTAL, from_=0, to=255, variable=None, **kwargs):
        if variable is None:
            variable = tk.IntVar(root)
        tk.Scale.__init__(self, root, label=name, variable=variable, orient=orient, from_=from_, to=to, **kwargs)
        self.value = variable
        self.grid(row=row, column=col, sticky='nsew')

        self.value.trace_add('write', self.callback)

    def callback(self, varname, unknown, action):
        fgr, fgg, fgb = [v.get() for v in color]
        bgr, bgg, bgb = [v.get() for v in background]
        print_settings(fgr, fgg, fgb, bgr, bgg, bgb)




r = tk.Tk()
color = [tk.IntVar(r, 0) for _ in range(3)]
background = [tk.IntVar(r, 0) for _ in range(3)]

r.minsize(600,200)
r.grid_columnconfigure(0, weight=1)
r.grid_columnconfigure(1, weight=1)
l1 = tk.Label(r, text='fg')
l1.grid(row=0, column=0, sticky='nsew')
l2 = tk.Label(r, text='bg')
l2.grid(row=0, column=1, sticky='nsew')

fgr = LabeledScale(r, 'red', 1, 0, variable=color[0])
fgg = LabeledScale(r, 'green', 2, 0, variable=color[1])
fgb = LabeledScale(r, 'blue', 3, 0, variable=color[2])

bgr = LabeledScale(r, 'red', 1, 1, variable=background[0])
bgg = LabeledScale(r, 'green', 2, 1, variable=background[1])
bgb = LabeledScale(r, 'blue', 3, 1, variable=background[2])

r.bind('<q>', lambda e: r.destroy())
r.mainloop()
print()
