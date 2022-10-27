from distutils.core import setup
from distutils.extension import Extension
from Cython.Build import cythonize

ext_mods = [Extension("calc_pi",
                      sources=["calc_pi.pyx"])]

setup(ext_modules=cythonize(ext_mods),)




# setup(name = 'learn cython',
#       ext_modules = cythonize("fib.pyx"), )
# setup(name = 'Hello world app',
#       ext_modules = cythonize("hello.pyx"),)
