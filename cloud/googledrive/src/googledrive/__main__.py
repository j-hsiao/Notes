import argparse
from .googledrive import py_googledrive
from . import (
    login,
    logout,
)
# TODO other commands/apis


if __name__ == '__main__':
    py_googledrive.main(__package__, __file__)
