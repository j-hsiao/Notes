test: test.pyd
	echo done
test.pyd: test.pyx test.pxd
	python setup.py build_ext --inplace --compiler=mingw32

test2: test2.pyd
	echo done
test2.pyd: test2.pyx test2.pxd test2.py
	python setup.py build_ext --inplace --compiler=mingw32
