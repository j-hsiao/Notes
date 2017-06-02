from fortest.fortest import *
import timeit


rc = 'ct{}({})'
rp = 'pt{}({})'

ic = 'from fortest.fortest import ct{}'
ip = 'from fortest.fortest import pt{}'

args=[None, 100, 5, '"i am a person who is a person and am a person"']
nums=[None, 10000, 10000, 10000]

for i in xrange(1,3 + 1):
    print '------------------------------'
    print timeit.timeit(rc.format(i, args[i]), ic.format(i), number=nums[i])
    exec('print {}'.format(rc.format(i, args[i])))
    print timeit.timeit(rp.format(i, args[i]), ip.format(i), number=nums[i])
    exec('print {}'.format(rp.format(i, args[i])))

