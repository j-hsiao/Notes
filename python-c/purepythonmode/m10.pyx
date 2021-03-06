cimport m11

cpdef double integrate_f(double a, double b, int N):
    cdef double s = 0
    cdef int i
    dx = (b - a) / N
    for i in xrange(N):
        s += m11.f(a+i*dx)
    return s * dx

