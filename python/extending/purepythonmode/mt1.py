import cython
#@cython.inline
@cython.locals(x=cython.double)
@cython.returns(cython.double)
@cython.ccall
def f(x):
    return x*x - x

