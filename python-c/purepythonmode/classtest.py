import cython



@cython.cclass
class fib:
    cython.declare(a=cython.ulonglong, b=cython.ulonglong)
    def __init__(self):
        self.a = 0
        self.b = 1

    @cython.ccall
    @cython.locals(t=cython.ulonglong, i=cython.int)
    @cython.returns(cython.ulonglong)
    def next(self, num):
        self.a = 0
        self.b = 1
        for i in xrange(num):
            t = self.a + self.b
            self.a = self.b
            self.b = t


        return self.b - self.a
