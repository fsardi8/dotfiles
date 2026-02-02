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

trim() {
  if (( $# )); then
    sudo fstrim -v "$@"
  else
    sudo fstrim -av
  fi
}

btl() { sudo btrfs subvolume list -t "${1:-.}"; }

btrscrub() {
  local MP="${1:-$PWD}"

  sudo bash -lc 'set -euo pipefail
MP="$1"

# Resolve to a real mountpoint (works if you pass a subdir)
if ! findmnt -T "$MP" >/dev/null 2>&1; then
  echo "ERROR: not a mountpoint or not mounted: $MP" >&2
  exit 1
fi
MP="$(findmnt -no TARGET -T "$MP")"

FSTYPE="$(findmnt -no FSTYPE -T "$MP")"
if [ "$FSTYPE" != "btrfs" ]; then
  echo "ERROR: $MP is not btrfs (fstype=$FSTYPE)" >&2
  exit 1
fi

echo "== starting scrub in background for: $MP =="
btrfs scrub start "$MP"

echo
echo "== check status =="
echo "sudo btrfs scrub status -d $MP"
echo
echo "== watch until done =="
echo "watch -n 2 sudo btrfs scrub status -d $MP"
echo
echo "== see errors / counters =="
echo "sudo btrfs device stats $MP"
echo
echo "== stop scrub if needed =="
echo "sudo btrfs scrub cancel $MP"
' bash "$MP"
}

bscrub() { sudo btrfs scrub start -Bd "${1:-/}"; }
bchk() { sudo btrfs check --readonly "${1:?usage: bchk /dev/XXX}"; }
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