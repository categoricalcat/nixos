# Additional completion settings
autoload -Uz compinit
compinit
zstyle ':completion:*' completer _complete _ignored  # Include ignored files
zstyle ':completion:*' menu select  # Interactive completion menu

# Autosuggest settings
ZSH_AUTOSUGGEST_HIGHLIGHT_STYLE="fg=#666666"  # Gray color for suggestions
ZSH_AUTOSUGGEST_STRATEGY=(history completion)  # Use both history and completion
ZSH_AUTOSUGGEST_BUFFER_MAX_SIZE=20            # Max size of buffer to trigger suggestions 
