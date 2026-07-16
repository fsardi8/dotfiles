source /usr/share/cachyos-zsh-config/cachyos-config.zsh

# Load modular shell config (shared with bash) — after cachyos-config.zsh
# so our aliases/functions win over its defaults (e.g. its own `l` alias).
for f in "$HOME/.config/shell/rc.d/"*.sh; do
  [[ -r "$f" ]] && source "$f"
done
unset f

### zoxide — must be last so it hooks into cd after everything else loads
eval "$(zoxide init zsh)"
