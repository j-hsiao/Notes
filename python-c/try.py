import ctypes
import sys
import os
LIBDIR = os.path.dirname(os.path.realpath(__file__))
# os.environ['PATH'] = os.path.dirname(os.path.realpath(__file__)) + os.pathsep + os.environ['PATH']
hello_lib = ctypes.cdll.LoadLibrary(os.path.join(LIBDIR, "hello.so"))
hello = hello_lib.hellop
hello.restype = ctypes.c_char_p
hello.argtypes = [ctypes.c_char_p]

s = hello(ctypes.c_char_p("bananas"))
print s

