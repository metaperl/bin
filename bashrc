export PATH=$HOME/bin:/usr/local/bin:$PATH

export VERSIONER_PYTHON_PREFER_32_BIT=yes


# ~/.bashrc: executed by bash(1) for non-login shells.
# see /usr/share/doc/bash/examples/startup-files (in the package bash-doc)
# for examples

# If not running interactively, don't do anything
[ -z "$PS1" ] && return

# don't put duplicate lines in the history. See bash(1) for more options
# export HISTCONTROL=ignoredups

# check the window size after each command and, if necessary,
# update the values of LINES and COLUMNS.
shopt -s checkwinsize

# make less more friendly for non-text input files, see lesspipe(1)
[ -x /usr/bin/lesspipe ] && eval "$(lesspipe)"

# the prompt information
export PS1="[\w]\$ "

# leave some commands out of history log
export HISTIGNORE="&:??:[ ]*:clear:exit:logout"

# default editor
export EDITOR=emacs

# define color to additional file types
export LS_COLORS=$LS_COLORS:"*.wmv=01;35":"*.wma=01;35":"*.flv=01;35":"*.m4a=01;35"


# Alias definitions.


# user-defined aliases
alias rm='rm -vi'
alias cp='cp -vi'
alias mv='mv -vi'
alias clean='rm -f "#"* "."*~ *~ *.bak *.dvi *.aux *.log'
alias nano='nano -w'
alias psi='ps h -eo pmem,comm | sort -nr | head'
alias _sb='source ~/.bashrc'

# enable programmable completion features (you don't need to enable
# this, if it's already enabled in /etc/bash.bashrc and /etc/profile
# sources /etc/bash.bashrc).
if [ -f /etc/bash_completion ]; then
    . /etc/bash_completion
fi

#PATH=/usr/local/share/python:$PATH
#PATH=/usr/local/opt/python/bin:$PATH

PATH=/Applications/Postgres.app/Contents/MacOS/bin:$PATH
export ARCHFLAGS="-arch i386 -arch x86_64"

#alias multibit='ssh -X schemelab@li2-168.members.linode.com "cd exe/multibit-0.5.15; java -jar multibit-exe.jar"'
alias multibit='ssh -X schemelab@li2-168.members.linode.com "cd exe/MultiBit-0.5.16; java -jar multibit-exe.jar"'

export PATH=/usr/local/smlnj/bin:$PATH
export PATH=~/Documents/Programming/scala/scala/bin:$PATH
#alias emacs=/usr/local/Cellar/emacs/HEAD/Emacs.app/Contents/MacOS/Emacs
alias emacs=/Applications/Emacs.app/Contents/MacOS/Emacs

export VPS_SERVER=li2-168.members.linode.com

export PATH=~/bin:$PATH
