disks() {
  printf "%-12s %-12s %-36s %-8s\n" DEVICE LABEL UUID TYPE
  sudo blkid -o export | awk -F= '
    /^DEVNAME/ {dev=$2}
    /^LABEL=/  {label=$2}
    $1=="UUID" {uuid=$2}
    /^TYPE=/   {type=$2}
    /^$/ {
      if (dev!="") printf "%-12s %-12s %-36s %-8s\n", dev, label, uuid, type
      dev=label=uuid=type=""
    }
  '
  echo
  lsblk -o NAME,LABEL,SIZE,FSTYPE,MOUNTPOINTS,UUID
  echo
  df -hT
}

blist() { sudo btrfs subvolume list -t "${1:-.}"; }
bsize() { sudo btrfs filesystem du -s --human-readable "${1:-.}"; }

scrub() {
  local mp="${1:-$PWD}"

  # Resolve and validate mountpoint
  if ! findmnt -T "$mp" >/dev/null 2>&1; then
    echo "ERROR: not a mountpoint or not mounted: $mp" >&2
    return 1
  fi
  mp="$(findmnt -no TARGET -T "$mp")"

  local fstype
  fstype="$(findmnt -no FSTYPE -T "$mp")"
  if [[ "$fstype" != "btrfs" ]]; then
    echo "ERROR: $mp is not btrfs (fstype=$fstype)" >&2
    return 1
  fi

  # If a scrub is already running, show status and exit cleanly
  if sudo btrfs scrub status -d "$mp" 2>/dev/null | grep -qi "running"; then
    echo "== scrub already running =="
    sudo btrfs scrub status -d "$mp"
    return 0
  fi

  echo "== starting scrub in background =="
  echo "== filesystem: $mp =="
  sudo btrfs scrub start "$mp"
  sudo btrfs scrub status -d $mp

  echo
  echo "== check status =="
  echo "sudo btrfs scrub status -d $mp"
  echo "watch -n 5 sudo btrfs scrub status -d $mp"
}

btchk() { sudo btrfs check --readonly "${1:?usage: btchk /dev/XXX}"; }

chk() { sudo e2fsck -p -f -C 0 "$@"; }
dedup() { sudo duperemove -drh "${1:?usage: dedup /path}"; }  # duperemove

hdspeed() {
  local f
  f="$(mktemp -p "${TMPDIR:-/tmp}" hdspeed.XXXXXX)" || return 1
  dd if=/dev/zero of="$f" bs=1M count=1024 oflag=direct status=progress
  sudo sh -c 'sync; echo 3 > /proc/sys/vm/drop_caches'
  dd if="$f" of=/dev/null bs=1M iflag=direct status=progress
  rm -f "$f"
}

part() {
  [ -n "$1" ] || { echo "Usage: part <disk>"; return 1; }
  [ -b "/dev/$1" ] || { echo "No such block device: /dev/$1"; return 1; }
  sudo cfdisk "/dev/$1" && sudo partprobe "/dev/$1"
}

trim() {
  if (( $# )); then
    sudo fstrim -v "$@"
  else
    sudo fstrim -av
  fi
}
