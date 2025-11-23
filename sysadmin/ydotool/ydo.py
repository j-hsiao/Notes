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
import os
import threading
import queue
import pty
import select
import traceback

threading.Thread()

class Ignore(object):
    def write(self, data):
        return len(data)
    def flush(self):
        pass

class OSRead(object):
    def __init__(self, fd):
        self.fd = fd
    def fileno(self):
        return self.fd
    if hasattr(os, readv):
        def readinto(self, buf):
            try:
                return os.readv(self.fd, [buf])
            except Exception:
                traceback.print_exc()
                return 0
    else:
        def readinto(self, buf):
            try:
                data = os.read(self.fd, len(buf))
            except Exception:
                traceback.print_exc()
                return 0
            amt = len(data)
            buf[:amt] = data
            return amt



def forward(src, dst):
    if dst is None:
        dec = codecs.getincrementaldecoder('utf-8')

    buf = bytearray(io.DEFAULT_BUFFER_SIZE)
    view = memoryview(buf)
    while 1:
        amt = src.readinto(buf)
        if amt == 0:
            if dst is None:
                print(dec.decode(b'', final=True), end='')
            dst.flush()
            return
        if dst is None:
            print(dec.decode(buf[:amt]), end='')
        else:
            total = 0
            while total < amt:
                total += dst.write(view[total:amt])

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
                        print(result.decode('utf-8'), end='')
                    except ValueError:
                        pass

                if b'READY' in buf.getvalue():
                    break
        self.threads.append(
            threading.Thread(
                target=forward, args=[OSRead(self.masterfd), ]))
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
            print('configuring...', time.time(), end='\r\n')
        if geom == self.fullscreen:
            # full screen achieved.
            # However, at this point, the pointer seems like
            # it is still not yet properly updated.
            if self.verbose:
                print('schedule non-fullscreen', end='\r\n')
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


m = Mouse('asdf')
print('initial mouse position:', m.readmouse())
