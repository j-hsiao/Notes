"""Example of using asyncio for stdin/stdout io.
"""
import asyncio
import io
import sys
import traceback

async def wait_for_input(cond, l):
    reader = asyncio.StreamReader()
    loop = asyncio.get_event_loop()
    tp, pt = await loop.connect_read_pipe(lambda: asyncio.StreamReaderProtocol(reader), sys.stdin)
    while not reader.at_eof():
        line = await reader.readline()
        async with cond:
            l.append(line)
            cond.notify_all()
    async with cond:
        l.append(None)
        cond.notify_all()

async def flush_outputs(cond, l):
    loop = asyncio.get_event_loop()
    tp, pt = await loop.connect_write_pipe(asyncio.streams.FlowControlMixin, sys.stdout)
    writer = asyncio.streams.StreamWriter(tp, pt, None, loop)

    print('transport', dir(tp), file=sys.stderr)
    print('protocol ', dir(pt), file=sys.stderr)

    running = True
    while running:
        async with cond:
            await cond.wait_for(lambda: bool(l))
            for item in l:
                if item is None:
                    running = False
                    break
                else:
                    writer.write(item)
            else:
                del l[:]
        await writer.drain()

class MyClass(object):
    def write(self, data):
        print('writing data:', repr(data), file=sys.stderr)
        return len(data)

    def flush(self):
        pass

async def testing(cond, l):
    loop = asyncio.get_event_loop()
    i=0
    try:
        tp, pt = await loop.connect_write_pipe(asyncio.streams.FlowControlMixin, MyClass())
    except Exception:
        print('Error connecting write pipe to file-like object without fd.', file=sys.stderr)
        traceback.print_exc()
        print('error end.', file=sys.stderr)
        while 1:
            async with cond:
                if None in l:
                    return
            print('dummy', i, file=sys.stderr)
            i += 1
            await asyncio.sleep(1)
    else:
        writer = asyncio.streams.StreamWriter(tp, pt, None, loop)
        while 1:
            async with cond:
                if None in l:
                    return
            writer.write('hello {}'.format(i))
            i += 1
            await writer.drain()
            await asyncio.sleep(1)


async def main():
    cond = asyncio.Condition()
    l = []
    results = await asyncio.gather(
        wait_for_input(cond, l),
        flush_outputs(cond, l),
        # testing(cond, l),
        return_exceptions=True
    )
    print(results, file=sys.stderr)


asyncio.run(main())
