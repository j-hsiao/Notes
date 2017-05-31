import cintegrate
import timeit


def f(x):
    return x*x - x



def integrate_f(a, b, N):
    s = 0
    dx = (b - a) / N
    for i in xrange(N):
        s += f(a+i*dx)
    return s * dx

if __name__ == '__main__':
    print timeit.timeit('integrate_f(0,10,10000)', 'from __main__ import integrate_f',   number=100)
    print timeit.timeit('integrate_f(0,10,10000)', 'from cintegrate import integrate_f', number=100)
    print (timeit.timeit('integrate_f(0,10,10000)', 'from __main__ import integrate_f',   number=1000) /
           timeit.timeit('integrate_f(0,10,10000)', 'from cintegrate import integrate_f', number=1000))
