"""Regex practice parsing date/time string with omissions.

Ymd and HMS are parsed independently.

M
H:M
H:M:S

d
m/d
y/m/d

/ can be replaced with -
The 2 halves can be joined with any spaces and at most a single T
YMD pattern requires unambiguous YMD or presence of HMS.
example:
/d
dT
d M
"""
import re
import itertools

'/2 :'

pat = re.compile(
    r'\s*(?:(?P<year>\d+)?[-/](?=\d*[-/]))?'
    r'\s*(?:(?P<month>\d+)?(?=[-/]))?'
    r'\s*(?:(?=[-/]|\d+(?:\s*T|\s+[\d:]))[-/]?(?P<day>\d+)?)?'
    r'\s*T?\s*'
    r'\s*(?:(?P<hour>\d+)?:)?'
    r'\s*(?P<minute>\d+)?'
    r'\s*(?::(?P<second>\d+)?)?'
    r'\s*'
)

if __name__ == '__main__':
    datahms = '''
2
 2
2 
 2 
2:
:2
1:2
1::
:1:
::1
1:2:
1::2
:1:2
1:2:3
'''
    dataymd = '''
2T
2/
/2
1/2
1//
/1/
//1
1/2/
1//2
/1/2
1/2/3
'''

    def check_hms(m, s):
        p = s.replace('T', ' ').split()
        if (len(p) != 2 and ':' not in s and not s.isdigit()) or not p[-1]:
            return
        p = p[-1].strip().split(':')
        if len(p) == 3:
            assert (m['hour'] is None) == (not p[0])
            assert (m['minute'] is None) == (not p[1])
            assert (m['second'] is None) == (not p[2])
        elif len(p) == 2:
            assert (m['hour'] is None) == (not p[0])
            assert (m['minute'] is None) == (not p[1])
            assert (m['second'] is None)
        else:
            assert m['hour'] is None
            assert m['minute'] is not None
            assert m['second'] is None

    def check_yms(m, t):
        p = t.replace('T', ' ').split()
        if len(p) != 2 or not p[0]:
            return
        p = p[0].strip().split('/')
        if len(p) == 3:
            assert (m['year'] is None) == (not p[0])
            assert (m['month'] is None) == (not p[1])
            assert (m['day'] is None) == (not p[2])
        elif len(p) == 2:
            assert m['year'] is None
            assert (m['month'] is None) == (not p[0])
            assert (m['day'] is None) == (not p[1])
        else:
            assert m['year'] is None
            assert m['month'] is None
            assert m['day'] is not None


    f = '{year:4}/{month:2}/{day:2} {hour:2}:{minute:2}:{second:2}'
    f1, f2 = f.split()

    # ===
    # HMS
    # ===
    for pre in ('', 'T', 'T ', ' '):
        for t in datahms.strip().splitlines():
            t = pre+t
            m = pat.match(t)
            groups = m.groupdict()
            fdict = {k:'' if v is None else v for k,v in groups.items()}
            print(f.format(**fdict), '|', repr(t))
            check_hms(m, t)
            assert groups['year'] is None
            assert groups['month'] is None
            assert groups['day'] is None


    for post in ('', 'T', 'T ', ' T', ' :'):
        for t in dataymd.strip().splitlines():
            t = t+post
            m = pat.match(t)
            groups = m.groupdict()
            fdict = {k:'' if v is None else v for k,v in groups.items()}
            print(f.format(**fdict), '|', repr(t))
            check_yms(m, t)
            assert groups['hour'] is None
            assert groups['minute'] is None
            assert groups['second'] is None

    for pair in itertools.product(dataymd.strip().splitlines(), datahms.strip().splitlines()):
        t = ' '.join(pair).replace('T T', 'T')
        m = pat.match(t)
        groups = m.groupdict()
        fdict = {k:'' if v is None else v for k,v in groups.items()}
        fstr = f.format(**fdict)
        print(fstr, '|', repr(t))
        check_yms(m, pair[0])
        check_hms(m, pair[1])

        # the 2 halves should effectively be parsed independently.
        lstr = f1.format(
            **{k:'' if v is None else v for k,v in pat.match(pair[0]).groupdict().items()})
        rstr = f2.format(
            **{k:'' if v is None else v for k,v in pat.match(pair[1]).groupdict().items()})
        assert fstr == ' '.join([lstr, rstr])
