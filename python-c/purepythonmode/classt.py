class fib:
    
    def __init__(self):
        self.a = 0
        self.b = 1

    def next(self, num):
        self.a = 0
        self.b = 1
        for i in xrange(num):
            t = self.a + self.b
            self.a = self.b
            self.b = t


        return self.b - self.a
