all: cintegrate.pyd f.pyd tint.pyd

f.pyd:f.pyx
	python setup.py build_ext --inplace --compiler=mingw32

cintegrate.pyd:cintegrate.pyx
	python setup.py build_ext --inplace --compiler=mingw32

tint.pyd:tint.pyx
	python setup.py build_ext --inplace --compiler=mingw32
