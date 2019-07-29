import logging


if __name__ == '__main__':
    logging.basicConfig(
        format = '%(asctime)s.%(msecs)d:%(levelname)-10s::%(message)s',
        datefmt = '%F %H:%M:%S',
        level = 0)
    logging.log(73, 'hello world!')
    logging.info('goodbye world!')
