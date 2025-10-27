import cv2
import numpy as np
import av
import argparse


p = argparse.ArgumentParser()
p.add_argument('f')
args = p.parse_args()

print(av.open is av.container.open)
with av.container.open(args.f, 'r') as container:
    print(type(container.streams.audio))
    print(container.streams.video[0].time_base)
    print(type(container.streams.video[0].time_base))
    print(container.format)
    print(container.file)
    print(type(container.flags))
    print(container.name)
    print(container.open_timeout)
    print(container.read_timeout)
print(av.time_base)

print(dir(av.container.Container))

help(av.ContainerFormat)

thing = av.ContainerFormat('Matroska')
