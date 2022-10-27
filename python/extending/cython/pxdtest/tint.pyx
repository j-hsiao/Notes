cpdef double f(double x):
    return x*(x-1)

def ff(x):
    return x*(x-1)




cpdef double integrate_f(double a, double b, int N):
    cdef double s = 0
    cdef int i
    dx = (b - a) / N
    for i in xrange(N):
        s += f(a+i*dx)
    return s * dx

cpdef double integrate_ff(double a, double b, int N):
    cdef double s = 0
    cdef int i
    dx = (b - a) / N
    for i in xrange(N):
        s += ff(a+i*dx)
    return s * dx
