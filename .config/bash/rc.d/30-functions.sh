# Load bash function libraries
shopt -s nullglob
for f in "$HOME/.config/bash/functions.d/"*.sh "$HOME/.config/bash/functions.d/"*.bash; do
  source "$f"
done
shopt -u nullglob
unset f
