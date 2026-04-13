import tkinter as tk
import time
import io
import base64
import cv2
import numpy as np
import os
import threading

# f = os.mkfifo('tmp.png')

def writeit(im):
    print('cv2 writing image...')
    cv2.imwrite('tmp.png', im)
    print('cv2 wrote image...')

r = tk.Tk()

l1 = tk.Label(r)
l1.grid()
t1 = []
def cv2b64(*args):
    now = time.time()
    npim = np.zeros((480,640,3), np.uint8)
    npim[::3] = 255
    succ, data = cv2.imencode('.png', npim)
    imname = r.call(
        'image', 'create', 'photo', '-data', base64.b64encode(data).decode('utf-8'),
        '-format', 'png')
    oname = l1.cget('image')
    l1.configure(image=imname)
    if oname:
        r.call('image', 'delete', oname)
    t1.append(time.time() - now)
r.bind('<a>', cv2b64)

t2 = []
try:
    from PIL import Image, ImageTk
    l2 = tk.Label(r)
    l2.grid()
    hold = [None]
    def nppil(*args):
        now = time.time()
        npim = np.zeros((480,640,3), np.uint8)
        npim[::3] = 255
        succ, data = cv2.imencode('.png', npim)
        hold[0] = ImageTk.PhotoImage(Image.fromarray(npim))
        l2.configure(image=hold[0])
        t2.append(time.time() - now)
    r.bind('<b>', nppil)
except ImportError:
    pass


l3 = tk.Label(r)
l3.grid()
t3 = []
def defaulthandler(*args):
    # This seems to fail, can't seem to get it to recongized the default handler...
    now = time.time()
    npim = np.zeros((5,5,3), np.uint8)
    npim[::3] = 255
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
        print(s.getvalue())
        imname = r.eval(
            'image create photo -height {} -width {} -data {{ {} }}'.format(
            npim.shape[0], npim.shape[1], s.getvalue()))

    oname = l3.cget('image')
    l3.configure(image=imname)
    if oname:
        r.call('image', 'delete', oname)
    t3.append(time.time() - now)
r.bind('<c>', defaulthandler)


r.bind('<Escape>', f'destroy {r}')
r.mainloop()

def stats(n, l):
    if l:
        print(n)
        print('  len:', len(l))
        print('  avg:', sum(l) / len(l))
        print('  min:', min(l))
        print('  max:', max(l))

stats('cv2', t1)
stats('PIL', t2)
stats('def', t3)
