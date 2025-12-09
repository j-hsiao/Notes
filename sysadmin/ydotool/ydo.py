"""

Notes on sudo:
    It seems like sudo defaults to reading password from the terminal.
    This means there is no special handling required for sudo password.
    Once the process is started, then there's no need for anymore sudo.
"""
import codecs
import getpass
import io
import os
import pty
import select
import shlex
import subprocess as sp
import sys
import textwrap
import threading
import time
import tkinter as tk
import traceback

threading.Thread()

def eprint(*args, **kwargs):
    kwargs.setdefault('file', sys.stderr)
    print(*args, **kwargs)

class Ignore(object):
    def write(self, data):
        return len(data)
    def flush(self):
        pass

class ToStderr(object):
    def __init__(self):
        self.decoder = codecs.getincrementaldecoder('utf-8')()
    def write(self, data):
        eprint(self.decoder.decode(data), end='')
        return len(data)
    def flush(self):
        pass

def oswriteall(fd, text):
    if isinstance(text, str):
        text = text.encode('utf-8')
    view = memoryview(text)
    total = 0
    target = len(text)
    while total < target:
        total += os.write(fd, view[total:])



class OSRead(object):
    """Provide a readinto for an fd."""
    def __init__(self, fd, verbose=False):
        self.fd = fd
        self.verbose = verbose
    def fileno(self):
        return self.fd
    if hasattr(os, 'readv'):
        def readinto(self, buf):
            try:
                return os.readv(self.fd, [buf])
            except Exception:
                if self.verbose:
                    traceback.print_exc()
                return 0
    else:
        def readinto(self, buf):
            try:
                data = os.read(self.fd, len(buf))
            except Exception:
                if self.verbose:
                    traceback.print_exc()
                return 0
            amt = len(data)
            buf[:amt] = data
            return amt

def forward(src, dst):
    """Forward data from src to dst."""
    buf = bytearray(io.DEFAULT_BUFFER_SIZE)
    view = memoryview(buf)
    readinto = getattr(src, 'readinto1', src.readinto)
    amt = readinto(buf)
    while amt:
        total = 0
        while total < amt:
            total += dst.write(view[total:amt])
        amt = readinto(buf)
    dst.flush()

class MousePosition(object):
    """Use tkinter window to track mouse position."""

    HIDE_CMD = 'hide_mouse_position_reader'
    HOLD_CMD = 'hold_mouse_position_reader'
    RELEASE_CMD = 'release_mouse_position_reader'
    def __init__(self, verbose=False):
        self.verbose = verbose
        self.lock = threading.Lock()
        self.updated = 0
        self.held = 0
        self.tk, self.step, self.W, self.H = self.open()

    def open(self):
        """Initialize a tk instance.

        Return the root and the screen shape.
        """
        r = tk.Tk()
        r.geometry('1x1+0+0')
        r.attributes('-topmost', True, '-fullscreen', True)
        r.withdraw()
        r.createcommand(self.HIDE_CMD, self.hide)
        r.createcommand(self.HOLD_CMD, self.holdmouse)
        r.createcommand(self.RELEASE_CMD, self.releasemouse)
        r.bind('<Motion>', self.HIDE_CMD)
        r.bind('<Button-1>', self.HOLD_CMD)
        r.bind('<ButtonRelease-1>', self.RELEASE_CMD)
        return r, tk.IntVar(r, 0), r.winfo_screenwidth(), r.winfo_screenheight()

    def holdmouse(self):
        """Track current mouse state."""
        with self.lock:
            self.held = 1
        if self.verbose:
            eprint('hold')
    def releasemouse(self):
        """Track current mouse state."""
        with self.lock:
            self.held = 0
        if self.verbose:
            eprint('release')

    def close(self):
        if getattr(self, 'tk', None) is not None:
            self.tk.destroy()
            self.tk = None

    def __enter__(self):
        if self.tk is None:
            self.tk, self.step, self.W, self.H = self.open()
        return self
    def __exit__(self, tp, exc, tb):
        self.close()
    def __del__(self):
        self.close()

    def hide(self):
        with self.lock:
            self.updated = True
        if self.verbose:
            eprint('updated mouse position.')
        self.step.set(1)
        # Seems like tk.attributes turn on/off fullscreen
        # is necessary or sometimes mouse event does not fire
        # after deiconify.
        self.tk.attributes('-fullscreen', False)
        self.tk.withdraw()

    def pos(self):
        """Get currently stored mouse position."""
        with self.lock:
            self.updated = False
            return self.tk.winfo_pointerxy()

    def readmouse(self, force=True):
        """Read the current mouse position (if not already updated).

        This temporarily sets the tk window to fullscren to ensure that
        the mouse is within the window allowing reading its position.

        force: force updating mouse position (ignored if mouse is currently held.)
        """
        with self.lock:
            if self.held or (not force and self.updated):
                self.updated = False
                return self.tk.winfo_pointerxy()
        self.tk.deiconify()
        self.tk.attributes('-topmost', True, '-fullscreen', True)
        self.tk.wait_variable(self.step)
        return self.pos()

    def __del__(self):
        self.close()

class NoMouseAccel(object):
    """Context manager to disable mouse acceleration."""

    # TODO: how to turn off for other desktop environments?
    # TODO: How to detect which desktop environment?
    GET = ['gsettings', 'get', 'org.gnome.desktop.peripherals.mouse', 'accel-profile']
    SET = ['gsettings', 'set', 'org.gnome.desktop.peripherals.mouse', 'accel-profile']
    FLAT = "'flat'"
    def __init__(self):
        self.accel = []

    def push(self):
        self.accel.append(sp.check_output(self.GET).decode('utf-8'))
        if self.accel[-1] != self.FLAT:
            sp.check_output(self.SET + [self.FLAT])
        return self
    def pop(self):
        try:
            orig = self.accel.pop()
            if orig != self.FLAT:
                sp.check_output(self.SET + [orig])
        except IndexError:
            pass
        return self
    def close(self):
        while self.accel:
            self.pop()
    def __enter__(self):
        self.push()
        return self
    def __exit__(self, tp, exc, tb):
        self.pop()
    def __del__(self):
        self.close()

def readtil(f, target, bufsize=io.DEFAULT_BUFFER_SIZE, out=None):
    """Read file until target is found.

    f: the file to read from.
    target: The target bytes to search for.
    bufsize: The buffersize to use.
    out: output if buffer is filled but target not found.

    Return (index, buf, total)
        index: the index where target is found.
        buf: the buffer.
        total: the total number of bytes read.
    """
    buf = bytearray(max(bufsize, len(target)))
    view = memoryview(buf)
    total = 0
    readinto = getattr(f, 'readinto1', f.readinto)
    amt = readinto(view)
    minwin = len(target) - 1
    while amt:
        searchstart = max(0, total - minwin)
        total += amt
        idx = buf.find(target, searchstart, total)
        if idx >= 0:
            return idx, buf, total
        elif total == len(buf):
            if out is not None:
                out.write(view[:-minwin])
            view[:minwin] = view[-minwin:]
            total = minwin
        amt = readinto(view[total:])
    return -1, buf, total


class ydotoold(object):
    """Context manager for the ydotoold daemon."""

    SCRIPT = textwrap.dedent('''
        trap '' SIGINT
        stdbuf -oL ydotoold -p {0} &
        pid=$!
        trap "kill $pid; rm "{1} EXIT
        wait $pid
        trap '' EXIT
        rm {0}
        ''')

    def __init__(self, sock=None, verbose=False):
        """Initialize ydotoold.

        sock: The socket path for ydotoold.
        """
        if sock is None:
            sock = f'/dev/shm/{os.environ["USER"]}_ydo.sock'
        self.verbose = verbose
        self.path = sock
        self.proc = None
        self.thread = None
        self.open()

    def __str__(self):
        """Return the ydotoold socket path."""
        return self.path

    def open(self):
        """Open ydotoold process if needed."""
        if self.proc is not None:
            return
        command = []
        if os.environ['USER'] != 'root':
            command.append('sudo')
        command.extend(('bash', '-c'))
        qpath = shlex.quote(self.path)
        command.append(self.SCRIPT.format(qpath, shlex.quote(qpath)))
        # TODO check if bufsize=0 is necessary
        # updating readtil to use readinto1 is good enough...
        proc = sp.Popen(command, stdout=sp.PIPE, bufsize=0)
        if self.verbose:
            out = ToStderr()
        else:
            out = Ignore()
        idx, buf, total = readtil(proc.stdout, b'READY', out=out)
        if idx < 0:
            raise RuntimeError('ydotoold exited without READY.')
        out.write(memoryview(buf)[:total])
        self.thread = threading.Thread(target=forward, args=[proc.stdout, out])
        self.thread.start()
        self.proc = proc
        return

    def __enter__(self):
        self.open()
        return self
    def __exit__(self, tp, exc, tb):
        self.close()
    def __del__(self):
        self.close()

    def close(self):
        if self.proc is not None:
            try:
                self.proc.terminate()
                self.thread.join()
            except Exception:
                eprint('ydotoold bash proc was ', self.proc.pid)
                traceback.print_exc()
            self.proc = None

class Bash(object):
    def __init__(self, sudo=False, stdout=sp.DEVNULL, stderr=sp.DEVNULL, **kwargs):
        """Initialize bash process."""
        self.proc = None
        self.bashin = None
        self.stderr = None
        self.stdout = None
        self.open(sudo, stdout, stderr, **kwargs)

    def open(self, sudo=False, stdout=sp.DEVNULL, stderr=sp.DEVNULL, **kwargs):
        if self.proc is not None:
            return
        if sudo:
            command = ['sudo', 'bash']
        else:
            command = ['bash']
        self.proc = sp.Popen(
            command, stdin=sp.PIPE, stdout=stdout, stderr=stderr, **kwargs)
        if kwargs.get('text', False):
            self.bashin = self.proc.stdin
        else:
            self.bashin = io.TextIOWrapper(self.proc.stdin)
        self.stdout = self.proc.stdout
        self.stderr = self.proc.stderr
        self('trap "" SIGINT')

    def close(self):
        if self.proc is None:
            return
        # proc.wait uses os.waitpid, but it seems like if
        # __del__ is called due to interpreter exit, then
        # os.waitpid might have been set to None causing
        # an error.
        try:
            self('exit')
            time.sleep(0.1)
            for i in range(3):
                if self.proc.poll() is not None:
                    break
                time.sleep(1)
            else:
                self.proc.terminate()
        except IOError:
            traceback.print_exc()
        try:
            self.proc.wait()
        except Exception:
            traceback.print_exc()
        try:
            self.bashin.close()
        except Exception:
            traceback.print_exc()
        self.proc = None

    def __enter__(self):
        self.open()
        return self
    def __exit__(self, tp, exc, tb):
        self.close()
    def __del__(self):
        self.close()

    def __bool__(self):
        return self.proc is not None and self.proc.poll() is None

    def __call__(self, *args, **kwargs):
        """Write to bash process.

        Same as print(), except flush defaults to True
        and file defaults to the bash stdin.
        """
        kwargs.setdefault('flush', True)
        kwargs.setdefault('file', self.bashin)
        try:
            print(*args, **kwargs)
        except Exception:
            traceback.print_exc()


class ydotool(object):
    """Ydotool commands through a bash process."""
    def __init__(self, sockpath=None, stderr=sp.DEVNULL, noaccel=False, verbose=False):
        self.verbose = verbose
        self.bash = None
        self.pos = None
        if noaccel:
            self.noaccel = NoMouseAccel()
        else:
            self.noaccel = None
        if sockpath is None:
            sockpath = f'/dev/shm/{os.environ["USER"]}_ydo.sock'
        self.sockpath = sockpath
        self.open(stderr)

    def open(self, stderr=None):
        if self.bash is not None:
            return
        self.bash = Bash(os.environ['USER'] != 'root', stdout=sp.PIPE, stderr=stderr)
        if self.noaccel is not None:
            self.noaccel.push()
        self.pos = MousePosition()
        self.bash('export YDOTOOL_SOCKET={}'.format(shlex.quote(self.sockpath)))
        self.bash(textwrap.dedent('''
            multimove() {
                while (($#))
                do
                    ydotool move -x ${1} -y ${2}
                    shift 2
                done >&2
            }'''))

    def sync(self):
        """Synchronize bash commands (echo and wait for output).

        This means that for most commands, stdout should be redirected away
        so synchronization does not possibly read some other command's output.
        """
        self.bash('echo')
        self.bash.stdout.readline()

    def close(self):
        if self.bash is None:
            return
        if self.noaccel is not None:
            self.noaccel.close()
        self.pos.close()
        self.bash.close()
        self.bash = None


    def type(self, text, nextdelay=0, keydelay=12, flush=True):
        self.bash('ydotool type', shlex.quote(text), '>&2', flush=flush)

    LEFT = 0x00
    RIGHT = 0x01
    MIDDLE = 0x02
    SIDE = 0x03
    EXTR = 0x04
    FORWARD = 0x05
    BACK = 0x06
    TASK = 0x07

    DOWN = 0x40
    UP = 0x80
    def click(self, code=UP|DOWN|LEFT, repeat=1, delay=25, flush=True):
        self.bash(
            'ydotool click 0x{:02x}'.format(code),
            '--repeat', repeat,
            '--next-delay', delay,
            '>&2', flush=flush)

    # TODO maybe read/parse the mapping? ...
    # sudo libinput read -o out.yaml, sleep(1), terminate(),
    # then parse for key: name, form a dict, ...
    # is outputting to stdout possible? otherwise use process substitution?
    rawkeys = {
        'ESC': 1, '1': 2, '2': 3, '3': 4, '4': 5, '5': 6, '6': 7, '7': 8, '8': 9, '9': 10, '0': 11,
        'MINUS': 12, 'EQUAL': 13, 'BACKSPACE': 14, 'TAB': 15,
        'Q': 16, 'W': 17, 'E': 18, 'R': 19, 'T': 20, 'Y': 21, 'U': 22, 'I': 23, 'O': 24, 'P': 25,
        'LEFTBRACE': 26, 'RIGHTBRACE': 27, 'ENTER': 28, 'LEFTCTRL': 29,
        'A': 30, 'S': 31, 'D': 32, 'F': 33, 'G': 34, 'H': 35, 'J': 36, 'K': 37, 'L': 38,
        'SEMICOLON': 39, 'APOSTROPHE': 40, 'GRAVE': 41, 'LEFTSHIFT': 42, 'BACKSLASH': 43,
        'Z': 44, 'X': 45, 'C': 46, 'V': 47, 'B': 48, 'N': 49, 'M': 50,
        'COMMA': 51, 'DOT': 52, 'SLASH': 53, 'RIGHTSHIFT': 54, 'KPASTERISK': 55, 'LEFTALT': 56, 'SPACE': 57, 'CAPSLOCK': 58,
        'F1': 59, 'F2': 60, 'F3': 61, 'F4': 62, 'F5': 63, 'F6': 64, 'F7': 65, 'F8': 66, 'F9': 67, 'F10': 68,
        'NUMLOCK': 69, 'SCROLLLOCK': 70, 'KP7': 71, 'KP8': 72, 'KP9': 73,
        'KPMINUS': 74, 'KP4': 75, 'KP5': 76, 'KP6': 77, 'KPPLUS': 78,
        'KP1': 79, 'KP2': 80, 'KP3': 81, 'KP0': 82, 'KPDOT': 83,
        'ZENKAKUHANKAKU': 85, '102ND': 86, 'F11': 87, 'F12': 88, 'RO': 89,
        'KATAKANA': 90, 'HIRAGANA': 91, 'HENKAN': 92, 'KATAKANAHIRAGANA': 93, 'MUHENKAN': 94,
        'KPJPCOMMA': 95, 'KPENTER': 96, 'RIGHTCTRL': 97, 'KPSLASH': 98, 'SYSRQ': 99, 'RIGHTALT': 100,
        'HOME': 102, 'UP': 103, 'PAGEUP': 104, 'LEFT': 105, 'RIGHT': 106, 'END': 107, 'DOWN': 108,
        'PAGEDOWN': 109, 'INSERT': 110, 'DELETE': 111,
        'MUTE': 113, 'VOLUMEDOWN': 114, 'VOLUMEUP': 115, 'POWER': 116, 'KPEQUAL': 117, 'PAUSE': 119,
        'KPCOMMA': 121, 'HANGEUL': 122, 'HANJA': 123, 'YEN': 124, 'LEFTMETA': 125, 'RIGHTMETA': 126,
        'COMPOSE': 127, 'STOP': 128, 'AGAIN': 129, 'PROPS': 130, 'UNDO': 131,
        'FRONT': 132, 'COPY': 133, 'OPEN': 134, 'PASTE': 135, 'FIND': 136, 'CUT': 137,
        'HELP': 138, 'CALC': 140, 'SLEEP': 142, 'WWW': 150, 'COFFEE': 152, 'BACK': 158, 'FORWARD': 159,
        'EJECTCD': 161, 'NEXTSONG': 163, 'PLAYPAUSE': 164, 'PREVIOUSSONG': 165, 'STOPCD': 166, 'REFRESH': 173,
        'EDIT': 176, 'SCROLLUP': 177, 'SCROLLDOWN': 178, 'KPLEFTPAREN': 179, 'KPRIGHTPAREN': 180,
        'F13': 183, 'F14': 184, 'F15': 185, 'F16': 186, 'F17': 187, 'F18': 188, 'F19': 189, 'F20': 190, 'F21': 191, 'F22': 192, 'F23': 193, 'F24': 194,
        'UNKNOWN': 240,
    }
    def keys(*specs):
        """Press keys in order.

        specs: str: the key to press (down then up)
               tuple: (key, state) where state = 1 (down), or 0 (up).
        """
        seq = []
        for spec in specs:
            if isinstance(spec, str):
                seq.append(spec + ':1')
                seq.append(spec + ':0')
            else:
                seq.append(':'.join((spec[0], int(bool(spec[1])))))
        # TODO

    def travel(self, coordinates, absolute=True, sleep=(lambda e:None)):
        """Move mouse approximately along the given coordinates.

        Coordinates: sequence of (x, y, delay)
            x,y: mouse screen coordinates.
            delay: time delay (ms).
        Due to mouse acceleration, the mouse might overshoot etc.
        After every move, iterate through coordinates until the
        first point that increases distance from the new cursor
        position.
        """
        x, y = self.pos.readmouse()
        if not absolute:
            ncoordinates = []
            lx, ly = x, y
            for (dx, dy, delay) in coordinates:
                lx += dx
                ly += dy
                ncoordinates.append((lx, ly, delay))
        ptidx = 0
        nx, ny, _ = coordinates[ptidx]
        while ptidx < len(coordinates):
            dx = nx-x
            dy = ny-y
            self.bash('ydotool mousemove -x {} -y {} >&2'.format(dx, dy))
            self.bash.stdout.readline()
            nx, ny = self.pos.readmouse()
            ax = nx-x
            ay = ny-y
            x,y = nx,ny
            lastdst = abs(ax) + abs(ay)
            delay = 0
            for ptidx in range(ptidx+1, len(coordinates)):
                nx, ny, dly = coordinates[ptidx]
                delay += dly
                dst = abs(nx-x) + abs(ny-y)
                if dst < lastdst:
                    lastdst = dst
                else:
                    break
            sleep(delay)
        self.move(nx, ny, True)

    def calibrate(self, start=10, stop=100, step=10, samples=3):
        """Calibrate mouse motion to actual motion."""
        def reset(dim):
            delta = [0, 0]
            delta[dim] = -1
            alt = 1 - dim
            mid = (self.pos.W//2, self.pos.H//2)
            pos = self.pos.readmouse()
            while pos[dim] != 0:
                if pos[alt] < mid[alt]:
                    delta[alt] = 1
                elif pos[alt] == mid[alt]:
                    delta[alt] = 0
                else:
                    delta[alt] = -1
                self.bash(
                    'for ((x=0; x < 50; ++x)); '
                    'do ydotool mousemove -x', delta[0], '-y', delta[1],
                    '; done >&2', flush=False)
                self.sync()
                pos = self.pos.readmouse()

        results = []
        for dim in range(2):
            data = {}
            delta = [0, 0]
            delta[dim] = 1
            for npix in range(start, stop, step):
                for sample in range(samples):
                    reset(dim)
                    cpos = self.pos.readmouse()
                    self.bash(
                        'for ((x=0; x <', npix, '; ++x));'
                        ' do ydotool mousemove -x', delta[0], '-y', delta[1],
                        '; done >&2', flush=False)
                    self.sync()
                    npos = self.pos.readmouse()
                    npos[dim] - cpos[dim]
                    data.setdefault(npix, []).append(npos[dim] - cpos[dim])
                    cpos = npos
            results.append(data)

        for dim, data in enumerate(results):
            eprint('dim:', dim)
            for k, v in data.items():
                eprint(' ', k, ':', v)
        return results

    def deltas(self, x, y):
        """Return sequence of deltas for a net move of x, y."""
        nstep = max(abs(x), abs(y))
        ret = []
        px = py = 0
        for i in range(1, nstep+1):
            nx = (x*i // nstep)
            ny = (y*i // nstep)
            ret.append((nx-px, ny-py))
            px = nx
            py = ny
        return ret

    def cmove(self, x, y, calibration, absolute=False):
        """Calibrated motion. Move x, y according to calibration.

        x, y: The desired movement.
        calibration: result of calibrate()
        absolute: x, y are absolute target coordinates.
        """
        if absolute:
            cx, cy = self.pos.readmouse()
            x -= cx
            y -= cy
        # TODO



    def move(self, x, y, absolute=False, check=5):
        """Move mouse to x, y.

        x, y: move the mouse by x,y.
        absolute: Move to (x,y) as measure from the top-left corner.
                  Note that ydotool does not have a "real" absolute
                  movement.  All it does is move a large offset to the
                  topleft to reset the mouse to (0,0) before moving
                  the given (x,y).  This can cause problems, such as if
                  gnome hot corner is turned on.
                  If given as ((rt)(lb)), then use that corner
                  as the target corner to move to for resetting the mouse
                  position.
        check: Check progress every 5 iterations. If the mouse position
               is not closer to the target, then stop.  This allows
               accurate movement even with mouse acceleration.
               For now, this is implemented by flashing a full screen
               topmost tkinter window (see `MousePosition`) so the window
               will flash on the screen with each measurement.
        """
        if check:
            cx, cy = self.pos.readmouse()
            if not absolute:
                x += cx
                y += cy
            x = min(max(x, 0), self.pos.W-1)
            y = min(max(y, 0), self.pos.H-1)
            dx = x-cx
            dy = y-cy
            odst = abs(dx) + abs(dy)
            it = 0
            while 1:
                self.bash('ydotool mousemove -x {} -y {} >&2'.format(dx, dy), flush=False)
                self.sync()
                nx, ny = self.pos.readmouse()
                if (nx, ny) == (x,y):
                    if self.verbose:
                        eprint('arrived to target.')
                    return
                if nx == cx:
                    if nx == x:
                        dx = 0
                    else:
                        dx = x - nx
                else:
                    dx = int(((x-nx)*dx) / (nx-cx))
                if ny == cy:
                    if ny == y:
                        dy = 0
                    else:
                        dy = y-ny
                else:
                    dy = int(((y-ny)*dy) / (ny-cy))
                if self.verbose:
                    eprint('  previous:', cx, cy, 'current:', nx, ny, 'target', x, y, 'adjusted:', dx, dy)
                cx = nx
                cy = ny
                it += 1
                if it >= check:
                    ndst = abs(x-cx) + abs(y-cy)
                    if ndst >= odst:
                        return
                    odst = ndst
                    it = 0
        else:
            if self.noaccel is None:
                eprint('WARNING: unchecked movement without noaccel.')
            if absolute:
                W, H = self.pos.W, self.pos.H
                W = (-W, W)['r' in absolute]
                H = (-H, H)['b' in absolute]
                self.bash((
                    'ydotool mousemove -x 0 -y {} >&2\n'
                    'ydotool mousemove -x {} -y 0 >&2\n'
                    'ydotool mousemove -x {} -y {} >&2'
                    ).format(H, W, x-max(0, W-1), y-max(0, H-1)))
            else:
                self.bash('ydotool mousemove -x {} -y {} >&2'.format(x, y))

    def __enter__(self):
        self.open()
        return self
    def __exit__(self, tp, exc, tb):
        self.close()
    def __del__(self):
        self.close()

if __name__ == '__main__':
    with MousePosition(True) as m:
        t = tk.Toplevel(m.tk)
        t.title('top')
        t.bindtags((str(m.tk),) + t.bindtags())
        t.bind('<space>', lambda e: print(m.readmouse(False)))
        t.bind('<Return>', lambda e: print(m.readmouse(True)))
        t.bind('<Escape>', 'destroy '+str(t))
        t.wait_window()
