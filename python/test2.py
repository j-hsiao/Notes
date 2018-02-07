import Tkinter

root = Tkinter.Tk()
photo = Tkinter.PhotoImage(file = r"D:\downloads\kamihime\all\127_0011_2_2_c2_h.gif")#, format='gif -index 2')
label = Tkinter.Label(image = photo)
label.pack()
root.mainloop()
