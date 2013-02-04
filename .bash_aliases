alias na='subl -w ~/.bash_aliases && source ~/.bash_aliases'
alias z='zeus'

# Rails alias
alias r='bundle exec rails'
alias rake='bundle exec rake'
alias rs='bundle exec rake spec'
alias rcov='bundle exec rake spec COVERAGE=true && open coverage/index.html'

# Git alias
alias g='git'

# PostgreSQL start
alias pgstart='pg_ctl -D /usr/local/var/postgres -l /usr/local/var/postgres/server.log start'

# MongoDB start
alias mongostart='mongod run --config /usr/local/Cellar/mongodb/2.0.2-x86_64/mongod.conf'

# Simmetry aliases
alias sy='symmetry'
alias so='sy open'
alias sp='sy push'
alias sl='sy pull'
alias slp='sl && sp'
alias spr='sy pr'
alias sf='sy fork'
alias su='sy upstream'