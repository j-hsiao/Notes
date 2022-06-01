# from libc.stdlib cimport atoi

cdef extern from "stdlib.h":
  cpdef int atoi(char* x)
  cpdef int abs(int x) except -1



def fib(n):
    a, b = 0, 1
    while b < n:
        print b,
        a, b = b, a + b
