import logging


if __name__ == '__main__':
    formattedhandler = logging.StreamHandler()
    rawhandler = logging.StreamHandler()

    formattedhandler.setFormatter(
        logging.Formatter('%(asctime)s.%(msecs)d | %(message)s', '%Y-%m-%d %H:%M:%S'))

    rootLogger = logging.getLogger('root')
    testLogger = rootLogger.getChild('testing')
    testLogger.setLevel(69)
    #child = testLogger.getChild('child')
    child = logging.getLogger('root.testing.child')
    child.setLevel(1)
    c2 = child.getChild('child2')




    print(dir(testLogger.parent))

    print(testLogger.parent.handlers)

    print(testLogger.getEffectiveLevel())
    print(child.getEffectiveLevel())
    print(c2.getEffectiveLevel())


    rootLogger.addHandler(rawhandler)
    testLogger.addHandler(formattedhandler)
    child.addHandler(rawhandler)
    c2.addHandler(rawhandler)

    c2.log(80, 'hello')
