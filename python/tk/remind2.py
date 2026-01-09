import argparse
import codecs
import datetime
import heapq
import io
import os
import re
import select
import socket
import subprocess
import sys
import textwrap
import tkinter as tk
from tkinter import messagebox
import traceback

DATE_FMT = '%Y-%m-%d %H:%M:%S.%f'

pat = re.compile(r'^(?:(?=.*[ -])(?:(?=.*-.*-)(?P<year>\d+)?-)?(?:(?P<month>\d+)?-)?(?P<day>\d+)? ?)?(?:(?P<hours>\d+(?:\.\d+)?)?:)?(?P<minutes>\d+(?:\.\d+)?)?(?::(?P<seconds>\d+(?:\.\d+)?)?)?$')

def schedule_reminder(args, recursed=False):
    if not args.exit:
        print(args.time)
        m = pat.match(args.time)
        if not m:
            raise ValueError(f'bad time: {args.time}')
        times = list(m.groups())
        assert len(times) == 6
        now = datetime.datetime.now()
        if args.delay:
            if any(times[:2]):
                raise ValueError('Delay cannot include year or month.')
            info = dict(zip(
                'days hours minutes seconds'.split(),
                [float(i) if i else 0 for i in times[2:]]))
            target = now + datetime.timedelta(**info)
        else:
            found = 0
            extra_seconds = 0
            for i in range(len(times)-1, -1, -1):
                if times[i]:
                    f = float(times[i])
                    times[i] = int(f)
                    extra_seconds += (f-times[i]) * (0, 0, 24*60*60, 60*60, 60, 1)[i]
                    found = 1
                    if not times[i]:
                        times[i] = (1, 1, 1, 0, 0, 0)[i]
                else:
                    times[i] = now.timetuple()[i] if found else (1, 1, 1, 0, 0, 0)[i]
            target = datetime.datetime(*times) + datetime.timedelta(seconds=extra_seconds)
            if target < now and target.hour < 12:
                target += datetime.timedelta(hours=12)
        print('target time:', target.strftime(DATE_FMT))
    s = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
    try:
        s.settimeout(1)
        try:
            s.connect(('localhost', args.port))
            s.settimeout(None)
            with s.makefile('w') as f:
                if args.exit:
                    f.write('exit')
                    f.flush()
                else:
                    target = (datetime.datetime.now() + datetime.timedelta(seconds=5)).strftime(DATE_FMT)
                    print(target, file=f)
                    print(' '.join(args.message), file=f)
                    f.flush()
                s.shutdown(socket.SHUT_WR)
                buf = bytearray(io.DEFAULT_BUFFER_SIZE)
                amt = s.recv_into(buf)
                decoder = codecs.getincrementaldecoder('utf-8')()
                while amt:
                    print(decoder.decode(buf[:amt]), end='')
                    amt = s.recv_into(buf)
                print(decoder.decode(b'', final=True))
        except Exception:
            if recursed:
                print('Error!')
                traceback.print_exc()
            else:
                p = subprocess.Popen([sys.executable, sys.argv[0], '-s'], stdout=sp.PIPE)
                p.stdout.readline()
                p.stdout.close()
                print('server pid:', p.pid)
                schedule_reminder(args)
    finally:
        s.close()

def show(r, tp='info', **kwargs):
    # the update() seems to be necessary
    # or the popup might get frozen on destruction
    # moving connection handling into a separate thread
    # would probably make this unnecessary.
    getattr(messagebox, 'show'+tp)(**kwargs)
    r.update()

def run_server(args):
    # TODO: tk gui unresponsive...
    # probably need a thread
    # put server into thread 1
    # gui mainloop into thread 0
    # ...???
    reminders = []
    tkroot = tk.Tk()
    tkroot.withdraw()
    try:
        tkroot.withdraw()
        L = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
        try:
            L.bind(('localhost', args.port))
            L.listen(5)
            print('bound')
            sleep = 60
            while 1:
                r, w, x = select.select([L], (), (), sleep)
                if r:
                    s, a = L.accept()
                    try:
                        with s.makefile('r') as f:
                            dt = f.readline()
                            message = f.read()
                            try:
                                target = datetime.datetime.strptime(dt.strip(), DATE_FMT)
                                show(tkroot, message=f'Scheduling reminder:\n{target}\n{message}')
                                heapq.heappush(reminders, (target, message))
                                s.send(b'ok')
                            except Exception:
                                if dt.strip() == 'exit':
                                    s.send(b'exiting')
                                    return
                                else:
                                    s.send(traceback.format_exc().encode('utf-8'))
                    finally:
                        s.close()
                now = datetime.datetime.now()
                while reminders:
                    if reminders[0][0] < now:
                        show(tkroot, message=reminders[0][1])
                        heapq.heappop(reminders)
                    else:
                        sleep = min((reminders[0][0] - now).total_seconds(), 60)
                        break
                else:
                    sleep = 60
        except Exception:
            show(
                tkroot, 'error',
                title='server crash.',
                message='Error! server crashed:\n' + traceback.format_exc())
        finally:
            L.close()
    finally:
        if reminders:
            parts = ['Unprocessed reminders:\n']
            for target, message in reminders:
                parts.append(f'{target}: {message}\n')
            show(tkroot, title='server exit', message=''.join(parts))
        tkroot.destroy()


if __name__ == '__main__':
    p = argparse.ArgumentParser()
    p.add_argument('-s', '--server', action='store_true')
    p.add_argument('-p', '--port', type=int, default=58008)
    p.add_argument('-e', '--exit', action='store_true')
    p.add_argument('-d', '--delay', help='interpret time as a delay instead of target time.', action='store_true')
    p.add_argument('time', nargs='?')
    p.add_argument('message', nargs=argparse.REMAINDER)
    args = p.parse_args()
    if args.server:
        run_server(args)
    else:
        schedule_reminder(args)
