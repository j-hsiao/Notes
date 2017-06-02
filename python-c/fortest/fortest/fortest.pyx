import os

#for loops test
cpdef int ct1(int i):
    cdef int j
    for j in xrange(i):
        j=j
    return j


def pt1(i):
    for j in xrange(i):
        j=j
    return j



#if statement test
cpdef int ct2(int i):
    if (i < 10):
        return i * 10
    else:
        return i + 10
def pt2(i):
    if (i < 10):
        return i * 10
    else:
        return i + 10


#lots of python calls test
cpdef str ct3(str p):
    return ' '.join([a for a in p])

def pt3(p):
    return ' '.join([a for a in p])

ct4
pt4 = pt2
