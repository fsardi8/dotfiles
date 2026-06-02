# ───────────────2026-apr-27-12:23─────────────────────────────
# Package Management
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
alias c=clear

# ─────────────────────────────────────────────────────────────
# System Info
# ─────────────────────────────────────────────────────────────
alias meminfo='free -h && echo && head -5 /proc/meminfo'
alias cpuinfo='lscpu | grep -E "Model name|CPU\(s\)|Thread|Core"'
alias temps='sensors 2>/dev/null || echo "install lm-sensors"'  # requires lm-sensors

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
alias btrl='sudo btrfs subvol list'

# ─────────────────────────────────────────────────────────────
# Navigation
# ─────────────────────────────────────────────────────────────
alias etc='cd /etc'
alias mnt='cd /mnt'
alias bak='cd /mnt/zen/backup/'
alias media='cd /mnt/zen/media'
alias tik='cd /mnt/zen/redsi/mikrotik'
alias zen='cd /mnt/zen'
alias ..='cd ..'
alias ...='cd ../..'

# ─────────────────────────────────────────────────────────────
# Network  (funciones → ~/.config/bash/functions.d/network.sh)
# ─────────────────────────────────────────────────────────────
alias p='ping -i 0.2'
alias t='traceroute'
alias ports='ss -tulnp'       # listening ports
alias syslog='journalctl -f'  # live system log
alias bootlog='journalctl -b' # current boot log

# ─────────────────────────────────────────────────────────────
# SSH Shortcuts
# ─────────────────────────────────────────────────────────────
alias p4='ssh f@10.88.88.8'
alias p5='ssh f@10.88.88.9'
alias od='ssh f@10.85.85.8'
alias ofa='ssh f@10.80.1.8'
alias ofr='ssh f@10.48.48.88'
alias or='ssh -i oracle-micro ubuntu@193.122.224.162'
alias g2='ssh f@10.85.85.1'
alias vr='ssh f@10.48.48.1'
alias vb='ssh f@10.47.48.0'
alias vk='ssh f@10.48.48.101'
alias pv='ssh root@10.48.48.99'

# ─────────────────────────────────────────────────────────────
# Utilities
# ─────────────────────────────────────────────────────────────
alias path='echo $PATH | tr ":" "\n"'    # readable PATH
alias now='date +"%Y-%m-%d %H:%M:%S"'   # current timestamp
alias week='date +%V'                    # ISO week number
alias extract='tar -xvf'                 # auto-detect archive
