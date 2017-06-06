

def f(x):
    return x*x - x - 10



def integrate_f(a, b, N):
    s = 0
    dx = (b - a) / N
    for i in xrange(N):
        s += f(a+i*dx)
    return s * dx

