import timeit
def pi_help(n):
    j = 1. / n
    return j*j


def approx_pi(n=10000000):
    val = 0
    for k in xrange(1, n+1):
        val += pi_help(k)
    return (6 * val) ** .5


if __name__ == '__main__':
    print timeit.timeit('calc_pi.approx_pi()', 'import calc_pi', number = 1)
    print timeit.timeit('approx_pi()', 'from __main__ import approx_pi', number = 1)
