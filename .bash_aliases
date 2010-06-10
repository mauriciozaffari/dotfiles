alias dpy='git add . && git commit -a -v && git push && cap deploy'
alias na='mate -w ~/.bash_aliases && source ~/.bash_aliases'
alias la='ls -la'

# Change to rails dir
alias crails='cd ~/Sites/rails'
alias cr='crails'

# Rails alias
alias r='rails'

# Tail rails log files
alias td='tail -f log/development.log'
alias tp='tail -f log/production.log'

# Restart passenger
alias rr='touch tmp/restart.txt'

