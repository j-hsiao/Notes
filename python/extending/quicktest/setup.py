from distutils.core import setup
from distutils.extension import Extension
from Cython.Build import cythonize


e = [Extension("test", ["test.pyx"]),
     Extension("test2", ["test2.pyx"])]

setup(ext_modules=cythonize(e))
