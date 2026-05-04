import cv2
import numpy as np


def showkp(name, im, kp):
    print(name, len(kp))
    im = im.copy()
    for pt in kp:
        cv2.circle(im, tuple(map(int, pt.pt)), 3, 127, -1)
    cv2.imshow(name, im)


srcim = np.zeros((480,640), np.uint8)
tgtim = np.zeros((480,640), np.uint8)

cv2.circle(srcim, (60,60), 50, 255, 3)
cv2.circle(tgtim, (500,400), 50, 255, 3)

sft = cv2.SIFT_create()

kp1, des1 = sft.detectAndCompute(srcim, None)
kp2, des2 = sft.detectAndCompute(tgtim, None)

print(len(kp1), len(kp2))
showkp('src', srcim, kp1)
showkp('tgt', tgtim, kp2)
while cv2.waitKey(0)&0xFF != ord('q'):
    pass

skp = []
tkp = []
for m1, m2 in cv2.FlannBasedMatcher().knnMatch(des1, des2, k=2):
    if m1.distance < 0.7 * m2.distance:
        skp.append(kp1[m1.queryIdx])
        tkp.append(kp2[m1.trainIdx])


spt = cv2.KeyPoint.convert(skp)
tpt = cv2.KeyPoint.convert(tkp)

print(spt.shape)
print(tpt.shape)

Tx, mask = cv2.findHomography(spt, tpt, cv2.RANSAC, 5.0)
print(Tx, mask)

if Tx is not None:
    cv2.imshow('warp src to tgt', cv2.warpPerspective(srcim, Tx, srcim.shape[1::-1]))
    cv2.imshow('warp tgt to src', cv2.warpPerspective(tgtim, Tx, srcim.shape[1::-1], flags=cv2.WARP_INVERSE_MAP))
    cv2.imshow('src', srcim)
    cv2.imshow('tgt', tgtim)

    while cv2.waitKey(0)&0xFF != ord('q'):
        pass
