import numpy as np
import struct
as_strided = np.lib.stride_tricks.as_strided

x = np.arange(5*5*5*5).reshape(5,5,5,5)
s = 0
for i in range(5):
    for j in range(5):
        s += x[j,i,j,i]

y = as_strided(x, shape = (5,5), strides = ((5*5*5 + 5)*x.itemsize,26 * x.itemsize))
s2 = y.sum()

print s
print s2
