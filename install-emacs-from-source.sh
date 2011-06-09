#!/bin/bash -x

# I was tired of googling for the necessary shell commands to install emacs
# from source on ubuntu, so I put them into this script.


bzr branch bzr://bzr.savannah.gnu.org/emacs/trunk
mv trunk emacs-trunk
cd emacs-trunk

sudo apt-get install automake autoconf texinfo
sudo apt-get install build-essential 
sudo apt-get build-dep emacs

./autogen.sh
./configure && make
