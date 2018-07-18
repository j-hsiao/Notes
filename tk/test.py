from PIL import Image, ImageTk
import tkinter
from tkinter import ttk
import traceback
import cv2
import base64


def callback(*args):
    for arg in args:
        print arg.x, arg.y
        print arg
        print dir(arg)

def drag(*args):
    for arg in args:
        print arg.x, arg.y
    print 'dragging'

def selected(*args):
    for arg in args:
        print [
            arg.widget.get(_)
            for _ in arg.widget.curselection()]

def swap(box, *args):
    box.configure(
        selectmode = (
            'browse' if box.configure('selectmode')[-1] == 'extended'
            else 'extended'))
    print box.configure('selectmode')[-1]

def close(root, *args):
    root.destroy()

def step(prog, *args):
    val = int(prog.configure('value')[-1])
    mv = int(prog.configure('maximum')[-1]) + 1
    prog.configure(value = (val + 1) % mv)

def start(prog, *args):
    prog.start()
def stop(prog, *args):
    prog.stop()


def begin_lines(canvas, point, *args):
    ev = args[0]
    point[:] = (ev.x, ev.y)


def draw_line(canvas, point, *args):
    canvas.create_line(
        args[0].x, args[0].y,
        point[0], point[1],
        fill = 'red',
        width = 3
    )
    point[:] = args[0].x, args[0].y


if __name__ == '__main__':
    path = '/home/andy/Downloads/fisheye/testim1.jpg'
    root = tkinter.Tk()
    im = cv2.imread(path)
    pim = ImageTk.PhotoImage(
        Image.fromarray(im[:,:,::-1])
    )
    frame = ttk.Frame(root)
    frame.grid(column = 0,row = 0)
    frame.configure(height = 500, width = 500)
    label = ttk.Label(frame)
    label.grid(column = 0, row = 0)
    text = ttk.Label(frame, text = 'hello world!')
    text.grid(column = 1, row = 1)
    button = ttk.Button(frame, text = 'push me', command = callback)
    button.grid(column = 0, row = 1)
    do = True
    

    boxlist = tkinter.StringVar()
    boxlist.set('I am a {beautiful person}')
    # class dat(object):
    #     def __init__(self, val):
    #         self._val = val
    #     def __repr__(self):
    #         return self._val
    # boxlist = [dat(_) for _ in ['I', 'am', 'a', 'beautiful person']]
    box = tkinter.Listbox(frame, height = 3, listvariable = boxlist)
    scrollbar = ttk.Scrollbar(frame, orient = 'vertical', command = box.yview)
    scrollbar.grid(column = 1, row = 2, sticky = 'w')
    box.configure(yscrollcommand = scrollbar.set)
    box.configure(selectmode = 'browse')
    box.grid(column = 0,row = 2, sticky = 'e')
    def wrap(func, target):
        def wut(*args):
            func(target, *args)
        return wut


    root.bind('q', wrap(close, root))
    root.bind('<Alt-Key-x>', callback)
    root.bind('<Button2-Motion>', drag)
    box.bind('<<ListboxSelect>>', selected)
    box.bind('b', wrap(swap, box))
    prog = ttk.Progressbar(
        frame, orient = 'horizontal',
        length = 500, mode = 'determinate',
        maximum = 5,
        value = 0)
    prog.grid(column = 0, row = 6)
    # prog.bind('<Double-Button-1>', wrap(step, prog))
    prog.bind('<Button-1>', wrap(start, prog))
    prog.bind('<Double-Button-1>', wrap(stop, prog))
    

    canvas = tkinter.Canvas(frame, width = 500, height = 500)
    canvas.grid(row = 5, column = 0)
    canvas.create_line(
        10,10,490,490)
    canpoint = [0,0]

    canvas.bind(
        '<Button-1>',
        (lambda *args : begin_lines(
            canvas, canpoint, *args)))
    canvas.bind(
        '<Button1-Motion>',
        (lambda *args : draw_line(
            canvas, canpoint, *args)))

    


    try:
        label.configure(
            image = pim
        )
    except:
        traceback.print_exc()
        do = False
    if do:
        root.mainloop()
    
