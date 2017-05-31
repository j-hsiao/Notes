import sys
import withcy
import timeit
def pi_help(n):
    j = 1. / n
    return j*j


def pi_no_cy(n):
    val = 0
    for k in xrange(1, n+1):
        val += pi_help(k)
    return (6 * val) ** .5








if __name__ == '__main__':
    v = 10000
    if len(sys.argv) > 1:
        try:
            v = int(sys.argv[1])
        except:
            print 'invalid int'
            exit(1)

    #DO STUFF
    print timeit.timeit('pi_no_cy({})'.format(v), 'from __main__ import pi_no_cy', number=1)
    print timeit.timeit('pi({})'.format(v), 'from withcy import pi', number=1)
    print timeit.timeit('pi_no_cy({})'.format(v), 'from __main__ import pi_no_cy', number=1)
    print pi_no_cy(v)
    print withcy.pi(v)
