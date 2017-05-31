import cython

#@cython.inline
@cython.locals(x=cython.double)
@cython.returns(cython.double)
@cython.cfunc
def f(x):
    return x*x - x


@cython.ccall
@cython.locals(a=cython.double, b = cython.double, N=cython.int,s=cython.double, i=cython.int)
@cython.returns(cython.double)
def integrate_f(a, b, N):
    s = 0
    dx = (b - a) / N
    for i in xrange(N):
        s += f(a+i*dx)
    return s * dx
