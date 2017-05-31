from distutils.core import setup
from distutils.extension import Extension
from Cython.Build import cythonize

exmods=[Extension("cintegrate", ["cintegrate.py"])]


setup(ext_modules=cythonize(exmods))
