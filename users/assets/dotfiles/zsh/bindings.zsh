# Key bindings
bindkey -e                    # Emacs key bindings
bindkey '^ ' autosuggest-accept                # Ctrl+Space to accept suggestion
bindkey '^]' autosuggest-execute               # Ctrl+] to accept and execute

# Sudo shortcuts (press ESC twice to add sudo to current command)
bindkey "\e\e" sudo-command-line

# Directory navigation
setopt AUTO_CD                # Type directory name to cd
setopt AUTO_PUSHD            # Push directories onto stack
setopt PUSHD_IGNORE_DUPS     # Don't push duplicates

# fzf keybindings (if fzf is installed):
# Ctrl+T - Fuzzy file finder
# Ctrl+R - Fuzzy history search
# Alt+C  - Fuzzy directory finder
# Ctrl+G - Fuzzy zoxide directory jump (custom) 
