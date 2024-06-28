import skimage
from skimage import filters
import os
import cv2
from skimage import io
import numpy as np
"""
ofilename = os.path.join(skimage.data_dir, 'camera.png')
camera = io.imread('http://scikit-image.org/_static/img/logo.png')
a = np.ones((5,5), np.float32)

a = a * -1
print a

cv2.imshow('hello', camera)
cv2.imshow('test', a)
cv2.waitKey()
"""
"""
a = np.array([[1,2,3],[4,5,6],[7,8,9]])

b = filters.gaussian_filter(a.astype(np.float32) / 9, sigma=2)
from skimage.feature import corner_harris
c = corner_harris(a.astype(np.float32) / 9)
print a
print b

print c
"""
"""
from skimage import data

a = data.checkerboard()
from skimage.feature import corner_harris
b = corner_harris(a)


cv2.imshow('a', a)
cv2.imshow('b', b)
cv2.waitKey(0)
"""
# def asdf(f):
#     """
#     >>> assert 1 + 1 == 2
#     >>> 1 + 1
#     2

#     """
#     print f





# if __name__ == "__main__":
#     import doctest
#     print 'hallelujah'
#     doctest.testmod()

"""
a = io.imread(os.path.join(os.path.dirname(__file__), 'test.jpg'))
print skimage.color.guess_spatial_dimensions(a)
"""
"""
from skimage import draw
a = np.zeros((100,200), np.uint8)


x = np.zeros((0,0), np.uint8)
y = np.zeros((0,0), np.uint8)
for i in range(30,71):
    for j in range(60,141):
        x = np.append(x, j)
        y = np.append(y, i)

b = draw.set_color(a, (y,x), 255)
c = np.array(a)

cv2.imshow('c', c)
cv2.imshow('a', a)

cv2.waitKey(0)
"""


#a = cv2.cvtColor(a, cv2.COLOR_BGR2RGB)
"""
from skimage import feature
from skimage import data
from skimage import morphology
a = cv2.imread('tests/test.jpg')
b,g,r = cv2.split(a)

gray1 = (b.astype(np.float32) 
         + g.astype(np.float32)
         + r.astype(np.float32)) / 3

gray2 = cv2.cvtColor(a, cv2.COLOR_BGR2GRAY)
cup = filters.rank.maximum(gray2, np.ones((5,5))) - \
      filters.rank.minimum(gray2, np.ones((5,5)))
check = data.checkerboard()

checkf = filters.rank.subtract_mean(check, np.ones((5,5)))

a = morphology.star(100)

cv2.imshow('a', a * 255)
cv2.waitKey()

"""

from skimage import transform
a = cv2.imread('tests/test.jpg')
b = cv2.cvtColor(a, cv2.COLOR_BGR2GRAY)


y,x,z = a.shape
i = 0
while i < x:
    c = transform.swirl(b, (i,y/2), 50)
    i = i + 5
    cv2.imshow('swirled', c)
    cv2.waitKey(10)
