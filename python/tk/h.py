import Tkinter as tk
import ttk

root = tk.Tk()
root.configure(
  background = "#000000")
f = ttk.Frame(root, width = "200", height = "200")
f.grid(row = 0, column = 0)
root.rowconfigure(0, pad = "9", weight = 1)
root.columnconfigure(0, pad = "9", weight = 1)
f2 = ttk.Frame(root, width = "200", height = '200')
f2.grid(row = 0, column = 1)



root.bind('<Escape>', lambda x : root.destroy())
root.mainloop()
