# ~/.bashrc: executed by bash(1) for non-login shells.
# see /usr/share/doc/bash/examples/startup-files (in the package bash-doc)
# for examples

# If not running interactively, don't do anything
[ -z "$PS1" ] && return

# don't put duplicate lines in the history. See bash(1) for more options
export HISTCONTROL=ignoredups
# ... and ignore same sucessive entries.
export HISTCONTROL=ignoreboth

# check the window size after each command and, if necessary,
# update the values of LINES and COLUMNS.
shopt -s checkwinsize

# make less more friendly for non-text input files, see lesspipe(1)
[ -x /usr/bin/lesspipe ] && eval "$(lesspipe)"

parse_git_branch() {
  git_branch=`git branch 2> /dev/null | sed -e '/^[^*]/d' -e 's/* \(.*\)/\1/'`
  if [ $git_branch ]; then
    echo "$git_branch, "
  fi
}

dns() {
  dig soa $1 | grep -q ^$1 &&
  echo "Registered" ||
  echo "Available"
}

delete_branch() {
  git push origin :$1 && git branch -D $1
}

gp() {
  current_branch=`git branch | grep \* | awk '{print $2}'`
  git push origin $current_branch $1
}

cr() {
  cd "/Users/$(whoami)/Development/rails/$1"
}

_cr()
{
  _filedir '/Users/$(whoami)/Development/rails/'
}
complete -o default -o nospace -F _cr cr

export AUTOFEATURE=true

# Comment in the above and uncomment this below for a color prompt
PS1=''

# set a fancy prompt (non-color, unless we know we "want" color)
case "$TERM" in
xterm-color|screen|xterm-256color)
    PS1='\[\033[0;32m\]\u@\h\[\033[00m\]:\[\033[0;94m\]\w\[\033[1;91m\] [$(parse_git_branch)$(ruby -e "print RUBY_VERSION")]\[\033[00m\]\$ '
    ;;
*)
    PS1='\u@\h:\w $(parse_git_branch)\$ '
    ;;
esac

# If this is an xterm set the title to user@host:dir
case "$TERM" in
xterm*|rxvt*|screen*)
    PROMPT_COMMAND='echo -ne "\033]0;${USER}@${HOSTNAME}: ${PWD/$HOME/~}\007"'
    ;;
*)
    ;;
esac

# Alias definitions.
# You may want to put all your additions into a separate file like
# ~/.bash_aliases, instead of adding them here directly.
# See /usr/share/doc/bash-doc/examples in the bash-doc package.

if [ -f ~/.bash_aliases ]; then
    . ~/.bash_aliases
fi

# enable programmable completion features (you don't need to enable
# this, if it's already enabled in /etc/bash.bashrc and /etc/profile
# sources /etc/bash.bashrc).
if [ -f /etc/bash_completion ]; then
    . /etc/bash_completion
fi

if [ -f ~/.git-completion.bash ]; then
    . ~/.git-completion.bash
fi

# History tweaks
export HISTCONTROL=erasedups
export HISTSIZE=10000
shopt -s histappend

export IGNOREPING=true
export ARCHFLAGS="-arch x86_64"
export EDITOR="subl"
export PATH="/usr/local/bin:/usr/local/sbin:/usr/bin:/bin:/usr/sbin:/sbin:/usr/local/git/bin:/usr/X11/bin"
export RUBY_GC_MALLOC_LIMIT=60000000
export RUBY_FREE_MIN=200000
export CFLAGS="-march=nocona -O2 -pipe -fomit-frame-pointer"

### Added by the Heroku Toolbelt
export PATH="/usr/local/heroku/bin:$PATH"

eval "$(rbenv init -)"