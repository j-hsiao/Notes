from __future__ import absolute_import, division, print_function

import numpy as np
import tensorflow as tf

sess = tf.Session()
a = tf.constant(3.0)
b = tf.constant(4.)
print(a, b, a+b)
print(sess.run(a+b))
print(sess.run(dict(ab = (a,b), total = a+b)))

p = tf.placeholder(tf.int64)
data = tf.data.Dataset.range(p)
it = data.make_initializable_iterator()
n = it.get_next()
i = it.initializer
l = 1
#while l:
#    l = int(raw_input('iterations: '))
#    sess.run(i, feed_dict = {p : l})
#    try:
#        while 1:
#            print(sess.run(n))
#    except tf.errors.OutOfRangeError:
#        pass

print('linear model')
x = np.arange(10).reshape(10,1).astype(np.float32)
y = x * 2
print(dir(x))

#model
inval = tf.placeholder(x.dtype, x.shape)
answers = tf.placeholder(y.dtype, y.shape)
model = tf.layers.Dense(units = 1)
out = model(inval)

sess.run(tf.global_variables_initializer())

print(sess.run(out, feed_dict = {inval : x}))

#error
error = tf.losses.mean_squared_error(
    labels = answers,
    predictions = out)
errorv, outv = sess.run((error, out), {answers : y, inval: x})
print(errorv)
print(((outv - y) ** 2).sum() / y.size)
print(outv)

#train
train = tf.train.GradientDescentOptimizer(0.01).minimize((error))
for i in range(1000):
    _, errorv, outv = sess.run(
        (train, error, out),
        feed_dict = {inval : x, answers : y})
    print(errorv)
    print(outv)

