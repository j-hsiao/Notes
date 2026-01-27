import argparse
import codecs
import collections
import datetime
import heapq
import io
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

DATE_FMT = '%Y-%m-%d %H:%M:%S.%f'
DATE_SHOW = '%Y-%m-%d %H:%M:%S'
def growbuf(buf):
    nbuf = bytearray(int(len(buf)*1.5))
    view = memoryview(nbuf)
    view[:len(buf)] = buf
    return view, nbuf

def readtil(sock, buf=None, total=0, target=None):
    """Nonblocking read until a target.

    Yield None until done.
    Return (buf, target, remainder) via StopIteration.value
        buf: the (possibly reallocated) buffer of data.
        target: the view of buf up to and including target
        remainder: the view of the remainder of the data.
    """
    if buf is None:
        buf = bytearray(io.DEFAULT_BUFFER_SIZE)
    view = memoryview(buf)
    while 1:
        try:
            amt = sock.recv_into(view[total:])
        except (BlockingIOError, socket.timeout):
            yield None
            continue
        if amt == 0:
            return buf, view[:total], view[total:total]
        ntotal = total + amt
        if target is not None:
            idx = buf.find(target, total, ntotal)
            if idx >= 0:
                end = idx+len(target)
                return buf, view[:end], view[end:ntotal]
        if ntotal >= len(buf):
            view, buf = growbuf(buf)
        total = ntotal

class Request(object):
    def __init__(self, sock, server):
        self.fileno = sock.fileno
        self.iter = self.loop(sock, server)

    @staticmethod
    def loop(sock, server):
        try:
            server.eprint('Handling socket', sock.getsockname())
            sock.settimeout(0)
            buf, command, remainder = yield from readtil(sock, target=b'\n')
            command = codecs.decode(command, 'utf-8').strip()
            buf[:remainder.nbytes] = remainder
            if command == 'exit':
                sock.sendall(b'exiting\n')
                return 'exit'
            elif command == 'list':
                server.reminders.sort()
                with sock.makefile('w') as wf:
                    print('Current time: ', datetime.datetime.now(), file=wf)
                    print('Scheduled reminders:', file=wf)
                    for i, (target, message) in enumerate(server.reminders):
                        print(f'{i}: {target.strftime(DATE_SHOW)}: {message}', file=wf)
            elif command == 'cancel':
                buf, fds, _ = yield from readtil(sock, buf, remainder.nbytes)
                out = 0
                cancels = set(map(int, fds.tobytes().split()))
                with sock.makefile('w') as wf:
                    for i, item in enumerate(server.reminders):
                        if i in cancels:
                            print(f'Canceled {item[0].strftime(DATE_SHOW)}: {item[1]}', file=wf)
                        else:
                            server.reminders[out] = item
                            out += 1
                del server.reminders[out:]
                heapq.heapify(server.reminders)
            else:
                try:
                    target = datetime.datetime.strptime(command, DATE_FMT)
                    buf, message, _ = yield from readtil(sock, buf, remainder.nbytes)
                    message = codecs.decode(message, 'utf-8')
                    entry = (target, message)
                    with sock.makefile('w') as wf:
                        if entry in server.reminders:
                            print('Reminder already scheduled.', file=wf)
                            print('  time:', target.strftime(DATE_SHOW), file=wf)
                            print('  mesg:', message, file=wf)
                        else:
                            heapq.heappush(server.reminders, entry)
                            print(datetime.datetime.now().strftime(DATE_SHOW), 'Scheduled reminder:', file=wf)
                            print('  time:', target.strftime(DATE_SHOW), file=wf)
                            print('  mesg:', message, file=wf)
                except Exception:
                    sock.sendall(traceback.format_exc().encode('utf-8'))
        finally:
            server.eprint('closing socket', sock.getsockname())
            sock.close()
        return 'done'

class Listener(object):
    def __init__(self, L, waiting, server):
        self.fileno = L.fileno
        self.iter = self.loop(L, waiting, server)

    @staticmethod
    def loop(L, waiting, server):
        while 1:
            s, a = L.accept()
            waiting.add(Request(s, server))
            yield True



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
        self.tk.update_idletasks() # On windows, without this, every window loses focus.
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
                tl.attributes('-topmost', True)
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
            waiting = set()
            startup = True
            try:
                waiting.add(Listener(L, waiting, self))
                running = True
                while running:
                    for item in select.select(waiting, (), (), wait)[0]:
                        self.eprint('stepping', item)
                        try:
                            next(item.iter)
                        except StopIteration as e:
                            startup = False
                            waiting.discard(item)
                            if e.value == 'exit':
                                running = False
                        except Exception:
                            waiting.discard(item)
                            traceback.print_exc()
                            continue
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
                    elif self.persist or startup:
                        wait = None
                    else:
                        return
            finally:
                waiting.clear()
        except Exception:
            traceback.print_exc()
        finally:
            L.close()
            with self.lock:
                self.running = False
            self.tk.event_generate('<<CheckNotifications>>', when='tail')


def launch_powershell(*args, **kwargs):
    """Launch a powershell process with Start-Process.

    args: sequence of [str | seq of str] (will be flattened.) of the
          command line

    kwargs:
    window: window style for the process, Normal, Hidden, Minimized,
            Maximized or None None means use the current window
            (-NoNewWindow)
    wait: The returned Popen waits until the process is complete.
    subprocess.Popen kwargs
    """
    pat = re.compile(r'(\\*")')
    def dquote(s):
        parts = pat.split(s)
        parts[0] = '"' + parts[0]
        parts[-1] = parts[-1] + '"'
        for i in range(1, len(parts), 2):
            parts[i] = '\\'*((len(parts[i])-1)*2) + '\\"'
        return ''.join(parts)
    cmdargs = []
    for item in args:
        if isinstance(item, str):
            cmdargs.append(dquote(item))
        else:
            cmdargs.extend([dquote(sub) for sub in item])
    print(cmdargs)
    psArgs = " ".join(cmdargs[1:]).replace("'", "''")
    window = kwargs.pop('window', None)
    if window is None:
        winflag = '-NoNewWindow'
    else:
        winflag = f'-WindowStyle {window}'
    wait = '-Wait' if kwargs.pop('wait', False) else ''
    return subprocess.Popen([
        'powershell', '-Command',
        f'Start-Process {cmdargs[0]} {wait} {winflag} -Args \'{psArgs}\''], **kwargs
    )


def launch(args):
    logname = os.path.join(
        os.environ.get('HOME', os.environ.get('USERPROFILE', './')), '.reminder')
    cmd = [
        os.path.realpath(sys.executable),
        os.path.realpath(sys.argv[0]),
        '-s', '--port', str(args.port)]
    for opt in ('persist', 'reuse', 'verbose'):
        if getattr(args, opt):
            cmd.append('--'+opt)
    if platform.system() == 'Windows':
        L = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
        try:
            L.bind(('localhost', 0))
            while L.getsockname()[1] == args.port:
                L.close()
                L = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
                L.bind(('localhost', 0))
            L.listen(1)
            cmd.extend(('--notify', str(L.getsockname()[1])))
            with open(logname, 'ab') as logf:
                print('launching', cmd)
                import shutil
                output = dict(stdout=logf.fileno(), stderr=logf.fileno())
                if shutil.which('cygstart'):
                    p = subprocess.Popen(['cygstart', '--hide'] + cmd, **output)
                else:
                    p = launch_powershell(cmd, window='Hidden', **output)
                    # cmd would probably require some kind of quoting as well...
                    # # start /B would not create a new window, BUT the program
                    # # will be killed if the terminal is closed.
                    # cargs.append('--hide')
                    # cmd = ['cmd', '/C', 'start', '/MIN'] + cmd + cargs
            L.settimeout(5)
            s, a = L.accept()
            s.close()
        finally:
            L.close()
    else:
        with open(logname, 'ab') as logf:
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


COMMANDS = {
    'exit': '',
    'list': '',
    'cancel': '',
    'check': 'list',
    'ls': 'list',
}
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
            if args.cmd in COMMANDS:
                print('No reminder server.')
                return 1
            else:
                try:
                    p = launch(args)
                except Exception:
                    print('Reminder server startup failed:')
                    traceback.print_exc()
                s.connect(('localhost', args.port))
        with s.makefile('w') as wf:
            if args.cmd in COMMANDS:
                args.cmd = COMMANDS[args.cmd] or args.cmd
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
