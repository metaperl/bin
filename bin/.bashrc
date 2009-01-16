# ~/.bashrc: executed by bash(1) for non-login shells.
# see /usr/share/doc/bash/examples/startup-files (in the package bash-doc)
# for examples

# If running interactively, then:
if [ "$PS1" ]; then

    # don't put duplicate lines in the history. See bash(1) for more options
    # export HISTCONTROL=ignoredups

    # check the window size after each command and, if necessary,
    # update the values of LINES and COLUMNS.
    #shopt -s checkwinsize


    # some more ls aliases
    #alias ll='ls -l'
    #alias la='ls -A'
    #alias l='ls -CF'

    # set a fancy prompt
    PS1='\u@\h:\w\$ '

    # If this is an xterm set the title to user@host:dir
    #case $TERM in
    #xterm*)
    #    PROMPT_COMMAND='echo -ne "\033]0;${USER}@${HOSTNAME}: ${PWD}\007"'
    #    ;;
    #*)
    #    ;;
    #esac

    # enable programmable completion features (you don't need to enable
    # this, if it's already enabled in /etc/bash.bashrc).
    #if [ -f /etc/bash_completion ]; then
    #  . /etc/bash_completion
    #fi
fi

export EDITOR=xemacs

alias meta='xemacs ~/public_html/metaperl.com'
alias gopugs='xemacs ~/haskell/pugs/pugs'
alias gnus='xemacs -f gnus'
alias gimble='xemacs -f gimble'
alias live='xemacs ~/public_html/livingcosmos.org'
alias smlx="xemacs ~/public_html/livingcosmos.org/sml/harper-sml/excs.sml"
alias alz='xemacs ~/perl/hax/Alzabo-Playground/scripts'




export BIVIO=~/perl/dl/Bivio-bOP-2.49/
export GIMBLE=$HOME/public_html/gimblerus.com
export GIMBLE_SRC=$GIMBLE/src/perl
export BCONF=$GIMBLE/bconf/gimble.bconf
#export BCONF=$BIVIO/petshop.bconf

# set PATH so it includes user's private bin if it exists
if [ -d ~/bin ] ; then
    PATH=~/bin:"${PATH}"
fi

export DBI_CONF=/home/terry/.dbi.conf

export PERL5LIB=~/install/lib:~/install/share/perl/perlver

PATH=~/bin/asciidoc-7.0.0:$PATH

export SVN_SSH='ssh -l metaperl'

# 

ulimit -Sv 500000
ulimit -Su 50

# CVS

cvs_developer=metaperl
cvs_project=seamstress

export CVSROOT_SEAMSTRESS=:ext:$cvs_developer@cvs.sourceforge.net:/cvsroot/$cvs_project

cvs_project=cgi-prototype
export CVSROOT_CGIP=:ext:$cvs_developer@cvs.sourceforge.net:/cvsroot/$cvs_project

#
export PREFIX=$HOME/install

#
export FORREST_HOME=$HOME/domains/org/livingcosmos/dev/apache-forrest
export PATH=$PATH:$FORREST_HOME/bin

# 

export PATH=$PREFIX/bin:$PATH
export PATH=$PREFIX/zopehome/bin:$PATH
export PATH=$PREFIX/asciidoc:$PATH

#

export PYTHONPATH=$HOME/lib/python:$PYTHONPATH