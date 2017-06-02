from distutils.core import setup
from distutils.extension import Extension
from Cython.Build import cythonize

em = [Extension("fortest.fortest", ["fortest/fortest.pyx"])]



setup(name = "fortest", ext_modules = cythonize(em))
