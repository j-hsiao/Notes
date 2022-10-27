all: puretest.pyd
	echo done

puretest.pyd:puretest.py
	python setup.py build_ext --inplace --compiler=mingw32


inte:cintegrate.pyd
	echo done


cintegrate.pyd:cintegrate.py
	python sint.py build_ext --inplace --compiler=mingw32

