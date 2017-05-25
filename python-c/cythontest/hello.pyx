def say_hello_to(name):
    print 'Hello {}!'.format(name)



def iterincre(i):
    v = 0
    for j in xrange(i):
        v += 1
    return v



# def f(x):
#     return x**2 - x


# def integrate_f(a, b, N)except? -2:
#     s = 0
#     dx = (b - a) / N
#     for i in xrange(N):
#         s += f(a+i*dx)
#     return s * dx

cdef double f(double x):
    return x**2 - x

cpdef double integrate_f(double a, double b, int N):
    cdef int i
    cdef double s, dx
    s = 0
    dx = (b - a) / N
    for i in range(N):
        s += f(a+i*dx)
    return s * dx
