for f in "$HOME/.config/shell/functions.d/"*.sh; do
  [[ -r "$f" ]] && source "$f"
done
unset f
