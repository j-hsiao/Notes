import argparse
import codecs
import collections
import datetime
import heapq
import itertools
import io
import os
import platform
import re
import select
import socket
import subprocess
import sys
import textwrap
import threading
import time
import tkinter as tk
from tkinter import messagebox
import traceback


DATE_FMT = '%Y-%m-%d %H:%M:%S.%f'
DATE_SHOW = '%Y-%m-%d %H:%M:%S'
def growbuf(buf):
    nbuf = bytearray(int(len(buf)*1.5))
    view = memoryview(nbuf)
    view[:len(buf)] = buf
    return view, nbuf

def showinfo(close='<Control-Shift-Alt-space>', **kwargs):
    """Show info and close with `close` keyseq

    kwargs:
        toplevel
        parent
        title
        message
        width
        height
        font
    """
    tl = kwargs.get('toplevel', None)
    if tl is None:
        r = kwargs.get('parent', None)
        destroy = False
        if r is None:
            try:
                r = tk._default_root
            except AttributeError:
                r = None
            if r is None:
                r = tk.Tk()
                showinfo(close=close, toplevel=r, **kwargs)
                return
        tl = tk.Toplevel(r)
    tl.attributes('-topmost', True)
    if kwargs.get('title') is not None:
        tl.title(kwargs['title'])
    tl.tk.eval('''
        if {"[info procs ::remind::showinfo::keep_window_at_center]" == ""} {
            namespace eval remind::showinfo {
                proc keep_window_at_center {win} {
                    variable targetx [expr ([winfo screenwidth $win]-[winfo width $win])/2]
                    variable targety [expr ([winfo screenheight $win]-[winfo height $win])/2]
                    if {[winfo x $win] != $targetx || [winfo y $win] != $targety} {
                        wm geometry $win +$targetx+$targety
                    }
                }
            }
        }''')
    txt = tk.Text(
        tl, font=kwargs.get('font', 'TkDefaultFont'),
        width=kwargs.get('width', 40), height=kwargs.get('height', 10),
    )
    txt.insert('end', kwargs.get('message', ''))
    txt.grid(row=0, column=0, sticky='nsew')
    txt.configure(state='disabled')

    scroll = tk.Scrollbar(tl, orient='vertical', command=txt.yview)
    scroll.grid(row=0, column=1, sticky='nsew')
    txt.configure(yscrollcommand=scroll.set)

    tl.bind('<Configure>', f'remind::showinfo::keep_window_at_center {tl}')
    tl.bind(close, f'grab release {tl}\ndestroy {tl}')
    tl.tk.call('wm', 'resizable', tl, 0, 0)
    tl.focus()
    tl.grab_set()
    tl.wait_window()

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
        self.args = args
        self.persist = args.persist
        self.verbose = args.verbose
        self.notify = args.notify
        self.reuse = args.reuse
        self.port = args.port
        self.lock = threading.Lock()
        self.reminders = []
        self.ready = collections.deque()
        self.running = True
        self.destroyed = False

        self.tk = tk.Tk()
        self.widgets = [
            tk.Text(
                self.tk, font=args.font,
                width=args.shape[0], height=args.shape[1],
            ),
            tk.Scrollbar(self.tk, orient='vertical')
        ]
        self.widgets[0].configure(
            yscrollcommand=self.widgets[1].set,
            selectforeground=self.widgets[0].cget('foreground'),
            selectbackground=self.widgets[0].cget('background'),
            )
        self.widgets[1].configure(command=self.widgets[0].yview)
        self.widgets[0].grid(row=0, column=0, sticky='nsew')
        self.widgets[1].grid(row=0, column=1, sticky='nsew')
        self.tk.grid_columnconfigure(0, weight=1)
        self.tk.grid_rowconfigure(0, weight=1)
        self.tk.eval('namespace eval remind { variable finish }')
        self.tk.bind(args.sequence, 'set remind::showinfo::done 1')
        self.tk.call('wm', 'resizable', self.tk, 0, 0)
        self.tk.eval('''
            namespace eval remind::showinfo {
                variable done 1
                proc keep_window_at_center {win} {
                    variable targetx [expr ([winfo screenwidth $win]-[winfo width $win])/2]
                    variable targety [expr ([winfo screenheight $win]-[winfo height $win])/2]
                    if {[winfo x $win] != $targetx || [winfo y $win] != $targety} {
                        wm geometry $win +$targetx+$targety
                    }
                }
            }''')
        self.tk.bind('<Configure>', f'remind::showinfo::keep_window_at_center {self.tk}')
        self.tk.createcommand('remind::showinfo::endit', self.stop)
        self.tk.bind('<Destroy>', 'remind::showinfo::endit %W')


        self.tk.update_idletasks() # On windows, without this, every window loses focus.
        self.tk.withdraw()
        self.tk.attributes('-topmost', True)
        self.tk.createcommand('CheckNotifications', self._check_notifications)
        self.notifying = tk.BooleanVar(self.tk, False)
        self.tk.bind('<<CheckNotifications>>', f'if {{!${self.notifying}}} {{CheckNotifications}}')

    def stop(self, name):
        if name != str(self.tk):
            return
        self.tk.call('set', 'remind::showinfo::done', 1)
        with self.lock:
            self.destroyed = True
            if not self.running:
                return
            self.running = False
        s = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
        try:
            s.connect(('localhost', self.port))
            with s.makefile('w') as wf:
                print('exit', file=wf)
                wf.flush()
            s.shutdown(socket.SHUT_WR)
            while s.recv(4096):
                pass
        finally:
            s.close()

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

    def showmessage(self, **kwargs):
        """Show text in a popup

        kwargs:
            title
            message
            width
            height
        """
        self.tk.focus()
        self.tk.grab_set()
        try:
            self.tk.title(kwargs.get('title', 'reminder'))
            self.widgets[0].configure(state='normal')
            self.widgets[0].delete('1.0', 'end')
            self.widgets[0].insert('end', kwargs.get('message', ''))
            self.widgets[0].configure(state='disabled')
            self.tk.call('vwait', 'remind::showinfo::done')
        finally:
            if not self.destroyed:
                self.tk.grab_release()

    def _check_notifications(self):
        """Display popups sequentially."""
        self.notifying.set(True)
        try:
            self.tk.deiconify()
            while 1:
                with self.lock:
                    if not self.running:
                        break
                    if self.ready:
                        target, message = self.ready.popleft()
                    else:
                        break
                now = datetime.datetime.now()
                parts = []
                dtstr = target.strftime(DATE_SHOW)
                if abs((now - target).total_seconds()) < 1:
                    formatted = ''.join([dtstr, '\n', '='*len(dtstr), '\n', message])
                else:
                    formatted = ''.join(['now: ', now.strftime(DATE_SHOW), ':\ntgt: ', dtstr, '\n', '='*len(dtstr+5), '\n', message])
                self.showmessage(parent=self.tk, title='Reminder', message=formatted)
            with self.lock:
                if self.running:
                    return
            if self.reminders or self.ready:
                with io.StringIO() as messagebuf:
                    self.reminders.sort()
                    now = datetime.datetime.now()
                    orig = sys.stdout
                    sys.stdout = messagebuf
                    try:
                        for target, message in itertools.chain(self.ready, self.reminders):
                            if now is not None and target > now:
                                fmt = '{{:^{}}}'.format(self.args.shape[0])
                                print('_'*self.args.shape[0])
                                print(fmt.format('Unprocessed reminders'))
                                print()
                                now = None
                            dtstr = target.strftime(DATE_SHOW)
                            print(f'{dtstr}\n{"="*len(dtstr)}\n{message}\n')
                    finally:
                        sys.stdout = orig
                    if self.destroyed:
                        showinfo(
                            close=self.args.sequence,
                            title='Reminder',
                            message=messagebuf.getvalue(),
                            toplevel=tk.Tk(),
                            font=self.args.font,
                        )
                        return
                    else:
                        self.showmessage(title='Reminder', message=messagebuf.getvalue())
            self.tk.call('after', 'idle', f'destroy {self.tk}')
        finally:
            if not self.destroyed:
                self.tk.withdraw()
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
                finalize = self.running
                self.running = False
            if finalize:
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
    if args.log is None:
        logname = os.devnull
    elif args.log:
        logname = args.log
    else:
        logname = os.path.join(
            os.environ.get('HOME', os.environ.get('USERPROFILE', './')), '.reminder')
    cmd = [
        os.path.realpath(sys.executable),
        os.path.realpath(sys.argv[0]),
        '-s', '--port', str(args.port)]
    for opt in ('persist', 'reuse', 'verbose'):
        if getattr(args, opt):
            cmd.append('--'+opt)
    for opt in ('sequence', 'font'):
        cmd.extend(('--'+opt, getattr(args, opt)))
    cmd.append('--shape')
    cmd.extend(map(str, args.shape))
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
            if platform.system() == 'Windows':
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
            else:
                cmd.insert(0, 'nohup')
                print('launching', cmd)
                p = subprocess.Popen(
                    cmd, bufsize=0, stdout=logf.fileno(),
                    stderr=logf.fileno())
        L.settimeout(5)
        s, a = L.accept()
        s.close()
    finally:
        L.close()
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
                    print(
                        'Reminder server startup failed:\n   ',
                        traceback.format_exc().replace('\n', '\n    '),
                        file=sys.stderr)
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

def win_check_excludedportrange(value):
    """Ensure value is not in windows excluded port range.

    Parse netsh interface ipv4 show excludedportrange protocol=tcp.
    """
    portrangepat = re.compile(r'\s*(\d+)\s*(\d+)')
    result = subprocess.check_output(
        ['netsh', 'int', 'ipv4', 'show', 'excludedportrange', 'protocol=tcp'])
    ranges = []
    for line in result.decode().splitlines():
        result = portrangepat.match(line)
        if result:
            ranges.append((int(result.group(1)), int(result.group(2))))
    ranges.sort()
    hval = value
    lval = value
    for start, stop in ranges:
        if start <= hval <= stop:
            hval = stop+1
    for start, stop in reversed(ranges):
        if start <= lval <= stop:
            lval = start-1
    return lval if value-lval < hval-value else hval

if __name__ == '__main__':
    p = argparse.ArgumentParser()
    p.add_argument('-s', '--server', action='store_true', help='act as the server, otherwise client.')
    p.add_argument('-P', '--persist', action='store_true', help='Server remains up even if no more notifications.')
    p.add_argument('-r', '--reuse', action='store_true')
    p.add_argument('-v', '--verbose', action='store_true')
    p.add_argument('--hide', action='store_true', help='hide terminal on windows.')
    p.add_argument('--notify', type=int, help='Connect to this port to notify server ready.')
    p.add_argument('-l', '--log', help='use logfile')
    p.add_argument('--shape', type=int, help='Width Height', nargs=2, default=(40,10))
    p.add_argument('--sequence', default='<Control-Shift-Alt-space>', help='bind sequence to close reminder popup.')
    p.add_argument('-f', '--font', default='TkDefaultFont')

    p.add_argument(
        'cmd', nargs='?',
        help=f'the client command: a time specification (YYYY-mm-dd HH:MM:SS), floats allowed, omissions allowed. or one of {[f"{k}->{v}" if v else k for k, v in COMMANDS.items()]}.')
    p.add_argument('extra', nargs='*', help='remaining extra arguments for command.')
    p.add_argument('-c', '--check', action='store_true', help='just check the time parsing.')
    p.add_argument('-p', '--port', type=int, default=65432, help='reminder server port.')
    p.add_argument('-d', '--delay', action='store_true', help='the given times are delays.')
    args = p.parse_args()

    if platform.system() == 'Windows':
        args.port = win_check_excludedportrange(args.port)

    if args.check:
        print('now:', datetime.datetime.now().strftime(DATE_FMT))
        print('tgt:', parse_time(args.cmd, args.delay).strftime(DATE_FMT))
    elif args.server:
        Server(args).run()
    else:
        sys.exit(send_command(args))
