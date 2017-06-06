import cintegrate
import integrate
import timeit




n = 100
print timeit.timeit('cintegrate.integrate_f(0, 10, 10000)', 'import cintegrate', number=n)
print timeit.timeit('integrate.integrate_f(0, 10, 10000)', 'import integrate', number=n)
print timeit.timeit('tint.integrate_f(0, 10, 10000)', 'import tint', number=n)
