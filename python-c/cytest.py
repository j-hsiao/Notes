import sys
import os
sys.path.insert(0, os.path.join(os.path.dirname(__file__), 'cythontest'))
import hello
import time


def f(x):
    return x**2 - x
def integrate_f(a, b, N):
    s = 0
    dx = (b - a) / N
    for i in xrange(N):
        s += f(a+i*dx)
    return s * dx





def t(f, v):
    now = time.time()
    print f(v)
    print time.time() - now

def ii(j):
    v = 0
    for i in xrange(j):
        v += 1
    return v

import timeit

if __name__ == '__main__':
    runs = 10000000
    t(ii, runs)
    t(hello.iterincre, runs)
    
    
    timport = """
from __main__ import t, ii, f, integrate_f
import sys
import os
sys.path.insert(0, os.path.join(os.path.dirname(__file__), 'cythontest'))
import hello
"""

    print timeit.timeit('ii(1000)', timport, number=100)
    print timeit.timeit('hello.iterincre(1000)', timport, number=100)
    print timeit.timeit('integrate_f(0,10,10000)', timport, number=100)
    print timeit.timeit('hello.integrate_f(0,10,10000)', timport, number=100)
