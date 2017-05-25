import ctypes

# class Link(ctypes.Structure):
#     _fields_ = [("next", ctypes.POINTER(Link)),
#                 ("data", ctypes.c_int)]



# class Link(ctypes.Structure):
#     pass
# Link._fields_ = [("next", ctypes.POINTER(Link)),
#                  ("data", ctypes.c_int)]


# class POINT(ctypes.Structure):
#     _fields_ = ('x', ctypes.c_int), ('y', ctypes.c_int)

# class RECT(ctypes.Structure):
#     _fields_ = ('a', POINT), ('b', POINT)

# p1 = POINT(1,2)
# p2 = POINT(3,4)
# r = RECT(p1, p2)

# print p1.x, p1.y, p2.x, p2.y
# p1.x, p1.y = p1.y, p1.x

# #ints not pointers or structs
# print p1.x, p1.y, p2.x, p2.y

# print r.a.x, r.a.y, r.b.x, r.b.y
# r.a, r.b = r.b, r.a
# print r.a.x, r.a.y, r.b.x, r.b.y

# s = ctypes.c_char_p()
# s.value = "abc def ghi"
# print s.value
# print s.value is s.value


# short_array = (ctypes.c_short * 4)()
# print short_array
# print ctypes.sizeof(short_array)
# try:
#     ctypes.resize(short_array, 4)
# except Exception as e:
#     print e
# # ctypes.resize(short_array, 32)
# short_array[:]
# short_array[3]
# try:
#     short_array[4]
# except Exception as e:
#     print e

# sp = ctypes.POINTER(ctypes.c_short)

# print short_array
# new_short_array = (ctypes.c_short*16).from_address(ctypes.addressof(short_array))
# print new_short_array

# short_array[0] = 69
# print short_array[:]
# print new_short_array[:]



from ctypes import c_int, WINFUNCTYPE, windll
from ctypes.wintypes import HWND, LPCSTR, UINT
prototype = WINFUNCTYPE(c_int, HWND, LPCSTR, LPCSTR, UINT)
paramflags = (1, "hwnd", 0), (1, "text", "Hi"), (1, "caption", None), (1, "flags", 0)
MessageBox = prototype(("MessageBoxA", windll.user32), paramflags)
print MessageBox()
print MessageBox(text = "Spam, spam spam")
print MessageBox(flags = 2, text = "foo bar")
print MessageBox(0, "hello world", "mybox", 0)
