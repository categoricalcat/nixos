#!/usr/bin/env zsh

if command -v atuin >/dev/null 2>&1; then
    vecho "setting atuin..."
    eval "$(atuin init zsh)"
fi

if command -v mcfly >/dev/null 2>&1; then
    vecho "setting mcfly..."
    eval "$(mcfly init zsh)"
fi

if command -v broot >/dev/null 2>&1; then
    vecho "setting broot..."
    eval "$(broot --print-shell-function zsh)"
fi

if command -v yazi >/dev/null 2>&1; then
    vecho "setting yazi..."
    function yy() {
        local tmp="$(mktemp -t "yazi-cwd.XXXXXX")"
        yazi "$@" --cwd-file="$tmp"
        if cwd="$(cat -- "$tmp")" && [ -n "$cwd" ] && [ "$cwd" != "$PWD" ]; then
            builtin cd -- "$cwd"
        fi
        rm -f -- "$tmp"
    }
fi

if command -v fzf >/dev/null 2>&1; then
    vecho "setting fzf..."
    export FZF_DEFAULT_OPTS='--height 40% --layout=reverse --border'
    if command -v fd >/dev/null 2>&1; then
        export FZF_DEFAULT_COMMAND='fd --type f'
    fi
fi

if command -v zoxide >/dev/null 2>&1; then
    vecho "setting zoxide..."
    eval "$(zoxide init zsh)"
fi

if command -v direnv >/dev/null 2>&1; then
    vecho "setting direnv..."
    eval "$(direnv hook zsh)"
fi

if command -v starship >/dev/null 2>&1; then
    vecho "setting starship..."
    eval "$(starship init zsh)"
fi
