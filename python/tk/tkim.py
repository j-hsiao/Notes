import argparse
import tkinter as tk
import time
import io
import base64
import cv2
import numpy as np
import os
import threading
import sys

p = argparse.ArgumentParser()
p.add_argument('-s', '--shape', help='width height', nargs=2, default=[640, 480], type=int)
args = p.parse_args()

# f = os.mkfifo('tmp.png')
# NOTE: writing png to named pipe and having
# tk use the -file option seems to fail.

def writeit(im):
    print('cv2 writing image...')
    cv2.imwrite('tmp.png', im)
    print('cv2 wrote image...')

r = tk.Tk()


class Binding(object):
    bindkey = ord('a')
    delete = False
    def __init__(self, r, im):
        self.times = []
        self.label = tk.Label(r, text=type(self).__name__)
        self.label.grid()
        self.im = im
        self.r = r
        r.bind('<{}>'.format(chr(Binding.bindkey)), self)
        print(chr(Binding.bindkey), type(self).__name__)
        Binding.bindkey += 1

    def clear(self):
        if self.delete:
            imname = self.label.cget('image')
            if imname:
                self.r.call('image', 'delete', imname)
        self.label.configure(image='')

    def __call__(self, *args):
        now = time.time()
        self.run(self.r, self.im)
        self.times.append(time.time() - now)

    def stats(self):
        tms = self.times
        if tms:
            print(type(self).__name__)
            if any(tms):
                print('  fps:', len(tms) / sum(tms))
            print('  len:', len(tms), file=sys.stderr)
            print('  avg:', sum(tms) / len(tms), file=sys.stderr)
            print('  min:', min(tms), file=sys.stderr)
            print('  max:', max(tms), file=sys.stderr)

npim = np.zeros((args.shape[1], args.shape[0], 3), np.uint8)
npim[::3] = 255
bindings = []
def insts(cls):
    bindings.append(cls(r, npim))
    return cls

@insts
class cv2b64(Binding):
    delete = True
    def run(self, r, npim):
        succ, data = cv2.imencode('.png', npim)
        imname = r.call(
            'image', 'create', 'photo', '-data',
            base64.b64encode(data).decode('utf-8'),
            '-format', 'png')
        oname = self.label.cget('image')
        self.label.configure(image=imname)
        if oname:
            r.call('image', 'delete', oname)

@insts
class cv2png(Binding):
    delete = True
    def run(self, r, npim):
        succ, data = cv2.imencode('.png', npim)
        imname = r.call(
            'image', 'create', 'photo',
            '-data', data.tobytes(),
            '-format', 'png')
        oname = self.label.cget('image')
        self.label.configure(image=imname)
        if oname:
            r.call('image', 'delete', oname)

@insts
class tkphotob64(Binding):
    def run(self, r, npim):
        succ, data = cv2.imencode('.png', npim)
        image = self.hold = tk.PhotoImage(
            master=r, format='png', data=base64.b64encode(data).decode('utf-8'))
        self.label.configure(image=image)

@insts
class tkphoto(Binding):
    def run(self, r, npim):
        succ, data = cv2.imencode('.png', npim)
        image = self.hold = tk.PhotoImage(
            master=r, format='png', data=data.tobytes())
        self.label.configure(image=image)

t2 = []
try:
    from PIL import Image, ImageTk
    @insts
    class TkPIL(Binding):
        def run(self, r, npim):
            image = self.hold = ImageTk.PhotoImage(Image.fromarray(npim))
            self.label.configure(image=image)
except ImportError:
    pass


if [int(_) for _ in r.eval('expr $tcl_version').split('.')] >= [9, 1]:
    @insts
    class Default(Binding):
        delete = True
        def run(self, r, npim):
            with io.StringIO() as s:
                for row in range(npim.shape[0]):
                    s.write('{ ')
                    for col in range(npim.shape[1]):
                        s.write(
                            '#{:02x}{:02x}{:02x} '.format(
                                npim[row,col,2],
                                npim[row,col,1],
                                npim[row,col,0],
                            ))
                    s.write('} ')
                imname = r.eval(
                    'image create photo -format default -colorformat rgb -height {} -width {} -data {{ {} }}'.format(
                    npim.shape[0], npim.shape[1], s.getvalue()))
            oname = self.label.cget('image')
            self.label.configure(image=imname)
            if oname:
                r.call('image', 'delete', oname)


def clearall(e):
    for item in bindings:
        item.clear()

r.bind('<Escape>', f'destroy {r}')
r.bind('<q>', f'destroy {r}')
r.bind('<space>', clearall)
r.mainloop()

for item in bindings:
    item.stats()
