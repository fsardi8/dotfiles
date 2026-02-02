for f in "$HOME/.config/bash/functions.d/"*.sh; do
  [[ -r "$f" ]] && source "$f"
done
unset f
