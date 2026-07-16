mux() {
  local name="${1:-fs}"
  if tmux has-session -t "$name" 2>/dev/null; then
    echo "👓 Attaching to session: $name"
    tmux attach -t "$name"
  else
    echo "🎩 Creating new session: $name"
    tmux new -s "$name"
  fi
}