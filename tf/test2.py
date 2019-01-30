# distributed tensorflow testing notes

import tensorflow as tf
from tensorflow.python.framework import device as pydev
if __name__ == '__main__':
    print(tf.DeviceSpec(job = "worker", replica = 1).to_string())
    spec = pydev.DeviceSpec.from_string("/job:worker")
    print(spec)
    print(spec.to_string())
    print(spec.replica)
    print(dir(spec))
