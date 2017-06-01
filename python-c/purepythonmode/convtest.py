# cython: c_string_type=bytes, c_string_encoding=ascii

import cv2
import numpy as np
import cython



@cython.cclass
class convthis:
    cython.declare(f=object)
    cython.declare(name = cython.str)
    def __init__(self):
        self.f = np.ones((5,5), np.float32) / 25.0
        self.name = "hello"

    @cython.ccall
    @cython.locals(i=cython.int)
    @cython.boundscheck(False)
    @cython.wraparound(False)
    def do(self, im):
        i = 0
        return cv2.filter2D(im, -1, self.f) + i

    @cython.ccall
    @cython.locals(n=cython.bytes)
    @cython.returns(cython.bytes) 
    def greet(self, n):
        self.name + n
