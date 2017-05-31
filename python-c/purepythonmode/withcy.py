import cython


@cython.inline
@cython.cfunc
@cython.locals(n=cython.int, j=cython.double)
@cython.returns(cython.double)
def helper(n):
    j = 1. / n
    return j*j


@cython.locals(n=cython.int, val=cython.double, k=cython.int)
@cython.returns(cython.double)
def pi(n):
    val = 0.
    for k in xrange(1, n+1):
        val += helper(k)
    return (6 * val) ** .5

