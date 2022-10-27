import timeit
import cintegrate
import integrate
if __name__ == '__main__':
    print timeit.timeit('integrate_f(0.,10.,10000)', 'from integrate import integrate_f', number=100)
    print timeit.timeit('integrate_f(0.,10.,10000)', 'from cintegrate import integrate_f',number=100)

    print (timeit.timeit('integrate_f(0.,10.,10000)', 'from integrate import integrate_f', number=100) /
           timeit.timeit('integrate_f(0.,10.,10000)', 'from cintegrate import integrate_f',number=100))
    print cintegrate.integrate_f(0.,10.,10000)
    print integrate.integrate_f(0.,10.,10000)
