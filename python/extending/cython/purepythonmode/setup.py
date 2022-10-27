from distutils.core import setup
from distutils.extension import Extension
from Cython.Build import cythonize
import sys
import numpy as np


mods={'withcy':[Extension("withcy", ["withcy.py"])],
      'fib'   :[Extension("classtest", ["classtest.py"])],
      'inte'  :[Extension("cintegrate", ["cintegrate.py"])],
      'conv'  :[Extension("convtest", ["convtest.py"], include_dirs=[np.get_include()])],
      'mt'    :[Extension("mt", ["mt.py", "mt1.py"])],
      'mt2'   :[Extension("mt", ["mt.py"]),
                Extension("mt1", ["mt1.py"])],
      'mt3'   :[Extension("mt2", ["mt2.pyx", "mt3.pyx"])],
      'm10'   :[Extension("m11", ["m11.pyx"]),
                Extension("m10", ["m10.pyx"])]}


TARGET=''
if len(sys.argv) > 1:
    if sys.argv[1] == '-t':
        TARGET = sys.argv[2]
    print 'making', sys.argv[2]
    sys.argv = [sys.argv[0]] + sys.argv[3:]

if TARGET in mods:
    setup(ext_modules=cythonize(mods[TARGET]))
