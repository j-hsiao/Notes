import os
import sys
import re
import traceback

def _load_mods():
    matcher = re.compile('rt_.*\.py')
    thisdir = os.path.abspath(os.path.realpath(os.path.dirname(__file__)))
    mods = [os.path.splitext(_)[0] for _ in os.listdir(thisdir) if matcher.match(_)]
    thismod = sys.modules[__name__]
    for modname in mods:
        cname = modname.split('_', 1)[-1]
        try:
            setattr(thismod, cname,
                    getattr(__import__(modname, globals()), cname))
        except:
            traceback.print_exc()
_load_mods()
