import classtest
import classt
import timeit



if __name__=='__main__':
    c1 = classtest.fib()
    c2 = classt.fib()

    print timeit.timeit('c1.next(50)', 'from __main__ import c1', number = 1000)
    print timeit.timeit('c2.next(50)', 'from __main__ import c2', number = 1000)
    print c1.next(50)
    print '------------------------------'
    print c2.next(50)
