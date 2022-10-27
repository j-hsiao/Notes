import cProfile, pstats
# import pyximport
# pyximport.install(setup_args={"script_args":["--compiler=mingw32"]})
import calc_pi

cProfile.runctx("calc_pi.approx_pi()", globals(), locals(), "Profile.prof")
s = pstats.Stats("Profile.prof")
s.strip_dirs().sort_stats("time").print_stats()
