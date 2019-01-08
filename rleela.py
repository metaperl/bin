#!/bin/env python3

from plumbum import local

ls = local["/usr/bin/ls"]
tail = local["/usr/bin/tail"]
leela = local["/cygdrive/c/Users/Owner/AppData/Local/Programs/Leela/Leela0110.exe"]

with local.cwd('/cygdrive/c/Users/Owner/Downloads'):

    last_game = ls["-arth", local.path('.').glob('*.sgf')] | tail["-1"]
    print(last_game)

    last_sgf = last_game()
    print(f"last sgf is {last_sgf}")

    leela(last_sgf)
