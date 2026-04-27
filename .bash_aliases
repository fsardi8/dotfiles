# ─────────────────────────────────────────────────────────────
# Package Management-change
# ─────────────────────────────────────────────────────────────
alias ai='sudo apt install -y'
alias ar='sudo apt purge -y'
alias au='sudo apt update && sudo apt full-upgrade -y && sudo apt autoremove -y && flatpak update -y'  # update all
alias flatup='flatpak update -y'
alias flats='flatpak search'
alias flati='flatpak install -y'
alias flatr='flatpak uninstall'
alias flatls='flatpak list'

# ─────────────────────────────────────────────────────────────
# Safety & Common Shortcuts
# ─────────────────────────────────────────────────────────────
alias rm='rm -I'   # prompt if >3 files
alias mv='mv -i'   # prompt before overwrite
alias cp='cp -i'   # prompt before overwrite
alias bc='bc -l'
alias h='history'
alias j='jobs -l'
alias py='python3'
alias cls=clear

# ─────────────────────────────────────────────────────────────
# System Info
# ─────────────────────────────────────────────────────────────
alias meminfo='free -h && echo && head -5 /proc/meminfo'
alias cpuinfo='lscpu | grep -E "Model name|CPU\(s\)|Thread|Core"'
alias temps='sensors 2>/dev/null || echo "install lm-sensors"'  # requires lm-sensors

# ─────────────────────────────────────────────────────────────
# User & Group Management
# ─────────────────────────────────────────────────────────────
agroup() { sudo usermod -aG "$1" "${2:-$USER}"; }

# ─────────────────────────────────────────────────────────────
# File Sync & Tmux
# ─────────────────────────────────────────────────────────────

# ─────────────────────────────────────────────────────────────
# Editor & Config Shortcuts
# ─────────────────────────────────────────────────────────────
export EDITOR=micro
alias e='micro'
alias se='sudo -e'
alias ealias='micro ~/.bash_aliases && source ~/.bash_aliases'
alias efstab='sudo -e /etc/fstab'
alias essh='sudo -e /etc/ssh/sshd_config && sudo systemctl restart ssh'
alias enfs='micro /etc/exports && sudo exportfs -ra'
esamba() {
  sudo -e /etc/samba/smb.conf || return
  sudo systemctl restart smbd 2>/dev/null || sudo systemctl restart samba 2>/dev/null
  sudo systemctl restart nmbd 2>/dev/null || true
}

# ─────────────────────────────────────────────────────────────
# Media Conversion
# ─────────────────────────────────────────────────────────────
alias amr2wav='for f in *.amr; do ffmpeg -i "$f" -ar 16000 -ac 1 "${f%.amr}.wav"; done'

# ─────────────────────────────────────────────────────────────
# Disk & Filesystem
# ─────────────────────────────────────────────────────────────
alias blkidl='blkid -o list'
alias mntl='mount | column -t'
alias du='du -ch'
alias dud='du -d 1 -h | sort -h'              # sorted dir sizes
alias biggest='du -ah . 2>/dev/null | sort -rh | head -20'  # top 20 largest

# ─────────────────────────────────────────────────────────────
# Navigation
# ─────────────────────────────────────────────────────────────
alias etc='cd /etc'
alias mnt='cd /mnt'
alias bak='cd /mnt/zen/backup/mikrotik'
alias media='cd /mnt/zen/media'
alias zen='cd /mnt/zen'
alias ..='cd ..'
alias ...='cd ../..'

# ─────────────────────────────────────────────────────────────
# Network
# ─────────────────────────────────────────────────────────────
alias p='ping -i 0.2'
alias t='traceroute'
alias ports='ss -tulnp'       # listening ports
alias syslog='journalctl -f'  # live system log
alias bootlog='journalctl -b' # current boot log

myip() { curl -4fsS --max-time 5 https://api.ipify.org && echo; }

ipa() {
  ip -br -c a
  echo "public:       $(myip 2>/dev/null || echo "?")"
}

dns() {
  command -v resolvectl >/dev/null && resolvectl status
  if command -v nmcli >/dev/null; then
    nmcli device show | grep -E 'IP4\.DNS|IP4\.ADDRESS|GENERAL\.DEVICE'
  else
    echo "nmcli not found; showing /etc/resolv.conf:"
    sed -n '1,120p' /etc/resolv.conf
  fi
}

ipscan() { sudo arp-scan --localnet; }   # Likely command is arp-scan on Ubuntu/Proxmox

network() {
  if command -v nmtui >/dev/null; then
    sudo nmtui
  else
    echo "nmtui not installed (common on Proxmox)."
    echo "Tip: edit netplan or /etc/network/interfaces depending on the host."
  fi
}

ipuf() {
  local env="$HOME/.config/cf-ddns.env"
  [[ -r "$env" ]] || { echo "Missing $env (see comments in ~/.bash_aliases)"; return 1; }
  source "$env"

  : "${CF_ZONE_ID:?Missing CF_ZONE_ID}" "${CF_API_TOKEN:?Missing CF_API_TOKEN}" "${CF_RECORD_NAME:?Missing CF_RECORD_NAME}"
  command -v jq >/dev/null || { echo "jq is required: sudo apt install -y jq"; return 1; }

  local ip rid
  ip="$(myip)" || return 1

  rid="$(curl -fsS --max-time 10 \
    -X GET "https://api.cloudflare.com/client/v4/zones/$CF_ZONE_ID/dns_records?type=A&name=$CF_RECORD_NAME" \
    -H "Authorization: Bearer $CF_API_TOKEN" -H "Content-Type: application/json" \
    | jq -r '.result[0].id')" || return 1

  [[ -n "$rid" && "$rid" != "null" ]] || { echo "DNS record not found for $CF_RECORD_NAME"; return 1; }

  curl -fsS --max-time 10 \
    -X PUT "https://api.cloudflare.com/client/v4/zones/$CF_ZONE_ID/dns_records/$rid" \
    -H "Authorization: Bearer $CF_API_TOKEN" -H "Content-Type: application/json" \
    --data "{\"type\":\"A\",\"name\":\"$CF_RECORD_NAME\",\"content\":\"$ip\",\"ttl\":120,\"proxied\":false}" | jq .
}

# ─────────────────────────────────────────────────────────────
# SSH Shortcuts
# ─────────────────────────────────────────────────────────────
alias p4='ssh f@10.88.88.8'
alias p5='ssh f@10.88.88.9'
alias od='ssh f@10.85.85.8'
alias ofa='ssh f@10.80.1.8'
alias ofr='ssh f@10.48.48.88'
alias g2='ssh f@10.85.85.1'
alias vr='ssh f@10.48.48.1'
alias vb='ssh f@10.47.48.0'

# ─────────────────────────────────────────────────────────────
# Utilities
# ─────────────────────────────────────────────────────────────
alias path='echo $PATH | tr ":" "\n"'    # readable PATH
alias now='date +"%Y-%m-%d %H:%M:%S"'   # current timestamp
alias week='date +%V'                    # ISO week number
alias extract='tar -xvf'                 # auto-detect archive
