pi: withcy.pyd
	echo done
withcy.pyd:withcy.py
	python setup.py -t withcy build_ext --inplace --compiler=mingw32




inte:cintegrate.pyd
	echo done
cintegrate.pyd:cintegrate.py
	python setup.py -t inte build_ext --inplace --compiler=mingw32



fib:classtest.pyd
	echo done
classtest.pyd:classtest.py
	python setup.py -t fib build_ext --inplace --compiler=mingw32




conv:convtest.pyd
	echo done

convtest.pyd:convtest.py
	python setup.py -t conv build_ext --inplace --compiler=mingw32


multi: mt.pyd
	echo done

mt.pyd:mt.py mt1.py
	python setup.py -t mt build_ext --inplace --compiler=mingw32

m2:mt1.pyd
	echo done
mt1.pyd:mt1.py mt.py
	python setup.py -t mt2 build_ext --inplace --compiler=mingw32


m3:mt2.pyd
	echo done
mt2.pyd:mt2.pyx
	python setup.py -t mt3 build_ext --inplace --compiler=mingw32
mf:m10.pyd
	echo done
m10.pyd:m10.pyx m11.pyx
	python setup.py -t m10 build_ext --inplace --compiler=mingw32

