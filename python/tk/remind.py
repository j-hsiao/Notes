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
import platform
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
        if args.hide:
            import ctypes
            ctypes.windll.user32.ShowWindow(
                ctypes.windll.kernel32.GetConsoleWindow(), 0)
        self.persist = args.persist
        self.verbose = args.verbose
        self.notify = args.notify
        self.reuse = args.reuse
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
        # must be in mainloop for the exit event to be caught in case of
        # failed binding.
        self.tk.after(0, t.start)
        self.tk.mainloop()
        t.join()

    def _check_notifications(self):
        """Display popups sequentially."""
        self.notifying.set(True)
        try:
            while 1:
                with self.lock:
                    if self.ready:
                        target, message = self.ready.popleft()
                    else:
                        break
                # It seems like at least deiconify is required
                # or the popup might be behind everything else, and not even have an icon.
                self.tk.deiconify()
                self.tk.attributes('-topmost', True)
                self.tk.update_idletasks()
                self.tk.withdraw()
                now = datetime.datetime.now()
                if abs((now - target).total_seconds()) < 1:
                    messagebox.showinfo(title='Reminder', message=f'{target.strftime(DATE_SHOW)}\n\n{message}')
                else:
                    messagebox.showinfo(title='Reminder', message=f'now: {now.strftime(DATE_SHOW)}\n\ntgt: {target.strftime(DATE_SHOW)}:\n\n{message}')
            with self.lock:
                if self.running:
                    return
            if self.reminders:
                tl = tk.Toplevel(self.tk)
                txt = tk.Text(tl)
                txt.grid(row=0, column=0, sticky='nsew')
                tl.grid_columnconfigure(0, weight=1)
                tl.grid_rowconfigure(0, weight=1)
                yscroll = tk.Scrollbar(tl, command=txt.yview, orient='vertical')
                xscroll = tk.Scrollbar(tl, command=txt.xview, orient='horizontal')
                xscroll.grid(row=1, column=0, sticky='nsew')
                yscroll.grid(row=0, column=1, rowspan=2, sticky='nsew')
                txt.configure(xscrollcommand=xscroll.set, yscrollcommand=yscroll.set)
                tl.title('Unhandled messages')
                self.reminders.sort()
                txt.insert('end', f'now: {datetime.datetime.now().strftime(DATE_SHOW)}\n\n')
                for target, message in self.reminders:
                    txt.insert('end', f'{target.strftime(DATE_SHOW)}: {message}\n\n')
                txt.configure(state='disabled')
                b = tk.Button(tl, text='ok', command=f'destroy {tl}')
                b.grid(row=2, column=0, columnspan=2, sticky='nsew')
                b.focus_set()
                tl.wait_window()
            self.tk.call('after', 'idle', f'destroy {self.tk}')
        finally:
            self.notifying.set(False)

    def run_server(self):
        L = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
        try:
            if self.reuse:
                L.setsockopt(socket.SOL_SOCKET, socket.SO_REUSEADDR, 1)
            L.bind(('localhost', self.port))
            L.listen(5)
            if self.notify:
                s = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
                try:
                    s.connect(('localhost', self.notify))
                    s.recv(1)
                finally:
                    s.close()
            else:
                print(f'Server bound to {L.getsockname()}.')
            sys.stdout.flush()
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
                                self.reminders.sort()
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
                elif self.persist:
                    wait = None
                else:
                    return
        except Exception:
            traceback.print_exc()
        finally:
            L.close()
            with self.lock:
                self.running = False
            self.tk.event_generate('<<CheckNotifications>>', when='tail')


def launch(args):
    cmd = [sys.executable, os.path.realpath(sys.argv[0])]
    cargs = ['-s', '--port', str(args.port)]
    for opt in ('persist', 'reuse', 'verbose'):
        if getattr(args, opt):
            cargs.append('--'+opt)
    if platform.system() == 'Windows':
        import shutil
        if shutil.which('cygstart'):
            # cygstart --hide seems to be the most reliable if available.
            # It allows the terminal to always be closed, and does not result in a new
            # window
            cmd = ['cygstart', '--hide'] + cmd
        else:
            # start /B would not create a new window, BUT the program
            # will be killed if the terminal is closed.
            cmd = ['cmd', '/C', 'start', '/MIN'] + cmd
            cargs.append('--hide')
        cmd.extend(cargs)
        L = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
        try:
            L.bind(('localhost', 0))
            while L.getsockname()[1] == args.port:
                L.close()
                L = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
                L.bind(('localhost', 0))
            L.listen(1)
            cmd.extend(('--notify', str(L.getsockname()[1])))
            with open(os.path.join(os.environ.get('HOME', os.environ['USERPROFILE']), '.reminder'), 'ab') as logf:
                print('launching', cmd)
                p = subprocess.Popen(cmd, stdout=logf.fileno(), stderr=logf.fileno())
            L.settimeout(5)
            s, a = L.accept()
            s.close()
        finally:
            L.close()
    else:
        cmd.extend(cargs)
        with open(os.path.join(os.environ['HOME'], '.reminder'), 'ab') as logf:
            print('launching', cmd)
            p = subprocess.Popen(
                cmd, bufsize=0,
                stdout=subprocess.PIPE,
                stderr=logf.fileno())
        result = p.stdout.readline().decode('utf-8')
        if not result.startswith('Server bound to '):
            raise ValueError('Server startup failed: ' + result)
        print(result, end='')
    print('Server pid:', p.pid)
    return p


COMMANDS = ('exit', 'list', 'cancel', 'check')
def send_command(args, retrying=False):
    """Send client command to server. Start server if it is down."""
    if args.cmd.lower() == 'launch':
        launch(args)
        return
    s = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
    try:
        try:
            s.connect(('localhost', args.port))
        except Exception:
            if retrying:
                traceback.print_exc()
            elif args.cmd in COMMANDS:
                if args.verbose:
                    print('Server not active.')
                return 1
            else:
                p = launch(args)
                send_command(args, True)
        else:
            with s.makefile('w') as wf:
                if args.cmd in COMMANDS:
                    if args.cmd == 'check':
                        args.cmd = 'list'
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
    p.add_argument('-P', '--persist', action='store_true', help='Server remains up even if no more notifications.')
    p.add_argument('-r', '--reuse', action='store_true')
    p.add_argument('-v', '--verbose', action='store_true')
    p.add_argument('--hide', action='store_true', help='hide terminal on windows.')
    p.add_argument('--notify', type=int, help='Connect to this port to notify server ready.')

    p.add_argument('cmd', nargs='?', help=f'the client command: a time specification (YYYY-mm-dd HH:MM:SS), floats allowed, omissions allowed. or one of {COMMANDS}.')
    p.add_argument('extra', nargs='*', help='remaining extra arguments for command.')
    p.add_argument('-c', '--check', action='store_true', help='just check the time parsing.')
    p.add_argument('-p', '--port', type=int, default=58008, help='reminder server port.')
    p.add_argument('-d', '--delay', action='store_true', help='the given times are delays.')
    args = p.parse_args()

    if args.check:
        print('now:', datetime.datetime.now().strftime(DATE_FMT))
        print('tgt:', parse_time(args.cmd, args.delay).strftime(DATE_FMT))
    elif args.server:
        Server(args).run()
    else:
        sys.exit(send_command(args))
