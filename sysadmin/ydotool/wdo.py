import ctypes
import time

MSEC = 1.0/1000.0

class _LPoint(ctypes.Structure):
    _fields_ = [('x', ctypes.c_long), ('y', ctypes.c_long)]

class Mouse(object):
    LEFT = 0x0
    RIGHT = 0x1
    MIDDLE = 0x2
    SIDE = 0x3
    EXTR = 0x4
    FORWARD = 0x5
    BACK = 0x6
    TASK = 0x7
    DOWN = 0x40
    UP = 0x80

    _WIN_MOVE = 0x0001
    _WIN_LEFTDOWN = 0x0002
    _WIN_LEFTUP = 0x0004
    _WIN_RIGHTDOWN = 0x0008
    _WIN_RIGHTUP = 0x0010
    _WIN_MIDDLEDOWN = 0x0020
    _WIN_MIDDLEUP = 0x0040
    _WIN_XDOWN = 0x0080
    _WIN_XUP = 0x0100
    _WIN_WHEEL = 0x0800
    _WIN_HWHEEL = 0x1000
    _WIN_ABSOLUTE = 0x8000
    _WIN_WHEELDELTA = 120

    _WIN_XBUTTON1 = 1
    _WIN_XBUTTON2 = 2

class Keyboard(object):
    ALIASES = [
        '0zero',
        '1one',
        '2two',
        '3three',
        '4four',
        '5five',
        '6six',
        '7seven',
        '8eight',
        '9nine',
        '\tTab',
        '\nReturn',
        ' space',
        '`grave',
        '-minus',
        '=equal',
        '[bracketleft',
        ']bracketright',
        '\\backslash',
        ';semicolon',
        '\'apostrophe',
        ',comma',
        '.period',
        '/slash',
    ]
    NOSHIFT = 'abcdefghijklmnopqrstuvwxyz`1234567890-=[]\\;\',./'
    SHIFTED = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ~!@#$%^&*()_+{}|:"<>?'
    def __init__(self):
        self.update({alias[:1]: self[alias[1:]] for alias in self.ALIASES})
        self.shift = {newk: self[oldk] for newk, oldk in zip(self.SHIFTED, self.NOSHIFT)}

    def __getattr__(self, attr):
        try:
            ret = self[attr]
        except KeyError:
            raise AttributeError(attr)
        else:
            setattr(self, attr, ret)
            return ret

    def key(self, k):
        """Return (shift_needed, intkey) from strkey."""
        try:
            return False, self[k]
        except KeyError:
            return True, self.shift[k]

    def name(self, val):
        """Find the strkey given the intkey."""
        for k, v in self.items():
            if v == val:
                return k
        raise KeyError(f'No key to match value {val}')


class KeyboardWin(Keyboard):
    _rawkeys = {
        'zero': 0x30, #	0 key
        'one': 0x31, #	1 key
        'two': 0x32, #	2 key
        'three': 0x33, #	3 key
        'four': 0x34, #	4 key
        'five': 0x35, #	5 key
        'six': 0x36, #	6 key
        'seven': 0x37, #	7 key
        'eight': 0x38, #	8 key
        'nine': 0x39, #	9 key
        'a': 0x41, #	A key
        'b': 0x42, #	B key
        'c': 0x43, #	C key
        'd': 0x44, #	D key
        'e': 0x45, #	E key
        'f': 0x46, #	F key
        'g': 0x47, #	G key
        'h': 0x48, #	H key
        'i': 0x49, #	I key
        'j': 0x4A, #	J key
        'k': 0x4B, #	K key
        'l': 0x4C, #	L key
        'm': 0x4D, #	M key
        'n': 0x4E, #	N key
        'o': 0x4F, #	O key
        'p': 0x50, #	P key
        'q': 0x51, #	Q key
        'r': 0x52, #	R key
        's': 0x53, #	S key
        't': 0x54, #	T key
        'u': 0x55, #	U key
        'v': 0x56, #	V key
        'w': 0x57, #	W key
        'x': 0x58, #	X key
        'y': 0x59, #	Y key
        'z': 0x5A, #	Z key
        'space': 0x20, #	Spacebar key
        'grave': 0xC0, #	It can vary by keyboard. For the US ANSI keyboard, the Grave Accent and Tilde key
        'minus': 0xBD, #	For any country/region, the Dash and Underscore key
        'equal': 0xBB, #	For any country/region, the Equals and Plus key
        'bracketleft': 0xDB, #	It can vary by keyboard. For the US ANSI keyboard, the Left Brace key
        'bracketright': 0xDD, #	It can vary by keyboard. For the US ANSI keyboard, the Right Brace key
        'backslash': 0xDC, #	It can vary by keyboard. For the US ANSI keyboard, the Backslash and Pipe key
        # 'VK_OEM_102': 0xE2, #	It can vary by keyboard. For the European ISO keyboard, the Backslash and Pipe key
        'semicolon': 0xBA, #	It can vary by keyboard. For the US ANSI keyboard , the Semiсolon and Colon key
        'apostrophe': 0xDE, #	It can vary by keyboard. For the US ANSI keyboard, the Apostrophe and Double Quotation Mark key
        'comma': 0xBC, #	For any country/region, the Comma and Less Than key
        'period': 0xBE, #	For any country/region, the Period and Greater Than key
        'slash': 0xBF, #	It can vary by keyboard. For the US ANSI keyboard, the Forward Slash and Question Mark key
        'F1': 0x70, #	F1 key
        'F2': 0x71, #	F2 key
        'F3': 0x72, #	F3 key
        'F4': 0x73, #	F4 key
        'F5': 0x74, #	F5 key
        'F6': 0x75, #	F6 key
        'F7': 0x76, #	F7 key
        'F8': 0x77, #	F8 key
        'F9': 0x78, #	F9 key
        'F10': 0x79, #	F10 key
        'F11': 0x7A, #	F11 key
        'F12': 0x7B, #	F12 key
        'F13': 0x7C, #	F13 key
        'F14': 0x7D, #	F14 key
        'F15': 0x7E, #	F15 key
        'F16': 0x7F, #	F16 key
        'F17': 0x80, #	F17 key
        'F18': 0x81, #	F18 key
        'F19': 0x82, #	F19 key
        'F20': 0x83, #	F20 key
        'F21': 0x84, #	F21 key
        'F22': 0x85, #	F22 key
        'F23': 0x86, #	F23 key
        'F24': 0x87, #	F24 key
        'Escape': 0x1B, #	Esc key
        'BackSpace': 0x08, #	Backspace key
        'Return': 0x0D, #	Enter key
        'Insert': 0x2D, #	Insert key
        'Home': 0x24, #	Home key
        'Prior': 0x21, #	Page up key
        'Delete': 0x2E, #	Delete key
        'End': 0x23, #	End key
        'Next': 0x22, #	Page down key
        'Tab': 0x09, #	Tab key
        'Caps_Lock': 0x14, #	Caps lock key
        'Scroll_Lock': 0x91, #	Scroll lock key
        'Num_Lock': 0x90, #	Num lock key
        'Pause': 0xB3, #	Play/Pause Media key
        'Super_L': 0x5B, #	Left Windows logo key
        'Super_R': 0x5C, #	Right Windows logo key
        'Alt_L': 0xA4, #	Left Alt key
        'Alt_R': 0xA5, #	Right Alt key
        'Shift_L': 0xA0, #	Left Shift key
        'Shift_R': 0xA1, #	Right Shift key
        'Control_L': 0xA2, #	Left Ctrl key
        'Control_R': 0xA3, #	Right Ctrl key
        'Shift': 0x10, #	Shift key (for use with keystate?)
        'Control': 0x11, #	Ctrl key (for use with keystate?)
        'Alt': 0x12, #	Alt key (for use with keystate?)
        'Up': 0x26, #	Up arrow key
        'Left': 0x25, #	Left arrow key
        'Down': 0x28, #	Down arrow key
        'Right': 0x27, #	Right arrow key
        'PrintScreen': 0x2C, #	Print screen key
        'Numpad_0': 0x60, #	Numeric keypad 0 key
        'Numpad_1': 0x61, #	Numeric keypad 1 key
        'Numpad_2': 0x62, #	Numeric keypad 2 key
        'Numpad_3': 0x63, #	Numeric keypad 3 key
        'Numpad_4': 0x64, #	Numeric keypad 4 key
        'Numpad_5': 0x65, #	Numeric keypad 5 key
        'Numpad_6': 0x66, #	Numeric keypad 6 key
        'Numpad_7': 0x67, #	Numeric keypad 7 key
        'Numpad_8': 0x68, #	Numeric keypad 8 key
        'Numpad_9': 0x69, #	Numeric keypad 9 key
        'Numpad_asterisk': 0x6A, #	Multiply key
        'Numpad_plus': 0x6B, #	Add key
        'Numpad_minus': 0x6D, #	Subtract key
        'Numpad_period': 0x6E, #	Decimal key
        'Numpad_slash': 0x6F, #	Divide key

        # 'VK_SEPARATOR': 0x6C, #	Separator key
        # 'VK_LBUTTON': 0x01, #	Left mouse button
        # 'VK_RBUTTON': 0x02, #	Right mouse button
        # 'VK_CANCEL': 0x03, #	Control-break processing
        # 'VK_MBUTTON': 0x04, #	Middle mouse button
        # 'VK_XBUTTON1': 0x05, #	X1 mouse button
        # 'VK_XBUTTON2': 0x06, #	X2 mouse button
        # 	# 0x07	Reserved
        # 	# 0x0A-0B	Reserved
        # 'VK_CLEAR': 0x0C, #	Clear key
        # 	# 0x0E-0F	Unassigned
        # 'VK_PAUSE': 0x13, #	Pause key
        # 'VK_KANA': 0x15, #	IME Kana mode
        # 'VK_HANGUL': 0x15, #	IME Hangul mode
        # 'VK_IME_ON': 0x16, #	IME On
        # 'VK_JUNJA': 0x17, #	IME Junja mode
        # 'VK_FINAL': 0x18, #	IME final mode
        # 'VK_HANJA': 0x19, #	IME Hanja mode
        # 'VK_KANJI': 0x19, #	IME Kanji mode
        # 'VK_IME_OFF': 0x1A, #	IME Off
        # 'VK_CONVERT': 0x1C, #	IME convert
        # 'VK_NONCONVERT': 0x1D, #	IME nonconvert
        # 'VK_ACCEPT': 0x1E, #	IME accept
        # 'VK_MODECHANGE': 0x1F, #	IME mode change request
        # 'VK_SELECT': 0x29, #	Select key
        # 'VK_PRINT': 0x2A, #	Print key
        # 'VK_EXECUTE': 0x2B, #	Execute key
        # 'VK_HELP': 0x2F, #	Help key
        # 0x3A-40	Undefined
        # 'VK_APPS': 0x5D, #	Application key
        # 0x5E	Reserved
        # 'VK_SLEEP': 0x5F, #	Computer Sleep key
        # 0x88-8F	Reserved
        # 0x92-96	OEM specific
        # 0x97-9F	Unassigned
        # 'VK_BROWSER_BACK': 0xA6, #	Browser Back key
        # 'VK_BROWSER_FORWARD': 0xA7, #	Browser Forward key
        # 'VK_BROWSER_REFRESH': 0xA8, #	Browser Refresh key
        # 'VK_BROWSER_STOP': 0xA9, #	Browser Stop key
        # 'VK_BROWSER_SEARCH': 0xAA, #	Browser Search key
        # 'VK_BROWSER_FAVORITES': 0xAB, #	Browser Favorites key
        # 'VK_BROWSER_HOME': 0xAC, #	Browser Start and Home key
        # 'VK_VOLUME_MUTE': 0xAD, #	Volume Mute key
        # 'VK_VOLUME_DOWN': 0xAE, #	Volume Down key
        # 'VK_VOLUME_UP': 0xAF, #	Volume Up key
        # 'VK_MEDIA_NEXT_TRACK': 0xB0, #	Next Track key
        # 'VK_MEDIA_PREV_TRACK': 0xB1, #	Previous Track key
        # 'VK_MEDIA_STOP': 0xB2, #	Stop Media key
        # 'VK_LAUNCH_MAIL': 0xB4, #	Start Mail key
        # 'VK_LAUNCH_MEDIA_SELECT': 0xB5, #	Select Media key
        # 'VK_LAUNCH_APP1': 0xB6, #	Start Application 1 key
        # 'VK_LAUNCH_APP2': 0xB7, #	Start Application 2 key
        # 0xB8-B9	Reserved
        # 0xC1-C2	Reserved
        # 'VK_GAMEPAD_A': 0xC3, #	Gamepad A button
        # 'VK_GAMEPAD_B': 0xC4, #	Gamepad B button
        # 'VK_GAMEPAD_X': 0xC5, #	Gamepad X button
        # 'VK_GAMEPAD_Y': 0xC6, #	Gamepad Y button
        # 'VK_GAMEPAD_RIGHT_SHOULDER': 0xC7, #	Gamepad Right Shoulder button
        # 'VK_GAMEPAD_LEFT_SHOULDER': 0xC8, #	Gamepad Left Shoulder button
        # 'VK_GAMEPAD_LEFT_TRIGGER': 0xC9, #	Gamepad Left Trigger button
        # 'VK_GAMEPAD_RIGHT_TRIGGER': 0xCA, #	Gamepad Right Trigger button
        # 'VK_GAMEPAD_DPAD_UP': 0xCB, #	Gamepad D-pad Up button
        # 'VK_GAMEPAD_DPAD_DOWN': 0xCC, #	Gamepad D-pad Down button
        # 'VK_GAMEPAD_DPAD_LEFT': 0xCD, #	Gamepad D-pad Left button
        # 'VK_GAMEPAD_DPAD_RIGHT': 0xCE, #	Gamepad D-pad Right button
        # 'VK_GAMEPAD_MENU': 0xCF, #	Gamepad Menu/Start button
        # 'VK_GAMEPAD_VIEW': 0xD0, #	Gamepad View/Back button
        # 'VK_GAMEPAD_LEFT_THUMBSTICK_BUTTON': 0xD1, #	Gamepad Left Thumbstick button
        # 'VK_GAMEPAD_RIGHT_THUMBSTICK_BUTTON': 0xD2, #	Gamepad Right Thumbstick button
        # 'VK_GAMEPAD_LEFT_THUMBSTICK_UP': 0xD3, #	Gamepad Left Thumbstick up
        # 'VK_GAMEPAD_LEFT_THUMBSTICK_DOWN': 0xD4, #	Gamepad Left Thumbstick down
        # 'VK_GAMEPAD_LEFT_THUMBSTICK_RIGHT': 0xD5, #	Gamepad Left Thumbstick right
        # 'VK_GAMEPAD_LEFT_THUMBSTICK_LEFT': 0xD6, #	Gamepad Left Thumbstick left
        # 'VK_GAMEPAD_RIGHT_THUMBSTICK_UP': 0xD7, #	Gamepad Right Thumbstick up
        # 'VK_GAMEPAD_RIGHT_THUMBSTICK_DOWN': 0xD8, #	Gamepad Right Thumbstick down
        # 'VK_GAMEPAD_RIGHT_THUMBSTICK_RIGHT': 0xD9, #	Gamepad Right Thumbstick right
        # 'VK_GAMEPAD_RIGHT_THUMBSTICK_LEFT': 0xDA, #	Gamepad Right Thumbstick left
        # 'VK_OEM_8': 0xDF, #	It can vary by keyboard. For the Canadian CSA keyboard, the Right Ctrl key
        # 0xE0	Reserved
        # 0xE1	OEM specific
        # 0xE3-E4	OEM specific
        # 'VK_PROCESSKEY': 0xE5, #	IME PROCESS key
        # 0xE6	OEM specific
        # 'VK_PACKET': 0xE7, #	Used to pass Unicode characters as if they were keystrokes. The VK_PACKET key is the low word of a 32-bit Virtual Key value used for non-keyboard input methods. For more information, see Remark in KEYBDINPUT, SendInput, WM_KEYDOWN, and WM_KEYUP
        # 0xE8	Unassigned
        # 0xE9-F5	OEM specific
        # 'VK_ATTN': 0xF6, #	Attn key
        # 'VK_CRSEL': 0xF7, #	CrSel key
        # 'VK_EXSEL': 0xF8, #	ExSel key
        # 'VK_EREOF': 0xF9, #	Erase EOF key
        # 'VK_PLAY': 0xFA, #	Play key
        # 'VK_ZOOM': 0xFB, #	Zoom key
        # 'VK_NONAME': 0xFC, #	Reserved
        # 'VK_PA1': 0xFD, #	PA1 key
        # 'VK_OEM_CLEAR': 0xFE, #	Clear key
    }

    def get(self, *args):
        self._rawkeys.get(*args)
    def update(self, *args):
        self._rawkeys.update(*args)
    def items(self):
        return self._rawkeys.items()
    def __contains__(self, key):
        return key in self._rawkeys
    def __getitem__(self, key):
        return self._rawkeys[key]


class ydotool(object):
    def type(self, text, nextdelay=0, keydelay=12):
        """Type the given text.

        nextdelay: delay between actions (up/down)
        keydelay: delay between keys
        """
        keyboard = self.k
        shift = keyboard['Shift_L']
        if self.lockstate('Caps_Lock'):
            text = text.swapcase()
        for i, k in enumerate(text):
            if i:
                time.sleep(keydelay*MSEC)
            if k in keyboard:
                self.keypress(keyboard[k])
            elif k in keyboard.shift:
                self.keypress(shift, up=False)
                self.keypress(keyboard.shift[k], delay=nextdelay)
                self.keypress(shift, down=False)


class ydowin(ydotool):
    m = Mouse
    k = KeyboardWin()
    # https://learn.microsoft.com/en-us/windows/win32/inputdev/virtual-key-codes

    def __init__(self, *args, **kwargs):
        """Create ydotool instance."""
        # args to allow same interface, but no actual state so all static.
        pass

    @staticmethod
    def lockstate(key='Caps_Lock'):
        """Return state for caps/num/scrollock."""
        if isinstance(key, str):
            key = ydowin.k[key]
        result = ctypes.windll.user32.GetKeyState(key)
        # NOTE: result < 0 implies key is currently pressed down
        # but only interested in the lock state for now...
        return bool(result & 1)

    @staticmethod
    def screenwidth():
        return ctypes.windll.user32.GetSystemMetrics(0) # SM_CXSCREEN
    @staticmethod
    def screenheight():
        return ctypes.windll.user32.GetSystemMetrics(1) # SM_CYSCREEN
    @staticmethod
    def pos():
        result = _LPoint()
        if ctypes.windll.user32.GetCursorPos(ctypes.pointer(result)):
            return result.x, result.y
        else:
            raise OSError('Failed to get cursor position.')

    # ctypes.windll.user32.mouse_event(dwFlags, dx, dy, dwData):
    # dwFlags: above flags combo
    # dx, dy: change in x,y OR absolute (if ABSOLUTE flag)
    # dwData:
    #     WHEEL: >0 = wheel forward (away from user), < 0 = towards use
    #     HWHEEL: wheel tilt, >0 = right, <0 = left
    #     XDOWN/XUP: index of X button
    #     else 0
    @staticmethod
    def click(code, repeat=1, delay=25, **kwargs):
        """Click the mouse.

        code: m.[LEFT|RIGHT|MIDDLE|SIDE|EXTR|FORWARD|BACK|TASK] | m.[UP|DOWN]
              If neither up nor down are given, then assume both.
        repeat: times to repeat
        delay: delay between repeats (msec)

        NOTE: some not too sure...
              windows has X and Wheel aside from left/right/middle
              but linux seems to have SIDE EXTR FORWARD BACK
              what are these? mouse forward/back keys? dunno...
              what is side and what is extr?
              maybe HWHEEL is FORWARD/BACK?
              XUP/XDOWN would be side and extra using the extra info?
              maybe side = XBUTTON1 and extr = XBUTTON2?
        """
        key = code & 0x07
        down = bool(code & 0x40)
        up = bool(code & 0x80)
        if not (up or down):
            up = down = True
        codes = []
        if key < 3:
            if down:
                codes.append((1 << (key*2 + 1), 0, 0, 0, 0))
            if up:
                codes.append((1 << (key*2 + 2), 0, 0, 0, 0))
        elif key < 5:
            if down:
                codes.append((Mouse._WIN_XDOWN, 0, 0, key-2, 0))
            if up:
                codes.append((Mouse._WIN_XUP, 0, 0, key-2, 0))
        else:
            raise ValueError(
                f'Mouse key not supported: {("FORWARD", "BACK", "TASK")[key-5]}')

        for idx in range(len(codes)):
            if idx:
                time.sleep(0.008)
            ctypes.windll.user32.mouse_event(*codes[idx])
        for item in range(1, repeat):
            time.sleep(delay*MSEC)
            for idx in range(len(codes)):
                if idx:
                    time.sleep(0.008)
                ctypes.windll.user32.mouse_event(*codes[idx])

    @staticmethod
    def move(dx, dy, absolute=True):
        """Move the cursor (Inexact).

        dx, dy: int, the amount to move.
        absolute: bool, If absolute, then dx, dy are screen pixel coordinates.
        """
        ctypes.windll.user32.mouse_event(
            Mouse._WIN_MOVE | (int(absolute) * Mouse._WIN_ABSOLUTE), dx, dy, 0, 0)

    @staticmethod
    def keypress(key, down=True, up=True, delay=0):
        """Press a single key.

        key: int or string repr of the key
        delay: int (msec), delay between down and up.
        """
        # SendInput seems to handle both mouse and keyboard instead of
        # separately but requires much more prep with nested structs.
        #
        # keybd_event(bVirtkey, scancode, dwFlags, extra)
        # flags:
        #     extendedkey = 1: If specified, the scan code was preceded by a prefix byte having the value 0xE0 (224).
        #     keyup = 2: key up instead of down
        # ctypes.windll.user32.keybd_event()
        if isinstance(key, str):
            key = ydowin.k[key]
        if down:
            ctypes.windll.user32.keybd_event(key, 0, 0, 0)
            if up:
                time.sleep(delay*MSEC)
        if up:
            ctypes.windll.user32.keybd_event(key, 0, 2, 0)

    def __enter__(self):
        return self
    def __exit__(self, tp, exc, tb):
        pass
    def close(self):
        pass
