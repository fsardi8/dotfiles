frsync() {
  # See $_frsync_usage below (printed with no args) for full usage, including
  # remote SSH examples and --exclude/--exclude-from (no default excludes).

  local mirror=0 dry=0 update=0 csum=0
  local prune=0 fast=0 no_default_excludes=0
  local -a excludes=()
  local -a default_excludes=( .git .venv venv __pycache__ '*.pyc' node_modules .DS_Store )

  local _frsync_usage="Usage: frsync [--mirror] [--dryrun] [--update] [--checksum] [--exclude=PATTERN ...] [--exclude-from=FILE] [--no-default-excludes] [--prune [--fast]] SRC/ DEST/

Local:
  frsync SRC/ DEST/                                 # clone (no delete), source wins
  frsync --mirror SRC/ DEST/                        # mirror (WITH delete)
  frsync --dryrun SRC/ DEST/                        # preview
  frsync --update SRC/ DEST/                        # do NOT overwrite newer files on DEST
  frsync --checksum SRC/ DEST/                      # compare by checksum, not size/mtime

Excludes:
  Default excludes (always on unless disabled): ${default_excludes[*]}
  frsync --exclude=dist SRC/ DEST/                  # add more; repeatable; rsync pattern, relative to SRC root
  frsync --exclude=dist --exclude=build SRC/ DEST/
  frsync --exclude dist SRC/ DEST/                  # space form also works
  frsync --exclude-from=.rsyncignore SRC/ DEST/     # FILE has one rsync pattern per line
  frsync --no-default-excludes SRC/ DEST/           # disable the defaults, sync everything

Remote (SSH, either side may be user@host:/path/):
  frsync SRC/ user@host:DEST/                       # push local -> remote
  frsync user@host:SRC/ DEST/                       # pull remote -> local
  frsync --dryrun --mirror SRC/ user@host:DEST/     # preview a remote mirror push
  frsync --update SRC/ user@host:DEST/              # push, skip newer files on remote DEST

Prune (local only, both SRC and DEST must be local paths):
  frsync --prune SRC/ DEST/                         # APPLY: delete from SRC files already in DEST (same rel path + same content)
  frsync --prune --dryrun SRC/ DEST/                # DRY-RUN prune
  frsync --prune --fast SRC/ DEST/                  # FAST: quick-hash (first+last 4MiB) instead of full cmp

Notes:
  - Trailing slashes mean \"copy contents of SRC into DEST\".
  - --prune never touches DEST; it only removes proven-duplicate files from SRC.
  - Remote transfers run as your user via sudo -E (SSH agent/keys preserved); --prune refuses remote paths.
  - --exclude/--exclude-from are passed straight to rsync's --exclude/--exclude-from (not supported in --prune mode)."

  if [[ $# -eq 0 ]]; then
    echo "$_frsync_usage" >&2
    return 2
  fi

  local _frsync_is_remote
  _frsync_is_remote() {
    [[ "$1" == rsync://* ]] && return 0
    [[ "$1" =~ ^([A-Za-z0-9._%+-]+@)?[A-Za-z0-9.-]+:.+ ]]
  }

  while [[ $# -gt 0 ]]; do
    case "$1" in
      -m|--mirror)   mirror=1; shift ;;
      -n|--dryrun)   dry=1; shift ;;
      -u|--update)   update=1; shift ;;
      -c|--checksum) csum=1; shift ;;

      --prune)       prune=1; shift ;;
      --fast)        fast=1; shift ;;

      --exclude=*)      excludes+=( "--exclude=${1#--exclude=}" ); shift ;;
      --exclude)        [[ $# -ge 2 ]] || { echo "frsync: --exclude requires a PATTERN" >&2; return 2; }
                         excludes+=( "--exclude=$2" ); shift 2 ;;
      --exclude-from=*) excludes+=( "--exclude-from=${1#--exclude-from=}" ); shift ;;
      --exclude-from)   [[ $# -ge 2 ]] || { echo "frsync: --exclude-from requires a FILE" >&2; return 2; }
                         excludes+=( "--exclude-from=$2" ); shift 2 ;;
      --no-default-excludes) no_default_excludes=1; shift ;;

      --) shift; break ;;
      -*) echo "frsync: unknown option: $1" >&2; return 2 ;;
      *) break ;;
    esac
  done

  if [[ $# -ne 2 ]]; then
    echo "$_frsync_usage" >&2
    return 2
  fi

  local src="$1"
  local dst="$2"

  local src_remote=0 dst_remote=0
  _frsync_is_remote "$src" && src_remote=1
  _frsync_is_remote "$dst" && dst_remote=1

  if [[ $src_remote -eq 0 && ! -e "$src" ]]; then
    echo "frsync: source not found: $src" >&2
    return 1
  fi
  if [[ $dst_remote -eq 0 && ! -d "$dst" ]]; then
    echo "frsync: destination is not a directory (or missing): $dst" >&2
    echo "       Create it first: sudo mkdir -p \"$dst\"" >&2
    return 1
  fi

  # ---- PRUNE MODE ----
  if [[ $prune -eq 1 ]]; then
    if [[ $src_remote -eq 1 || $dst_remote -eq 1 ]]; then
      echo "frsync --prune: SRC and DEST must both be local paths (no ssh)." >&2
      return 2
    fi
    if (( ${#excludes[@]} )); then
      echo "frsync --prune: --exclude/--exclude-from are not supported in prune mode." >&2
      return 2
    fi
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

  if [[ $no_default_excludes -eq 0 ]]; then
    local pat
    for pat in "${default_excludes[@]}"; do
      args+=( "--exclude=$pat" )
    done
  fi
  (( ${#excludes[@]} )) && args+=( "${excludes[@]}" )

  if [[ $mirror -eq 1 && $update -eq 1 ]]; then
    echo "frsync: refuse: --mirror with --update is a foot-gun (deletes + skips overwrites)." >&2
    return 2
  fi

  echo "sudo -E rsync ${args[*]} \"$src\" \"$dst\""
  sudo -E rsync "${args[@]}" "$src" "$dst"
}