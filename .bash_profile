#!/bin/bash
#example ~/.bash_profile file
/usr/bin/keychain ~/.ssh/id_rsa
#redirect ~/.ssh-agent output to /dev/null to zap the annoying
#"Agent PID" message
source ~/.keychain/andLinux-sh > /dev/null

source ~/.bashrc
