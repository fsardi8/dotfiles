#!/usr/bin/env bash
set -euo pipefail

SUBVOL="/mnt/zen"
SNAP_DIR="/mnt/zen/.snapshots"   # dentro del mismo fs btrfs de zen
REMOTE="f@pi5"
REMOTE_DIR="/srv/backup/FSC/zen"
SNAP_NAME="$(date +%Y-%m-%d_%H:%M:%S)"
SNAP_PATH="$SNAP_DIR/$SNAP_NAME"

sudo mkdir -p "$SNAP_DIR"

# Snapshot readonly local
sudo btrfs subvolume snapshot -r "$SUBVOL" "$SNAP_PATH"
echo "Snapshot local: $SNAP_PATH"

# Parent para incremental (penúltimo snapshot)
PREV=$(sudo btrfs subvolume list -s "$SNAP_DIR" 2>/dev/null \
  | awk '{print $NF}' | sort | tail -2 | head -1 | xargs -I{} basename {})

PREV_PATH="$SNAP_DIR/$PREV"

# Enviar a pi5
if [[ -n "$PREV" && "$PREV" != "$SNAP_NAME" && -d "$PREV_PATH" ]]; then
  echo "Incremental send, parent: $PREV"
  sudo btrfs send -p "$PREV_PATH" "$SNAP_PATH" \
    | ssh "$REMOTE" "sudo btrfs receive '$REMOTE_DIR'"
else
  echo "Full send (sin parent previo)"
  sudo btrfs send "$SNAP_PATH" \
    | ssh "$REMOTE" "sudo btrfs receive '$REMOTE_DIR'"
fi

# Symlink current
ssh "$REMOTE" "ln -sfn '$REMOTE_DIR/$SNAP_NAME' '$REMOTE_DIR/current'"
echo "Done → $REMOTE:$REMOTE_DIR/$SNAP_NAME"

# Rotación local: keepar últimos 7 snapshots
sudo btrfs subvolume list -s "$SNAP_DIR" \
  | awk '{print $NF}' | sort | head -n -7 \
  | xargs -I{} sudo btrfs subvolume delete "$SNAP_DIR/{}" 2>/dev/null || true

# Rotación remota: keepar últimos 30
ssh "$REMOTE" "sudo btrfs subvolume list '$REMOTE_DIR' 2>/dev/null \
  | awk '{print \$NF}' | grep -E '[0-9]{4}-[0-9]{2}' | sort | head -n -30 \
  | xargs -I{} sudo btrfs subvolume delete '$REMOTE_DIR/{}'" 2>/dev/null || true
