from Tkinter import *

# root=Tk()
# frame=Frame(root,width=300,height=300)
# frame.grid(row=0,column=0)
# canvas=Canvas(frame,bg='#FFFFFF',width=300,height=300,scrollregion=(0,0,500,500))
# hbar=Scrollbar(frame,orient=HORIZONTAL)
# hbar.pack(side=BOTTOM,fill=X)
# hbar.config(command=canvas.xview)
# canvas.config(width=300,height=300)
# canvas.config(xscrollcommand=hbar.set)
# canvas.pack(side=LEFT,expand=True,fill=BOTH)

# root.mainloop()

import ttk
root = Tk()
# frame = ttk.Frame(root, width = 300, height = 300)
# frame.grid(row = 0, column = 0)


canvas = Canvas(
    root,
    bg='#000000')
canvas.configure(
    width = 300,
    height = 300,
    scrollregion = (0, 0, 500, 500))

f2 = ttk.Frame(canvas, width = 300, height = 300)
canvas.create_window((0,0), window = f2, anchor = 'nw')
canvas.configure(
    width = 300,
    height = 300,
    scrollregion = (0, 0, 500, 500))
canvas.grid(row = 0, column = 0)
scroll = ttk.Scrollbar(root, orient = 'horizontal')
scroll.configure(command = canvas.xview)
canvas.configure(xscrollcommand = scroll.set)
scroll.grid(row = 1, column = 0, sticky = 'we')




root.bind('q', lambda x : root.destroy())
root.mainloop()
