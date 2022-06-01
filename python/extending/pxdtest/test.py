import cintegrate
import integrate
import timeit




n = 100
print 'cimport other .so: {}'.format(timeit.timeit('cintegrate.integrate_f(0, 10, 10000)', 'import cintegrate', number=n))
print 'only py:           {}'.format(timeit.timeit('integrate.integrate_f(0, 10, 10000)', 'import integrate', number=n))
print 'include method:    {}'.format(timeit.timeit('tint.integrate_f(0, 10, 10000)', 'import tint', number=n))
print 'include, pyfunc:   {}'.format(timeit.timeit('tint.integrate_ff(0, 10, 10000)', 'import tint', number=n))
