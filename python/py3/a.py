import sys
__package__ = 'py3'
print(__package__)
from . import b
#from py3 import b
print(b)
from .c import x
#from py3.c import x
print(x)
print(__name__)
