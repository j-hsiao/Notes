# cython: profile=True
cimport cython
@cython.profile(False)
cdef inline recip_square(int i):
    cdef float j = 1./i
    return j*j


def approx_pi(n=10000000):
    cdef double val = 0.
    cdef int k
    for k in xrange(1, n+1):
        val += recip_square(k)
    return (6 * val)**.5

