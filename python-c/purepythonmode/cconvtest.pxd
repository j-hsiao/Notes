import numpy as np



cdef class convthis:

      cpdef do(self, np.ndarray[np.uint8, ndim=3] im)