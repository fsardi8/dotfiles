for f in "$HOME/.config/bash/functions.d/"*.bash; do
  [[ -r "$f" ]] && source "$f"
done
unset f
