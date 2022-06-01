COMPILER_FLAG:=--compiler=mingw32

all:hello.pyd fib.pyd
	echo done

fib.pyd: fib.pyx
	echo make fib
	python setup.py build_ext --inplace $(COMPILER_FLAG)

hello.pyd:hello.pyx
	echo make hello
	python setup.py build_ext --inplace $(COMPILER_FLAG)

test: hello.pyd ../cytest.py
	python ../cytest.py
