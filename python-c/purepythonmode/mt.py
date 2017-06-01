import cython
import mt1
@cython.ccall
@cython.locals(a=cython.double, b = cython.double, N=cython.int,s=cython.double, i=cython.int, f=object)
@cython.returns(cython.double)
def integrate_f(a, b, N):
    f=mt1.f
    s = 0
    dx = (b - a) / N
    for i in xrange(N):
        s += f(a+i*dx)
    return s * dx

