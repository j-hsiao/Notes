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


def setcolor(fg, bg, bold=False, faint=False, italic=False, underline=False, crossed=False, superscript=False, subscript=False):
    return ''.join((
        fgansi(*fg),
        bgansi(*bg),
        makecode(1) if bold else '',
        makecode(2) if faint else '',
        makecode(3) if italic else '',
        makecode(4) if underline else '',
        makecode(9) if crossed else '',
        makecode(73) if superscript else '',
        makecode(74) if subscript else '',
    ))


def print_settings():
    fgr, fgg, fgb = [v.value.get() for v in color]
    bgr, bgg, bgb = [v.value.get() for v in background]
    setting = setcolor((fgr,fgg,fgb), (bgr,bgg,bgb), **{k: v.value.get() for k,v in modifiers.items()})
    print(f'\rfg: ', setting, f'{fgr:03d}, {fgg:03d}, {fgb:03d}, #{fgr:02x}{fgg:02x}{fgb:02x}', clearansi(), end='', sep='')
    print(f'  bg: ', setting, f'{bgr:03d}, {bgg:03d}, {bgb:03d}, #{bgr:02x}{bgg:02x}{bgb:02x}', clearansi(), end='', sep='', flush=True)


class LabeledScale(tk.Scale):
    def __init__(self, root, name, row, col, orient=tk.HORIZONTAL, from_=0, to=255, variable=None, **kwargs):
        if variable is None:
            variable = tk.IntVar(root)
        tk.Scale.__init__(self, root, label=name, variable=variable, orient=orient, from_=from_, to=to, **kwargs)
        self.value = variable
        self.grid(row=row, column=col, sticky='nsew')

        self.value.trace_add('write', self.callback)

    def callback(self, varname, unknown, action):
        print_settings()

class Checkbox(tk.Checkbutton):
    def __init__(self, root, name, row, col, variable=None):
        if variable is None:
            variable = tk.BooleanVar(root)
        tk.Checkbutton.__init__(self, root, text=name, variable=variable)
        self.value = variable
        self.grid(row=row, column=col, sticky='nsew')
        self.value.trace_add('write', self.callback)

    def callback(self, varname, unknown, action):
        print_settings()



r = tk.Tk()
modframe = tk.Frame(r)
modifiers = {
    k: Checkbox(modframe, k, 0, i)
    for i, k in enumerate('bold faint italic underline crossed'.split())
}
modframe.grid(row=4, column=0, columnspan=2)

r.minsize(600,200)
r.grid_columnconfigure(0, weight=1)
r.grid_columnconfigure(1, weight=1)
l1 = tk.Label(r, text='fg')
l1.grid(row=0, column=0, sticky='nsew')
l2 = tk.Label(r, text='bg')
l2.grid(row=0, column=1, sticky='nsew')

color = [
    LabeledScale(r, k, i+1, 0)
    for i, k in enumerate('red green blue'.split())]
background = [
    LabeledScale(r, k, i+1, 1)
    for i, k in enumerate('red green blue'.split())]






r.bind('<q>', lambda e: r.destroy())
r.bind('<Escape>', lambda e: r.destroy())
r.mainloop()
print()
