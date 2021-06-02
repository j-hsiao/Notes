"""Wake on lan.

Wake on lan = wake a computer over network.
This script will wake a computer via udp.

To enable wake on lan for a device:
    ubuntu:
        resources:
            https://wiki.archlinux.org/title/Wake-on-LAN#alx_driver_support
            https://bugzilla.kernel.org/show_bug.cgi?id=61651:
        enable wake on lan in bios
        enable wake on lan in software:
            if have tlp:
                set WOL_DISABLE=N in /etc/default/tlp
            add NETDOWN=no in /etc/default/halt
        check wake on lan:
            sudo ethtool <interface>
        set wake on lan:
            sudo ethtool -s <interface> wol g
        for some network cards, you may need to unpatch wol removal because of some
            wake twice bug or whatever. (alx):

            https://bugzilla.kernel.org/show_bug.cgi?id=61651:
            download automatic installer (dunno if using older version is required depending on kernel)
            decompress the automatic dkms installer and run setup
            reload the module:
                modprobe -r alx; modprobe alx
            check that it loaded the one from updates:
                modinfo alx
                /lib/modules/4.4.0-141-generic/updates/dkms/alx.ko
            then try ethtool again
    windows:
        ???
"""
from __future__ import print_function
import socket
import struct
import ast
import argparse

def wake(args):
    macaddr = args.mac
    parts = [int(_, 16) for _ in macaddr.split(':')]
    if len(parts) != 6:
        raise Exception('bad mac address, XX:XX:XX:XX:XX:XX')
    hwa = struct.pack(b'6B', *parts)
    # Just trying a different way to convert mac address
    hwa2 = ast.literal_eval(r'b"\x{}\x{}\x{}\x{}\x{}\x{}"'.format(*macaddr.split(':')))
    assert hwa2 == hwa
    # The wol magic packet is 6 0xFF bytes followed by mac address repeated 16 times
    msg = b'\xff' * 6 + (hwa * 16)
    try:
        info = socket.getaddrinfo(args.host, args.port, type=socket.SOCK_DGRAM)
        if len(info) > 1:
            print('multiple candidates for target:')
            for item in info:
                print(item)
            print('picking first item')
        family, tp, proto, cannon, addr = info[0]
    except socket.gaierror:
        print('error using getaddrinfo, falling back to tuple')
        family = socket.AF_INET
        tp = socket.SOCK_DGRAM
        addr = (args.ip, args.port)
    sock = socket.socket(family, tp)
    print("target", addr)
    try:
        if args.broadcast:
            sock.setsockopt(socket.SOL_SOCKET, socket.SO_BROADCAST, 1)
        print(sock.sendto(msg, addr))
    finally:
        sock.close()

if __name__ == '__main__':
    p = argparse.ArgumentParser(formatter_class=argparse.ArgumentDefaultsHelpFormatter)
    p.add_argument('-i', '--ip', default='10.36.172.212', help='target host/ip')
    p.add_argument('-p', '--port', type=int, default=7, help='target port')
    p.add_argument('-m', '--mac', default='1C:39:47:FA:63:FE', help='nic mac address for target machine to wake')
    p.add_argument('-b', '--broadcast', action='store_true', help='use broadcasting')
    wake(p.parse_args())
