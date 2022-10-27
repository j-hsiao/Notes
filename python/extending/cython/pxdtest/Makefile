all: cintegrate.pyd f.pyd tint.pyd

f.pyd:f.pyx
	python setup.py build_ext --inplace

cintegrate.pyd:cintegrate.pyx
	python setup.py build_ext --inplace

tint.pyd:tint.pyx
	python setup.py build_ext --inplace
