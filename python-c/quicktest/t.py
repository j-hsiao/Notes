import timeit
class blah:
    def __init__(self):
        self.sum = 0
        self.i   = 0
    def nxt(self):
        self.sum += self.i * self.i
        self.i += 1
        return self.sum


if __name__ == '__main__':
    v=1000
    print timeit.timeit('b = blah()\nn=b.nxt\nfor i in xrange({}):\n\tn()\n'.format(v), 'from __main__ import blah',number=100)
    print timeit.timeit('b = blah()\nfor i in xrange({}):\n\tb.nxt()\n'.format(v), 'from __main__ import blah',number=100)
