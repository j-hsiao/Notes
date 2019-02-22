import timeit
NUMBER=10
REPEAT=10
SETUP = '''
import numpy as np
a = np.arange(2500).reshape(50,50).astype(np.float64)
b = np.arange(2500,5000).reshape(50,50).astype(np.float64)
einpath, blah = np.einsum_path('ij,jk->ik', a, b, optimize = 'optimal')

'''
def ti(script):
    print(script)
    print(min(timeit.repeat(
        script,
        SETUP,
        number = NUMBER, 
        repeat = REPEAT)))

if __name__ == '__main__':
    ti("np.matmul(a, b)")
    ti("np.einsum('ij,jk->ik', a, b)")
    ti("np.tensordot(a,b,(1,0))")
    exec(SETUP)
    n1 = np.einsum('ij,jk->ik', a, b)
    n2 = np.matmul(a,b)
    n3 = np.tensordot(a,b,(1,0))
    print(np.all(n1 == n2))
    print(np.all(n1 == n3))

    print

    ti("np.einsum('ij,ij->', a, b)")
    ti("(a * b).sum()")
    ti("np.tensordot(a,b)")
    n1 = np.einsum('ij,ij->', a, b)
    n2 = (a*b).sum()
    n3 = np.tensordot(a,b)
    print(n1, n2)
    print(np.all(n1 == n2))
    print(np.all(n2==n3))
