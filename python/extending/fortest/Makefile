all: fortest/fortest.pyd

fortest/fortest.pyd:fortest/fortest.pyx
	python setup.py build_ext --inplace --compiler=mingw32


test:
	python test.py
