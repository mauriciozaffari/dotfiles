alias dpy='git add . && git commit -a -v && git push && cap deploy'
alias na='mate -w ~/.bash_aliases && source ~/.bash_aliases'
alias la='ls -la'
alias l='ls -aFhlG'
alias ll='ls -l'
alias ..='cd ..'
alias ...='cd ../..'
function -() { cd -; }
alias c='clear'
alias p='pwd'
alias m='mate .'

# Change to home dir
alias ch='cd ~'

# Change to rails dir
alias crails='cd ~/Sites/rails'
alias cr='crails'

# Change to github dir
alias cgithub='cd ~/Github'
alias cg='cgithub'

# Rails alias
alias r='rails'
alias rs='rake spec'

# Git alias
alias g='git'

# Tail rails log files
alias td='tail -f log/development.log'
alias tp='tail -f log/production.log'

# Restart passenger
alias rr='touch tmp/restart.txt'

