# Environment variables
export EDITOR='nvim'           # Default editor
export PATH="$HOME/.local/bin:$PATH"  # Add local bin to PATH

# NPM Global
mkdir -p ~/.npm-global
npm config set prefix '~/.npm-global' 2>/dev/null
export PATH="$HOME/.npm-global/bin:$PATH"  # Add npm global bin to PATH 
