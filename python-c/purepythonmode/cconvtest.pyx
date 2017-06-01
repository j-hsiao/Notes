import numpy as np
cimport numpy as np
import cv2
cimport cython

cdef class convthis:
    cdef object f
    def __init__(self):
        self.f = np.ones((5,5), np.float32) / 25.0

    @cython.boundscheck(False)
    @cython.wraparound(False)
    cpdef do(self, np.ndarray[np.uint8_t, ndim=3] im):
        cdef np.ndarray[np.float32_t, ndim=2] ar
        ar = self.f
        cdef int i = 0
        return cv2.filter2D(im, -1, ar) + i
