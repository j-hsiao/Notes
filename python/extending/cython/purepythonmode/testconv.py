import cv2
import convtest
import time


if __name__ == '__main__':
    cap = cv2.VideoCapture(0)
    s, f = cap.read()
    c = convtest.convthis()

    tottime = 0
    nf = 0
    while s:
        now = time.time()
        j = c.do(f)
        tottime += time.time() - now
        nf += 1

        cv2.imshow('f', f)
        cv2.imshow('j', j)
        
        
        s, f = cap.read()
        switch = cv2.waitKey(1) & 0xFF
        if switch == ord('q'):
            s = False
    print '{}/{}={}'.format(nf, tottime, nf / tottime)
    cap.release()


#193 compile no change
#192.85 no compile
#191 compile  self.f = object, no assign to nparray
#196 compile, self.f = object, convert to np.ndarray
#194.8 compile, some stuff, 
#196 ish remove boundscheck and wraparound
#pyx, all = 196 or so
