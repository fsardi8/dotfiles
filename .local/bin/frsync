frsync() {
  # Usage:
  #   frsync SRC/ DEST/                         # clone (no delete), source wins
  #   frsync --mirror SRC/ DEST/                # mirror (WITH delete)
  #   frsync --dryrun SRC/ DEST/                # preview
  #   frsync --update SRC/ DEST/                # do NOT overwrite newer files on DEST
  #
  #   frsync --prune SRC/ DEST/                 # APPLY: delete from SRC files already in DEST (same rel path + same content)
  #   frsync --prune --dryrun SRC/ DEST/        # DRY-RUN prune
  #   frsync --prune --fast SRC/ DEST/          # FAST: quick-hash (first+last 4MiB) instead of full cmp
  #
  # Notes:
  # - Trailing slashes mean "copy contents of SRC into DEST".
  # - --prune never touches DEST; it only removes proven-duplicate files from SRC.

  local mirror=0 dry=0 update=0 csum=0
  local prune=0 fast=0

  while [[ $# -gt 0 ]]; do
    case "$1" in
      -m|--mirror)   mirror=1; shift ;;
      -n|--dryrun)   dry=1; shift ;;
      -u|--update)   update=1; shift ;;
      -c|--checksum) csum=1; shift ;;

      --prune)       prune=1; shift ;;
      --fast)        fast=1; shift ;;

      --) shift; break ;;
      -*) echo "frsync: unknown option: $1" >&2; return 2 ;;
      *) break ;;
    esac
  done

  if [[ $# -ne 2 ]]; then
    echo "Usage: frsync [--mirror] [--dryrun] [--update] [--checksum] [--prune [--fast]] SRC/ DEST/" >&2
    return 2
  fi

  local src="$1"
  local dst="$2"

  if [[ ! -e "$src" ]]; then
    echo "frsync: source not found: $src" >&2
    return 1
  fi
  if [[ ! -d "$dst" ]]; then
    echo "frsync: destination is not a directory (or missing): $dst" >&2
    echo "       Create it first: sudo mkdir -p \"$dst\"" >&2
    return 1
  fi

  # ---- PRUNE MODE ----
  if [[ $prune -eq 1 ]]; then
    # basic sanity
    [[ -d "$src" ]] || { echo "frsync --prune: SRC must be a directory: $src" >&2; return 1; }
    local src_root="${src%/}"
    local dst_root="${dst%/}"

    echo "== frsync --prune =="
    echo "SRC : $src_root"
    echo "DEST: $dst_root"
    echo "mode: $([[ $dry -eq 1 ]] && echo DRY-RUN || echo APPLY)"
    echo "fast: $([[ $fast -eq 1 ]] && echo yes || echo no)"
    echo

    # Export roots for xargs workers
    export SRC_ROOT="$src_root" DST_ROOT="$dst_root" DRY="$dry" FAST="$fast" CHUNK=4194304

    # For each file in SRC, if same rel path exists in DEST and is identical:
    # - dry-run: print WOULD DELETE
    # - apply : rm it
    #
    # Uses size precheck to avoid cmp for obvious mismatches.
    cd "$src_root" || return 1

    find . -type f -print0 | \
      xargs -0 -n 1 bash -lc '
        f="$1"
        s="$SRC_ROOT/${f#./}"
        d="$DST_ROOT/${f#./}"

        [[ -f "$d" ]] || exit 0

        ss=$(stat -c %s "$s" 2>/dev/null) || exit 0
        ds=$(stat -c %s "$d" 2>/dev/null) || exit 0
        [[ "$ss" == "$ds" ]] || exit 0

        if [[ "$FAST" == "1" ]]; then
          qhash() {
            f="$1"
            size="$2"
            if (( size <= 2*CHUNK )); then
              sha256sum "$f" 2>/dev/null | awk "{print \$1}"
            else
              { head -c "$CHUNK" "$f"; tail -c "$CHUNK" "$f"; } | sha256sum 2>/dev/null | awk "{print \$1}"
            fi
          }

          hs=$(qhash "$s" "$ss") || exit 0
          hd=$(qhash "$d" "$ds") || exit 0
          [[ "$hs" == "$hd" ]] || exit 0

          if [[ "$DRY" == "1" ]]; then
            printf "WOULD DELETE %s\n" "${f#./}"
          else
            rm -f -- "$s" && printf "DELETED %s\n" "${f#./}"
          fi
        else
          if cmp -s "$s" "$d"; then
            if [[ "$DRY" == "1" ]]; then
              printf "WOULD DELETE %s\n" "${f#./}"
            else
              rm -f -- "$s" && printf "DELETED %s\n" "${f#./}"
            fi
          fi
        fi
      ' _

    if [[ $dry -eq 0 ]]; then
      echo
      echo "Removing empty directories..."
      find "$src_root" -mindepth 1 -type d -empty -print -delete
    fi

    return 0
  fi

  # ---- RSYNC MODE (normal) ----
  local -a args
  args=( -HaAX --numeric-ids --info=progress2,name1 --partial --protect-args )

  [[ $dry   -eq 1 ]] && args+=( --dry-run )
  [[ $mirror -eq 1 ]] && args+=( --delete )
  [[ $update -eq 1 ]] && args+=( --update )
  [[ $csum  -eq 1 ]] && args+=( --checksum )

  if [[ $mirror -eq 1 && $update -eq 1 ]]; then
    echo "frsync: refuse: --mirror with --update is a foot-gun (deletes + skips overwrites)." >&2
    return 2
  fi

  echo "sudo rsync ${args[*]} \"$src\" \"$dst\""
  sudo rsync "${args[@]}" "$src" "$dst"
}