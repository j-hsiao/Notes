import argparse
import codecs
import collections
import datetime
import heapq
import re
import select
import socket
import subprocess
import sys
import threading
import tkinter as tk
from tkinter import messagebox
import time
import traceback
import os



_TIMEPAT = re.compile(r'^(?:(?=.*[ -])(?:(?=.*-.*-)(?P<year>\d+)?-)?(?:(?P<month>\d+)?-)?(?P<day>\d+)? ?)?(?:(?P<hours>\d+(?:\.\d+)?)?:)?(?P<minutes>\d+(?:\.\d+)?)?(?::(?P<seconds>\d+(?:\.\d+)?)?)?$')
def parse_time(timespec, delay=False):
    """Convert a time string into a target time.

    If the time has already passed and am, then assume pm was desired.
    """
    m = _TIMEPAT.match(timespec)
    if not m:
        raise ValueError(f'bad time: {timespec}')
    times = list(m.groups())
    assert len(times) == 6
    now = datetime.datetime.now()
    deltas = ('days', 'hours', 'minutes', 'seconds')
    if delay:
        if any(times[:2]):
            raise ValueError('Delay only supports day, hour, minute, second.')
        info = dict(zip(deltas, [float(i) if i else 0 for i in times[2:]]))
        return now + datetime.timedelta(**info)
    else:
        found = 0
        extra = {}
        for i in range(len(times)):
            if times[i]:
                found = 1
                if i >= 2:
                    f = float(times[i])
                    times[i] = int(f)
                    extra[deltas[i-2]] = f-times[i]
                else:
                    times[i] = int(times[i])
            else:
                times[i] = int(i < 3) if found else now.timetuple()[i]
        target = datetime.datetime(*times) + datetime.timedelta(**extra)
        if target < now and (now - target).total_seconds() < 12*60*60:
            target += datetime.timedelta(hours=12)
        return target

DATE_FMT = '%Y-%m-%d %H:%M:%S.%f'
DATE_SHOW = '%Y-%m-%d %H:%M:%S'
class Server(object):
    def __init__(self, args):
        self.persist = args.persist
        self.verbose = args.verbose
        self.port = args.port
        self.lock = threading.Lock()
        self.reminders = []
        self.ready = collections.deque()
        self.running = True

        self.tk = tk.Tk()
        self.tk.withdraw()
        self.tk.createcommand('CheckNotifications', self._check_notifications)
        self.notifying = tk.BooleanVar(self.tk, False)
        self.tk.bind('<<CheckNotifications>>', f'if {{!${self.notifying}}} {{CheckNotifications}}')

    def eprint(self, *args, **kwargs):
        if self.verbose:
            kwargs.setdefault('file', sys.stderr)
            print(*args, **kwargs)

    def run(self):
        t = threading.Thread(target=self.run_server)
        t.start()
        self.tk.mainloop()
        t.join()

    def _check_notifications(self):
        """Display popups sequentially."""
        self.notifying.set(True)
        try:
            while 1:
                self.eprint('  grabbing lock', datetime.datetime.now())
                with self.lock:
                    self.eprint('  lock grabbed', datetime.datetime.now())
                    if self.ready:
                        target, message = self.ready.popleft()
                    else:
                        self.eprint('  no notifications ready')
                        break
                # It seems like at least deiconify is required
                # or the popup might be behind everything else, and not even have an icon.
                self.tk.deiconify()
                self.tk.attributes('-topmost', True)
                self.tk.update_idletasks()
                self.tk.withdraw()
                messagebox.showinfo(title='Reminder', message=f'{target.strftime(DATE_SHOW)}\n\n{message}')
            with self.lock:
                if self.running:
                    self.eprint('  still running')
                    return
            self.eprint('  running has ended...')
            if self.reminders:
                self.eprint('  has unhandled messages.')
                messagebox.showinfo(
                    title='Unhandled messages',
                    message='\n'.join([
                        f'{target.strftime(DATE_SHOW)}:\n{message}\n'
                        for target, message in self.reminders]))
            self.eprint('  schedule destruction after idle')
            self.tk.call('after', 'idle', f'destroy {self.tk}')
        finally:
            self.notifying.set(False)

    def run_server(self):
        L = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
        try:
            L.setsockopt(socket.SOL_SOCKET, socket.SO_REUSEADDR, 1)
            L.bind(('localhost', self.port))
            print(f'bound to {L.getsockname()}')
            sys.stdout.flush()
            L.listen(5)
            wait = None
            while 1:
                r, w, x = select.select([L], (), (), wait)
                if r:
                    s, a = L.accept()
                    try:
                        with s.makefile('r') as rf:
                            command = rf.readline().rstrip('\r\n')
                            if command == 'exit':
                                s.sendall(b'exiting\n')
                                return
                            elif command == 'list':
                                with s.makefile('w') as wf:
                                    print('Scheduled reminders:', file=wf)
                                    for i, (target, message) in enumerate(self.reminders):
                                        print(f'{i}: {target.strftime(DATE_SHOW)}: {message}', file=wf)
                                    wf.flush()
                            elif command == 'check':
                                pass
                            elif command == 'cancel':
                                out = 0
                                cancels = set(map(int, rf.read().split()))
                                with s.makefile('w') as wf:
                                    for i, item in enumerate(self.reminders):
                                        if i in cancels:
                                            print(f'Canceled {item[0].strftime(DATE_SHOW)}: {item[1]}', file=wf)
                                        else:
                                            self.reminders[out] = item
                                            out += 1
                                del self.reminders[out:]
                                heapq.heapify(self.reminders)
                            else:
                                try:
                                    target = datetime.datetime.strptime(command, DATE_FMT)
                                except Exception:
                                    s.sendall(traceback.format_exc().encode('utf-8'))
                                else:
                                    message = rf.read()
                                    heapq.heappush(self.reminders, (target, message))
                                    s.sendall(f'{datetime.datetime.now().strftime(DATE_SHOW)}: Scheduled reminder:\n\n{target.strftime(DATE_SHOW)}\n\n{message}\n'.encode('utf-8'))
                    except Exception:
                        traceback.print_exc()
                    finally:
                        s.close()
                now = datetime.datetime.now()
                nready = []
                while self.reminders and self.reminders[0][0] < now:
                    nready.append(heapq.heappop(self.reminders))
                if nready:
                    with self.lock:
                        self.ready.extend(nready)
                    self.tk.event_generate('<<CheckNotifications>>', when='tail')
                if self.reminders:
                    wait = min(60, max(0, (self.reminders[0][0] - now).total_seconds()))
                    self.eprint('waittime is', wait)
                elif self.persist:
                    wait = None
                else:
                    return
        except Exception:
            traceback.print_exc()
        finally:
            L.close()
            self.eprint('server socket closed')
            with self.lock:
                self.running = False
            self.tk.event_generate('<<CheckNotifications>>', when='tail')


COMMANDS = ('exit', 'list', 'cancel')
def send_command(args, retrying=False):
    """Send client command to server. Start server if it is down."""
    s = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
    try:
        try:
            s.connect(('localhost', args.port))
        except Exception:
            if retrying:
                traceback.print_exc()
            elif args.cmd in COMMANDS or not args.auto:
                if args.verbose:
                    print('Server not active.')
                return 1
            else:
                with open(os.path.join(os.environ['HOME'], '.reminder'), 'ab') as logf:
                    cmd = [sys.executable, sys.argv[0], '-s']
                    if args.verbose:
                        cmd.append('-v')
                    if args.persist:
                        cmd.append('--persist')
                    p = subprocess.Popen(
                        cmd, bufsize=0,
                        stdout=subprocess.PIPE,
                        stderr=logf.fileno())
                p.stdout.readline()
                print('Server pid:', p.pid)
                send_command(args, True)
        else:
            with s.makefile('w') as wf:
                if args.cmd in COMMANDS:
                    print(args.cmd, file=wf)
                else:
                    print(parse_time(args.cmd, args.delay).strftime(DATE_FMT), file=wf)
                if args.extra:
                    print(' '.join(args.extra), end='', file=wf)
                wf.flush()
            s.shutdown(socket.SHUT_WR)
            with s.makefile('r') as rf:
                for line in rf:
                    print(line, end='')
        return 0
    finally:
        s.close()

if __name__ == '__main__':
    p = argparse.ArgumentParser()
    p.add_argument('-s', '--server', action='store_true', help='act as the server, otherwise client.')
    p.add_argument('-p', '--port', type=int, default=58008, help='reminder server port.')
    p.add_argument('-d', '--delay', action='store_true', help='the given times are delays.')
    p.add_argument('-v', '--verbose', action='store_true')
    p.add_argument('-c', '--check', action='store_true')
    p.add_argument('-a', '--auto', action='store_true')
    p.add_argument('--persist', action='store_true', help='Server remains up even if no more notifications.')
    p.add_argument('cmd', nargs='?', help=f'the client command: a time specification (YYYY-mm-dd HH:MM:SS), floats allowed, omissions allowed. or one of {COMMANDS}.')
    p.add_argument('extra', nargs='*', help='remaining extra arguments for command.')
    args = p.parse_args()

    if args.check:
        print('now:', datetime.datetime.now().strftime(DATE_FMT))
        print('tgt:', parse_time(args.cmd, args.delay).strftime(DATE_FMT))
    elif args.server:
        print('server main thread number:', threading.get_native_id())
        Server(args).run()
    else:
        sys.exit(send_command(args))
