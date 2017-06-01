include "mt3.pyx"

cpdef double integrate_f(double a, double b, int N):
    cdef double s = 0
    cdef int i
    s = 0
    dx = (b - a) / N
    for i in xrange(N):
        s += f(a+i*dx)
    return s * dx

