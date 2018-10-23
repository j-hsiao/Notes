from .. import b
print(b)
n = getattr(__import__('py3.n', globals(), locals()), 'n')
# from ...py3 import n
print(n)
# import hi
hi = getattr(
    __import__('py3.c', globals(), locals(), ['hi']),
    'hi')
print(hi)
