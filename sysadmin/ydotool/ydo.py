"""

Notes on sudo:
    It seems like sudo defaults to reading password from the terminal.
    This means there is no special handling required for sudo password.
    Once the process is started, then there's no need for anymore sudo.
"""
import codecs
import tkinter as tk
import subprocess as sp
import getpass
import io
import time
import shlex
import os
import threading
import queue
import pty
import select
import traceback
import sys

threading.Thread()

class Ignore(object):
    def write(self, data):
        return len(data)
    def flush(self):
        pass

class ToStderr(object):
    def __init__(self, decoder):
        self.decoder = decoder
    def write(self, data):
        print(self.decoder.decode(data), end='', file=sys.stderr)
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
    if dst is None:
        dec = codecs.getincrementaldecoder('utf-8')()

    buf = bytearray(io.DEFAULT_BUFFER_SIZE)
    view = memoryview(buf)
    while 1:
        amt = src.readinto(buf)
        if amt == 0:
            if dst is None:
                print(dec.decode(b'', final=True), end='')
            else:
                dst.flush()
            return
        if dst is None:
            print(dec.decode(buf[:amt]), end='')
        else:
            total = 0
            while total < amt:
                total += dst.write(view[total:amt])

class MousePosition(object):
    """Use tkinter window to track mouse position."""

    HIDE_CMD = 'hide_mouse_position_reader'
    def __init__(self, verbose=False):
        self.verbose = verbose
        self.lock = threading.Lock()
        self._pos = (0,0)
        self.tk, self.step, self.W, self.H = self.open()

    def open(self):
        """Initialize a tk instance.

        Return the root and the screen shape.
        """
        r = tk.Tk()
        r.attributes('-topmost', True, '-fullscreen', True)
        r.withdraw()
        r.createcommand(self.HIDE_CMD, self.hide)
        r.bind('<Motion>', self.HIDE_CMD)
        return r, tk.IntVar(r), r.winfo_screenwidth(), r.winfo_screenheight()

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
            self._pos = self.tk.winfo_pointerxy()
            if self.verbose:
                print('\tmeasured mouse', self._pos, file=sys.stderr)
        self.step.set(self.step.get()+1)
        self.tk.withdraw()

    def pos(self):
        """Get currently stored mouse position."""
        with self.lock:
            return self._pos

    def readmouse(self, *args):
        """Read the current mouse position.

        This temporarily sets the tk window to fullscren to ensure that
        the mouse is within the window allowing reading its position.
        """
        self.tk.deiconify()
        r.attributes('-topmost', True, '-fullscreen', True)
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
    def __enter__(self):
        self.push()
        return self
    def __exit__(self, tp, exc, tb):
        self.pop()
    def __del__(self):
        while self.accel:
            self.pop()

class ydotoold(object):
    """Context manager for the ydotoold daemon."""
    def __init__(self, sock=None, verbose=True):
        """Initialize ydotoold.

        sock: The socket path for ydotoold.
        """
        if sock is None:
            sock = f'/dev/shm/{os.environ["USER"]}_ydo.sock'
        self.verbose = verbose
        self.path = sock
        self.masterfd = None
        self.proc = None
        self.thread = None
        self.open()

    def __str__(self):
        """Return the ydotoold socket path."""
        return self.path

    def open(self):
        """Open ydotoold process if needed."""
        if self.masterfd is not None:
            return
        masterfd, slavefd = pty.openpty()
        # Use a bash process to start ydotoold
        # so that bash will still have root permissions
        # such as from sudo, when the process should be
        # closed.  (root permissions might be needed to
        # cleanup the socket.)
        # Must use openpty or ydotoold will have no output,
        # cannot tell if it is ready or not.

        if os.environ['USER'] == 'root':
            command = ['bash']
        else:
            command = ['sudo', 'bash']

        self.proc = sp.Popen(command, stdout=slavefd, stderr=slavefd, stdin=slavefd)
        os.close(slavefd)

        qpath = shlex.quote(self.path)
        script = (
                'trap "" SIGINT\n'
                'ydotoold -p {} &\n'
                'pid=$!\n'
                'trap "kill ${{pid}}; rm "{} EXIT\n'
                'wait ${{pid}}\n'
                'exit\n'
            ).format(qpath, shlex.quote(qpath))
        with io.BytesIO() as buf:
            if self.verbose:
                decoder = codecs.getincrementaldecoder('utf-8')()
            while self.proc.poll() is None:
                try:
                    result = os.read(masterfd, io.DEFAULT_BUFFER_SIZE)
                except IOError:
                    continue
                buf.write(result)
                if self.verbose:
                    try:
                        print(decoder.decode(result), end='', file=sys.stderr)
                    except Exception:
                        pass
                if b'READY' in buf.getvalue():
                    self.thread = threading.Thread(
                        target=forward,
                        args=[OSRead(masterfd), ToStderr(decoder) if self.verbose else Ignore()])
                    self.thread.start()
                    self.masterfd = masterfd
                    return
            raise RuntimeError('ydotoold exited before ready.')

    def __enter__(self):
        self.open()
        return self
    def __exit__(self, tp, exc, tb):
        self.close()
    def __del__(self):
        self.close()

    def close(self):
        if self.masterfd is not None:
            self.proc.terminate()
            self.proc.wait()
            os.close(self.masterfd)
            self.thread.join()
            self.masterfd = None

class Bash(object):
    def __init__(self, sudo=None, stdout=None, stderr=None):
        """Initialize bash process."""
        self.stdout = stdout
        self.stderr = stderr
        if sudo is None:
            sudo = os.environ['USER'] != 'root'
        self.sudo = sudo
        self.proc = None
        self.bashin = None
        self.open()

    def open(self):
        if self.proc is not None:
            return
        if self.sudo:
            command = ['sudo', 'bash']
        else:
            command = ['bash']
        self.proc = sp.Popen(
            command, stdin=sp.PIPE,
            stdout=self.stdout,
            stderr=self.stderr)
        self.bashin = io.TextIOWrapper(self.proc.stdin)
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
        try:
            print(*args, **kwargs, file=self.bashin)
            self.bashin.flush()
        except Exception:
            traceback.print_exc()


class ydotool(object):
    """Ydotool commands through a bash process."""
    def __init__(self, sockpath=None, stdout=None, stderr=None, noaccel=False):
        self.bash = None
        self.pos = None
        if noaccel:
            self.noaccel = NoMouseAccel()
        else:
            self.noaccel = None
        if sockpath is None:
            sockpath = f'/dev/shm/{os.environ["USER"]}_ydo.sock'
        self.sockpath = sockpath
        self.open(stdout, stderr)

    def open(self, stdout=None, stderr=None):
        if self.bash is not None:
            return
        self.bash = Bash(stdout=stdout, stderr=stderr)
        if self.noaccel is not None:
            self.noaccel.push()
        self.pos = MousePosition()
        self.bash('export YDOTOOL_SOCKET={}'.format(shlex.quote(self.sockpath)))
    def close(self):
        if self.bash is None:
            return
        if self.noaccel is not None:
            self.noaccel.pop()
        self.pos.close()
        self.bash.close()
        self.bash = None
    rawkeys = {
        'ESC': 1,
        '1': 2,
        '2': 3,
        '3': 4,
        '4': 5,
        '5': 6,
        '6': 7,
        '7': 8,
        '8': 9,
        '9': 10,
        '0': 11,
        'MINUS': 12,
        'EQUAL': 13,
        'BACKSPACE': 14,
        'TAB': 15,
        'Q': 16,
        'W': 17,
        'E': 18,
        'R': 19,
        'T': 20,
        'Y': 21,
        'U': 22,
        'I': 23,
        'O': 24,
        'P': 25,
        'LEFTBRACE': 26,
        'RIGHTBRACE': 27,
        'ENTER': 28,
        'LEFTCTRL': 29,
        'A': 30,
        'S': 31,
        'D': 32,
        'F': 33,
        'G': 34,
        'H': 35,
        'J': 36,
        'K': 37,
        'L': 38,
        'SEMICOLON': 39,
        'APOSTROPHE': 40,
        'GRAVE': 41,
        'LEFTSHIFT': 42,
        'BACKSLASH': 43,
        'Z': 44,
        'X': 45,
        'C': 46,
        'V': 47,
        'B': 48,
        'N': 49,
        'M': 50,
        'COMMA': 51,
        'DOT': 52,
        'SLASH': 53,
        'RIGHTSHIFT': 54,
        'KPASTERISK': 55,
        'LEFTALT': 56,
        'SPACE': 57,
        'CAPSLOCK': 58,
        'F1': 59,
        'F2': 60,
        'F3': 61,
        'F4': 62,
        'F5': 63,
        'F6': 64,
        'F7': 65,
        'F8': 66,
        'F9': 67,
        'F10': 68,
        'NUMLOCK': 69,
        'SCROLLLOCK': 70,
        'KP7': 71,
        'KP8': 72,
        'KP9': 73,
        'KPMINUS': 74,
        'KP4': 75,
        'KP5': 76,
        'KP6': 77,
        'KPPLUS': 78,
        'KP1': 79,
        'KP2': 80,
        'KP3': 81,
        'KP0': 82,
        'KPDOT': 83,
        'ZENKAKUHANKAKU': 85,
        '102ND': 86,
        'F11': 87,
        'F12': 88,
        'RO': 89,
        'KATAKANA': 90,
        'HIRAGANA': 91,
        'HENKAN': 92,
        'KATAKANAHIRAGANA': 93,
        'MUHENKAN': 94,
        'KPJPCOMMA': 95,
        'KPENTER': 96,
        'RIGHTCTRL': 97,
        'KPSLASH': 98,
        'SYSRQ': 99,
        'RIGHTALT': 100,
        'HOME': 102,
        'UP': 103,
        'PAGEUP': 104,
        'LEFT': 105,
        'RIGHT': 106,
        'END': 107,
        'DOWN': 108,
        'PAGEDOWN': 109,
        'INSERT': 110,
        'DELETE': 111,
        'MUTE': 113,
        'VOLUMEDOWN': 114,
        'VOLUMEUP': 115,
        'POWER': 116,
        'KPEQUAL': 117,
        'PAUSE': 119,
        'KPCOMMA': 121,
        'HANGEUL': 122,
        'HANJA': 123,
        'YEN': 124,
        'LEFTMETA': 125,
        'RIGHTMETA': 126,
        'COMPOSE': 127,
        'STOP': 128,
        'AGAIN': 129,
        'PROPS': 130,
        'UNDO': 131,
        'FRONT': 132,
        'COPY': 133,
        'OPEN': 134,
        'PASTE': 135,
        'FIND': 136,
        'CUT': 137,
        'HELP': 138,
        'CALC': 140,
        'SLEEP': 142,
        'WWW': 150,
        'COFFEE': 152,
        'BACK': 158,
        'FORWARD': 159,
        'EJECTCD': 161,
        'NEXTSONG': 163,
        'PLAYPAUSE': 164,
        'PREVIOUSSONG': 165,
        'STOPCD': 166,
        'REFRESH': 173,
        'EDIT': 176,
        'SCROLLUP': 177,
        'SCROLLDOWN': 178,
        'KPLEFTPAREN': 179,
        'KPRIGHTPAREN': 180,
        'F13': 183,
        'F14': 184,
        'F15': 185,
        'F16': 186,
        'F17': 187,
        'F18': 188,
        'F19': 189,
        'F20': 190,
        'F21': 191,
        'F22': 192,
        'F23': 193,
        'F24': 194,
        'UNKNOWN': 240,
    }
    tclkeys = {
        'Escape': 1,
        '1': 2,
        '2': 3,
        '3': 4,
        '4': 5,
        '5': 6,
        '6': 7,
        '7': 8,
        '8': 9,
        '9': 10,
        '0': 11,
        'q': 16,
        'w': 17,
        'e': 18,
        'r': 19,
        't': 20,
        'y': 21,
        'u': 22,
        'i': 23,
        'o': 24,
        'p': 25,
        'a': 30,
        's': 31,
        'd': 32,
        'f': 33,
        'g': 34,
        'h': 35,
        'j': 36,
        'k': 37,
        'l': 38,
        'z': 44,
        'x': 45,
        'c': 46,
        'v': 47,
        'b': 48,
        'n': 49,
        'm': 50,
        'F1': 59,
        'F2': 60,
        'F3': 61,
        'F4': 62,
        'F5': 63,
        'F6': 64,
        'F7': 65,
        'F8': 66,
        'F9': 67,
        'F10': 68,
        'F11': 87,
        'F12': 88,
        'F13': 183,
        'F14': 184,
        'F15': 185,
        'F16': 186,
        'F17': 187,
        'F18': 188,
        'F19': 189,
        'F20': 190,
        'F21': 191,
        'F22': 192,
        'F23': 193,
        'F24': 194,

        'minus': 12,
        'equal': 13,
        'BackSpace': 14,
        'Tab': 15,
        'braceleft': 26,
        'braceright': 27,
        'Return': 28,
        'semicolon': 39,
        'apostrophe': 40,
        'grave': 41,
        'backslash': 43,
        'comma': 51,
        'period': 52,
        'slash': 53,
        'space': 57,

        'Caps_Lock': 58,
        'Shift': 42,
        'Shift_L': 42,
        'Shift_R': 54,
        'Alt': 56,
        'Alt_L': 56,
        'Alt_R': 100,
        'Control': 29,
        'Control_L': 29,
        'Control_R': 97,
        'Super': 125,
        'Super_L': 125,
        'Super_R': 126,
        'Meta': 125,
        'Meta_L': 125,
        'Meta_R': 126,


        'Up': 103,
        'Left': 105,
        'Right': 106,
        'Down': 108,

        'Insert': 110,
        'Home': 102,
        'Prior': 104,
        'Delete': 111,
        'End': 107,
        'Next': 109,

        # keypad
        'asterisk': 55,
        'Num_Lock': 69,
        'Scroll_Lock': 70,
        'KP_7': 71,
        'KP_8': 72,
        'KP_9': 73,
        'KP_minus': 74,
        'KP_4': 75,
        'KP_5': 76,
        'KP_6': 77,
        'KP_plus': 78,
        'KP_1': 79,
        'KP_2': 80,
        'KP_3': 81,
        'KP_0': 82,
        'KP_period': 83,
        'KP_Return': 96,
        'KP_slash': 98,
    }
    def keys(arg):
        pass

    def type(self, text, nextdelay=0, keydelay=12):
        self.bash('ydotool type',  shlex.quote(text))


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
    def click(self, code=UP|DOWN|LEFT, repeat=1, delay=25):
        self.bash(
            'ydotool click 0x{:02x}'.format(code),
            '--repeat', repeat,
            '--next-delay', delay,
        )

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
            ox, oy = self.pos.readmouse()
            if not absolute:
                x += ox
                y += oy
            x = min(max(x, 0), self.pos.W-1)
            y = min(max(y, 0), self.pos.H-1)
            cx, cy = ox, oy
            it = 0
            while 1:
                it += 1
                if (cx, cy) == (x,y):
                    return
                # Limit the size of movement. If the movement
                # is too large, it might shoot past due to mouse
                # acceleration.  It would then ping-pong back and
                # forth without making any progress.
                self.bash(
                    'ydotool mousemove -x {} -y {}'.format(
                        min(max(x-cx, -100),100),
                        min(max(y-cy, -100),100)))
                cx, cy = self.pos.readmouse()
                if it >= check:
                    if (cx, cy) == (ox, oy):
                        return
                    ox, oy = cx, cy
                    it = 0
        else:
            if absolute:
                W, H = self.pos.W, self.pos.H
                W = (-W, W)['r' in absolute]
                H = (-H, H)['b' in absolute]
                self.bash('ydotool mousemove -x 0 -y {}'.format(H))
                self.bash('ydotool mousemove -x {} -y 0'.format(W))
                self.bash(
                    'ydotool mousemove -x {} -y {}'.format(
                        x-max(0, W-1), y-max(0, H-1)))
            else:
                self.bash('ydotool mousemove -x {} -y {}'.format(x, y))

    def __enter__(self):
        self.open()
        return self
    def __exit__(self, tp, exc, tb):
        self.close()
    def __del__(self):
        self.close()


class Mouse(object):
    def __init__(self, sock=f'/dev/shm/{os.environ["USER"]}_ydo.sock', verbose=False):
        self.verbose = verbose
        self.ydotoold = None
        self.bashin = None
        self.tk = None
        self.masterfd = None
        self.threads = []
        self.mouseaccel = sp.check_output(['gsettings', 'get', 'org.gnome.desktop.peripherals.mouse', 'accel-profile']).decode('utf-8')
        if self.mouseaccel != 'flat':
            sp.check_output(['gsettings', 'set', 'org.gnome.desktop.peripherals.mouse', 'accel-profile', "'flat'"])

        self.masterfd, slave = pty.openpty()
        self.ydotoold = sp.Popen(
            ['sudo', 'ydotoold', '-p', sock], stdout=slave, stderr=slave, stdin=slave)
        os.close(slave)
        with io.BytesIO() as buf:
            while 1:
                result = os.read(self.masterfd, io.DEFAULT_BUFFER_SIZE)
                buf.write(result)
                if verbose:
                    try:
                        print(result.decode('utf-8'), end='', file=sys.stderr)
                    except ValueError:
                        pass

                if b'READY' in buf.getvalue():
                    break
        self.threads.append(
            threading.Thread(
                target=forward, args=[OSRead(self.masterfd), Ignore()]))
        self.threads[-1].start()

        self.bash_ = sp.Popen(['sudo', 'bash'], stdin=sp.PIPE)
        self.bashin = io.TextIOWrapper(self.bash_.stdin)
        self.bash(f'export YDOTOOL_SOCKET="{sock}"')
        self.pos = None
        self.tk = tk.Tk()
        self.tk.createcommand('update_mouse_position', self.update_pos)
        self.tk.call('bind', self.tk, '<Configure>', 'update_mouse_position')
        self.tk.attributes('-topmost', True)
        self.tk.geometry('1x1+0+0')
        self.W = self.tk.winfo_screenwidth()
        self.H = self.tk.winfo_screenheight()
        self.fullscreen = f'{self.W}x{self.H}+0+0'
        self.updated = tk.BooleanVar(self.tk)

    def __enter__(self):
        return self
    def __exit__(self, tp, exc, tb):
        self.close()
    def __del__(self):
        self.close()
    def close(self):
        if self.bashin is not None:
            self.bash('exit')
            self.bash_.wait()
            self.bashin = None
        if self.masterfd is not None:
            os.close(self.masterfd)
            self.masterfd = None
        if self.tk is not None:
            self.tk.destroy()
            self.tk = None
        if self.ydotoold is not None:
            self.ydotoold.terminate()
            self.ydotoold = None
        for t in self.threads:
            t.join()
        self.threads = []
        if self.mouseaccel != 'flat':
            sp.check_output(['gsettings', 'set', 'org.gnome.desktop.peripherals.mouse', 'accel-profile', self.mouseaccel])


    def update_pos(self, *args):
        """Update the mouse position when configuring.

        When size is full screen, then the mouse should be within the
        tk application meaning the mouse position is now visible so wait
        until after fullscreen to read the mouse.
        """
        geom = self.tk.winfo_geometry()
        if self.verbose:
            print('configuring...', time.time(), end='\r\n', file=sys.stderr)
        if geom == self.fullscreen:
            # full screen achieved.
            # However, at this point, the pointer seems like
            # it is still not yet properly updated.
            if self.verbose:
                print('schedule non-fullscreen', end='\r\n', file=sys.stderr)
            self.pos = None
            self.tk.call(
                'after', '100',
                'wm attributes . -fullscreen false'
            )
            # self.tk.attributes('-fullscreen', False)
        elif geom.startswith('1x1') and self.pos is None:
            self.pos = self.tk.winfo_pointerxy()
            self.updated.set(True)

    def readmouse(self, *args):
        """Update the current mouse position.

        Changing to fullscreen allows the tkinter to read the
        mouse position.  Tk seems to use xwayland, so on a wayland
        system, mouse position is only visible if the mouse is inside
        the application.  Must change to fullscreen to ensure
        readiing the mouse.  Seems like after_idle must be used
        to ensure fullscreen is in effect.  Only then is mouse
        consistently read.  Otherwise, the reading seems to generally
        happen before fullscreen has completed so the mouse position
        is the old position and never updated.  Calling update() also
        does not seem to be enough...

        On wayland, deiconify works, but even using
            after timeout deiconify
        tk seems to not get deiconified, therefore, use topmost and
        toggle fullscreen instead...
        """
        self.updated.set(False)
        self.tk.attributes('-fullscreen', True)
        self.tk.wait_variable(self.updated)
        return self.pos


    def bash(self, *command, **kwargs):
        print(*command, file=self.bashin)
        self.bashin.flush()

    def move(self, x, y, reset=True):
        """Basic mouse motion.

        x, y: target destionation (absolute coordinates.)
        reset: move mouse to ensure correct positioning.
        """
        if reset or self.pos is None:
            self.bash(f'ydotool mousemove -x 0 -y {self.H}')
            self.bash(f'ydotool mousemove -x -{self.W} -y 0')
            self.bash(f'ydotool mousemove -x {x} -y {y - (self.H-1)}')
        else:
            self.bash(f'ydotool mousemove -x {x - self.pos[0]} -y {y - self.pos[1]}')
        self.pos = (x, y)

    def click(self):
        self.bash('ydotool click 0xc0')


if __name__ == '__main__':
    with MousePosition(True) as m:
        import time
        while input() != 'exit':
            time.sleep(1)
            print(m.readmouse())
