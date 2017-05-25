COMPILER_FLAG:=--compiler=mingw32

all:hello.pyd
	echo done

hello.pyd:hello.pyx
	python setup.py build_ext --inplace $(COMPILER_FLAG)

test: hello.pyd ../cytest.py
	python ../cytest.py
