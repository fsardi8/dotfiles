# De-duplicate PATH while preserving order
path_dedup() {
  local IFS=":" seg out=":"
  for seg in $PATH; do
    [[ -z "$seg" ]] && continue
    case "$out" in *":$seg:"*) ;; *) out="$out$seg:" ;; esac
  done
  PATH="${out#:}"; PATH="${PATH%:}"
  export PATH
}
path_dedup
