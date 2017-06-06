from distutils.core import setup
from distutils.extension import Extension
from Cython.Build import cythonize

exten = [Extension("f", ["f.pyx"]),
         Extension("cintegrate", ["cintegrate.pyx"]),
         Extension("tint", ["tint.pyx"])]

setup(ext_modules=cythonize(exten))
