"""

Notes on sudo:
    It seems like sudo defaults to reading password from the terminal.
    This means there is no special handling required for sudo password.
    Once the process is started, then there's no need for anymore sudo.
"""
from collections import defaultdict
import codecs
import getpass
import io
import os
import pty
import select
import shlex
import itertools
import subprocess as sp
import sys
import textwrap
import threading
import time
import tkinter as tk
import traceback
import uuid

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


def detect_deiconify_motion_type(r):
    """Detect whether a <Motion> will be visible or not after deiconify.

    From observation:
        1. X generally results in multiple <Configure> events.
        2. Windows only has 1 <Configure> event.
        3. WSL usually has 6 configure events for a new Toplevel with this sequence.
        4. Using vncserver/vncviewer NO <Motion> event fires, BUT still multiple
           <Configure>, but less than WSL
    , a <Motion> will be fired if multiple configures
    happen between deiconify and enter.
    """
    t = tk.Toplevel(r)
    # There generally seems to be a potential for double <Motion>
    # if mouse happens to be inside of t when it first deiconifies.
    # so make it tiny and out of the way corner/edge is much more likely
    # than some other position prbly...
    # It seems geometry +0+0 vs +5+5 results in an extra <Configure>
    # for X (so (vnc)3->4 and (wsl)5->6)
    # need testing on arch/wayland
    t.geometry('1x1+5+5')
    t.withdraw()
    vname = 'v'+uuid.uuid4().hex
    r.call('set', vname, '0')
    t.bind('<Enter>', f'puts "enterred... %x %y %X %Y"\nif {{${vname} == 4 || ${vname} == 1}} {{destroy {t}}}')
    t.bind('<Configure>', f'set {vname} [expr ${vname} + 1]')
    t.bind('<Motion>', f'puts "motioned %x %y %X %Y"\ndestroy {t}')
    t.attributes('-topmost', True, '-fullscreen', True)
    t.deiconify()
    t.wait_window()
    config_count = r.eval(f'expr ${vname}')
    r.call('unset', vname)
    return int(config_count) > 4, config_count


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
        r.geometry(f'{r.winfo_screenwidth()}x{r.winfo_screenheight()}+0+0')
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
        return self


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
        self.bash(
            'export YDOTOOL_SOCKET={}'.format(
                shlex.quote(self.sockpath)))
        if self.bash(textwrap.dedent('''
            smove()
            {
                local x="${1}" y="${2}"
                if ((x == 0 && y == 0)); then return; fi
                if ((${x#*-} > ${y#*-}))
                then
                    local main=x sub=y
                else
                    local main=y sub=x
                fi
                local i=0 dx dy end=${!main#*-} step='++i'
                ((d${main} = ${!main//[^-]}1))
                if ((${!sub}))
                then
                    ((end *= ${!sub#*-}))
                    step=''
                    eval d${sub}='"${!sub//[^-]}(-(i / ${!main#*-}) + (i+=${!sub#*-})/${!main#*-})"'
                else
                    ((d${sub} = 0))
                fi
                for ((; i<end; step))
                do
                    ydotool mousemove -x $((dx)) -y $((dy))
                done
            }
            multimove() {
                while ((${#}))
                do
                    ydotool mousemove -x ${1} -y ${2}
                    shift 2
                done >&2
            }
            echo ready
            ''')).stdout.readline().strip() != b'ready':
            self.close()
            raise RuntimeError('Failed to start ydotool.')

    def sync(self):
        """Synchronize bash commands (echo and wait for output).

        This means that for most commands, stdout should be redirected away
        so synchronization does not possibly read some other command's output.
        """
        self.bash('echo').stdout.readline()

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

    def calibrate_motion(self, motion, samples=3, margin=10):
        """Convert a screen motion arc into a mousemotion arc.

        motion: [(x, y, delay)...]
        samples: number of consecutive successes to determine motion.
        reset: float (sec), number of seconds required to reset mouse.
        """
        def adjust_bounds(lo, hi, result, target):
            """Adjust the bounds of best mouse delta."""
            result = abs(result)
            target = abs(target)
            if result == target:
                return lo, hi
            else:
                mid = lo + (hi-lo)//2
                if result > target:
                    if lo == mid:
                        return max(lo-1, 1), mid
                    else:
                        return lo, mid
                else:
                    if lo == mid:
                        return mid, hi+1
                    else:
                        return mid, hi
        def prep_range(dx, dy):
            """Prepare the potential range of mouse delta"""
            sx = -1 if dx < 0 else (1 if dx > 0 else 0)
            sy = -1 if dy < 0 else (1 if dy > 0 else 0)
            return sx, sy, (1 if dx else 0), abs(dx*2), (1 if dy else 0), abs(dy*2)

        def pick_best(tx, ty, attempts):
            """Choose the best delta among the given attempts.

            tx, ty: target ending postion
            attempts: {(dx,dy): [(rx,ry), ...]} dict of mouse delta to resulting position.
            """
            bestdelta = None
            bestpos = None
            bestdif = None
            for delta, results in attempts.items():
                avgx = 0
                avgy = 0
                for x, y in results:
                    avgx += x
                    avgy += y
                avgx /= len(results)
                avgy /= len(results)
                diff = abs(avgx - tx) + abs(avgy - ty)
                if bestdelta is None or diff < bestdif:
                    bestdelta = delta
                    bestpos = (int(round(avgx)), int(round(avgy)))
                    bestdif = diff
            return bestdelta, bestpos

        def add_delta(motion, targetidx, calibrated, position, samples=3, margin=float('inf')):
            """Add a single delta to calibrated motion.

            motion: sequence of tuple: [(x,y,delay)...], screen positions,
                    delay in msec.
            calibrated: sequence of tuple: [(dx, dy, delay)...] mouse deltas,
                        delay in msec.
            position: estimated ending position of input calibrated.

            Return the new position.
            """
            tx, ty, delay = motion[targetidx]
            prex, prey = position
            dx = tx - prex
            dy = ty - prey
            eprint(f'target step: ({px}, {py}) -> ({tx}, {ty})')
            if dx == 0 and dy == 0:
                return position
            sx, sy, lox, hix, loy, hiy = prep_range(dx, dy)
            attempts = defaultdict(list)
            while 1:
                gx = (lox + (hix-lox)//2)*sx
                gy = (loy + (hiy-loy)//2)*sy
                self.move(motion[0][0], motion[0][1], True, 5)
                for x, y, t in calibrated:
                    time.sleep(t/1000.0)
                    self.bash(f'ydotool mousemove -x {x} -y {y} >&2; echo').stdout.readline()
                time.sleep(delay/1000.0)
                self.bash(f'ydotool mousemove -x {gx} -y {gy} >&2; echo').stdout.readline()
                x, y = self.pos.readmouse()
                eprint(f'  mouse guess ({gx},{gy}) -> screen ({x}, {y}):')
                attempts[(gx, gy)].append((x,y))
                if len(attempts[(gx,gy)]) >= samples:
                    bestdelta, bestpos = pick_best(tx, ty, attempts)
                    if bestdelta == (gx, gy):
                        if abs(bestpos[0] - tx) < margin and abs(bestpos[1] - ty) < margin:
                            calibrated.append(bestdelta + (delay,))
                            eprint(f'  final delta: {bestdelta}')
                            eprint(f'  final point: ({x}, {y})')
                            return bestpos
                        else:
                            eprint('  Not within margin.')
                            return None
                    eprint(f'    x: ({lox}-{hix}) -> ', end='')
                    lox, hix = adjust_bounds(lox, hix, x-prex, dx)
                    eprint(f'({lox}-{hix}), y: ({loy}-{hiy}) -> ', end='')
                    loy, hiy = adjust_bounds(loy, hiy, y-prey, dy)
                    eprint(f'({loy}-{hiy})')
        def best_idx(motion, position, idx):
            """Choose the best index for the next target given motion and current position and idx."""
            best = idx
            delta = abs(motion[idx][0] - position[0]) + abs(motion[idx][1] - position[1])
            for candidate in range(idx+1, len(motion)):
                ndelta = (abs(motion[candidate][0] - position[0])
                          + abs(motion[candidate][1] - position[1]))
                if ndelta < delta:
                    best = candidate
                    delta = ndelta
                else:
                    break
            return best
        calibrated = []
        position = motion[0][:2]
        idx = 1
        while idx < len(motion):
            position = add_delta(motion, idx, calibrated, position, samples, margin)
            nidx = best_idx(motion, position, idx)
            if nidx != len(motion)-1 or idx == nidx:
                idx = nidx+1
            else:
                idx = nidx
        return calibrated

    def calibrate3(self, msecs=range(0,2000,100), samples=3):
        data = {}
        for msec in msecs:
            data[msec] = []
            eprint('{:4d}: '.format(msec), end='')
            for i in range(samples):
                start = self.pos.readmouse()
                time.sleep(msec/1000.0)
                self.bash('ydotool mousemove -x 10 -y 10 >&2; echo').stdout.readline()
                stop = self.pos.readmouse()
                time.sleep(msec/1000.0)
                self.bash('ydotool mousemove -x -10 -y -10 >&2; echo').stdout.readline()
                data[msec].append((stop[0]-start[0], stop[1]-start[1]))
                eprint('({:4d}, {:4d}), '.format(*data[msec][-1]), end='')
            eprint()
        return data

    def calibrate2(self, cases=itertools.chain.from_iterable(
            [[(v,0), (0,v), (v, v), (v, v//2), (v//2, v)] for v in range(10, 100, 10)]),
        samples=3, wait=0):
        """Calibrate actual motion to mouse motion (single ydo call).

        cases: cases of relative mouse motions.
        samples: number of samples to collect for each case.
        wait: wait time after readmouse (idle mouse duration.)
        return {wait_time: {avg_screen_motion: required_mouse_motion}}
        """
        if isinstance(wait, (float, int)):
            wait = [wait]
        if not wait:
            wait = [0]
        results = {}
        for tm in wait:
            wresults = results[tm] = {}
            eprint(f'wait {tm:.3f} seconds')
            for delta in cases:
                eprint('  ({:4d}, {:4d}): '.format(*delta), end='')
                tx = 0
                ty = 0
                self.bash(
                    'ydotool mousemove -x {-delta[0]} -y {-delta[1]} >&2; echo'
                    ).stdout.readline()
                for sample in range(samples):
                    p1 = self.pos.readmouse()
                    if tm:
                        time.sleep(tm)
                    self.bash('ydotool mousemove -x {} -y {} >&2; echo'.format(
                        *delta)).stdout.readline()
                    p2 = self.pos.readmouse()
                    if tm:
                        time.sleep(tm)
                    self.bash(
                        f'ydotool mousemove -x {-delta[0]} -y {-delta[1]} >&2; echo'
                        ).stdout.readline()
                    dx = p2[0]-p1[0]
                    dy = p2[1]-p1[1]
                    eprint(f'({dx:4d}, {dy:4d}), ', end='')
                    tx += dx
                    ty += dy
                eprint()
                tx /= samples
                ty /= samples
                wresults[(int(round(tx)), int(round(ty)))] = delta
        return results

    def calibrate(
        self,
        cases=itertools.chain.from_iterable(
            [[(v,0), (0,v), (v, v), (v, v//2), (v//2, v)] for v in range(10, 100, 10)]),
        samples=3, wait=0
    ):
        """Calibrate actual motion to mouse motion (incremental 1-pix loop).

        cases: list of (x,y) relative mouse motions.
        samples: int, number of samples to measure per case.
        wait: amount of time to wait just before moving the mouse.
              (idle mouse duration.)
        Return {wait_time: {avg_screen_motion: required_mouse_motion}}
        """
        def reset(dim):
            mid = (self.pos.W//2, self.pos.H//2)
            target = [0, 0]
            target[1-dim] = mid[1-dim]
            pos = self.pos.readmouse()
            while pos[dim] != 0:
                dx = (target[0] - pos[0])
                dy = (target[1] - pos[1])
                if abs(dx) > 1:
                    dx //= 2
                if abs(dy) > 1:
                    dy //= 2
                self.bash('smove', dx, dy, ' >&2; echo').stdout.readline()
                pos = self.pos.readmouse()
        if isinstance(wait, (float, int)):
            wait = [wait]
        if not wait:
            wait = [0]
        results = {}
        for tm in wait:
            wresults = results[tm] = {}
            eprint(f'wait {tm:.3f} seconds')
            for delta in cases:
                eprint('  ({:4d}, {:4d}): '.format(*delta), end='')
                tx = 0
                ty = 0
                for sample in range(samples):
                    reset(int(delta[1] > delta[0]))
                    p1 = self.pos.readmouse()
                    if tm:
                        time.sleep(tm)
                    self.bash(
                        'smove {} {} >&2\necho'.format(*delta)).stdout.readline()
                    p2 = self.pos.readmouse()
                    dx = p2[0]-p1[0]
                    dy = p2[1]-p1[1]
                    eprint(f'({dx:4d}, {dy:4d}), ', end='')
                    tx += dx
                    ty += dy
                eprint()
                tx /= samples
                ty /= samples
                wresults[(int(round(tx)), int(round(ty)))] = delta
        return results

    def cmove(self, x, y, calibration, absolute=False):
        """Calculate the mouse (mx,my) to move for screen motion (x,y).

        x, y: int, The desired screen movement.
        calibration: dict, result of calibrate(),
                     {waittime: {screenmotion: mousemotion}}.
        absolute: bool, Indicate whether x,y are absolute coordinates.
        """
        if absolute:
            x, y = [d-s for d, s in zip((x,y), self.pos.readmouse())]
        wt = min(calibration)
        curve = calibration[wt]
        target = (x, y)
        mousemotion = []
        for dim in range(2):
            val = abs(target[dim])
            if val == 0:
                mousemotion.append(0)
                continue
            lo = hi = None
            for screen in curve:
                check = abs(screen[dim])
                if check == val:
                    lo = hi = screen
                elif check < val:
                    if lo is None or abs(lo[dim]) < check:
                        lo = screen
                else:
                    if hi is None or check < abs(hi[dim]):
                        hi = screen
            if lo is None or hi is None or lo == hi:
                screen = lo or hi
                mouse = curve[screen]
                mousemotion.append(int(round(target[dim] * abs(mouse[dim]) / abs(screen[dim]))))
            else:
                lomouse = abs(curve[lo][dim])
                loscreen = abs(lo[dim])
                himouse = abs(curve[hi][dim])
                hiscreen = abs(hi[dim])
                mousemotion.append(
                    int(round(
                        lomouse
                        +(val-loscreen)*(himouse-lomouse)/(hiscreen-loscreen))))
                if target[dim] < 0:
                    mousemotion[-1] *= -1
        return mousemotion

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
    import argparse
    p = argparse.ArgumentParser()
    p.add_argument('-d', '--daemon', action='store_true')
    p.add_argument(
        '-c', '--calibrate', type=float, nargs='*',
        help='seconds to wait for calibration.')
    p.add_argument(
        '--calibrate2', type=float, nargs='*',
        help='seconds to wait for calibration.')
    p.add_argument('-y', '--ydotool', action='store_true')
    args = p.parse_args()
    if args.daemon:
        with ydotoold() as d:
            try:
                input('Press return to exit.')
            except KeyboardInterrupt:
                pass
    elif args.calibrate is not None:
        with ydotool() as y:
            y.calibrate(wait=args.calibrate)
    elif args.calibrate2 is not None:
        with ydotool() as y:
            y.calibrate2(wait=args.calibrate2)
    elif args.ydotool:
        with ydotool() as y:
            import code
            code.interact(local=locals())
    else:
        with MousePosition(True) as m:
            t = tk.Toplevel(m.tk)
            t.title('top')
            t.bindtags((str(m.tk),) + t.bindtags())
            t.bind('<space>', lambda e: print(m.readmouse(False)))
            t.bind('<Return>', lambda e: print(m.readmouse(True)))
            t.bind('<Escape>', 'destroy '+str(t))
            t.wait_window()
