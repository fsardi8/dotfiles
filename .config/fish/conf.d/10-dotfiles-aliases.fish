# Fish port of ~/.config/shell/aliases.sh (bash/zsh).
# Keep in sync manually when that file changes — fish syntax is not
# source-compatible with bash/zsh, so this can't just `source` it.

# ─────────────────────────────────────────────────────────────
# Package Management  (apt on Debian/Ubuntu, pacman on Arch)
# ─────────────────────────────────────────────────────────────
if command -v apt >/dev/null
    alias ai 'sudo apt install -y'
    alias ar 'sudo apt purge -y'
    alias au 'sudo apt update; and sudo apt full-upgrade -y; and sudo apt autoremove -y; and flatpak update -y 2>/dev/null; or true'
else if command -v pacman >/dev/null
    alias ai 'sudo pacman -S --noconfirm'
    alias ar 'sudo pacman -Rns'
    alias au 'sudo pacman -Syu; and flatpak update -y 2>/dev/null; or true'
end

function uclaude
    pushd /home/f/.local/share/claude-desktop
    bash setup.sh
    popd
end

alias flatup 'flatpak update -y'
alias flats 'flatpak search'
alias flati 'flatpak install -y'
alias flatr 'flatpak uninstall'
alias flatls 'flatpak list'

# ─────────────────────────────────────────────────────────────
# Safety & Common Shortcuts
# ─────────────────────────────────────────────────────────────
alias rm 'rm -I'
alias mv 'mv -i'
alias cp 'cp -i'
alias bc 'bc -l'
alias h 'history'
alias j 'jobs -l'
alias py 'python3'
alias c clear

# ─────────────────────────────────────────────────────────────
# System Info
# ─────────────────────────────────────────────────────────────
alias meminfo 'free -h; and echo; and head -5 /proc/meminfo'
alias cpuinfo 'lscpu | grep -E "Model name|CPU\(s\)|Thread|Core"'
alias temps 'sensors 2>/dev/null; or echo "install lm-sensors"'

# ─────────────────────────────────────────────────────────────
# Editor & Config Shortcuts
# ─────────────────────────────────────────────────────────────
set -gx EDITOR micro
alias e 'micro'
alias se 'sudo -e'
alias ealias 'micro ~/.config/fish/conf.d/10-dotfiles-aliases.fish; and source ~/.config/fish/conf.d/10-dotfiles-aliases.fish'
alias efstab 'sudo -e /etc/fstab'
function essh
    sudo -e /etc/ssh/sshd_config
    and begin
        sudo systemctl restart ssh 2>/dev/null; or sudo systemctl restart sshd
    end
end
alias enfs 'micro /etc/exports; and sudo exportfs -ra'

# ─────────────────────────────────────────────────────────────
# Media Conversion
# ─────────────────────────────────────────────────────────────
function amr2wav
    for f in *.amr
        ffmpeg -i "$f" -ar 16000 -ac 1 (string replace -r '\.amr$' '.wav' -- $f)
    end
end

# ─────────────────────────────────────────────────────────────
# Disk & Filesystem
# ─────────────────────────────────────────────────────────────
alias blkidl 'blkid -o list'
alias mntl 'mount | column -t'
alias du 'du -ch'
alias dud 'du -d 1 -h | sort -h'
alias biggest 'du -ah . 2>/dev/null | sort -rh | head -20'
alias btrl 'sudo btrfs subvol list'

# ─────────────────────────────────────────────────────────────
# Modern CLI replacements
# ─────────────────────────────────────────────────────────────
# bat: binary is 'batcat' on Debian/Ubuntu, 'bat' on Arch
set -l _bat (command -v batcat 2>/dev/null; or command -v bat 2>/dev/null)
if test -n "$_bat"
    alias bat "$_bat --paging=auto"
    alias cat "$_bat --paging=never"
    set -gx MANROFFOPT "-c"
    set -gx MANPAGER "sh -c 'col -bx | $_bat -l man -p'"
end

# fd: binary is 'fdfind' on Debian/Ubuntu, 'fd' on Arch
set -l _fd (command -v fdfind 2>/dev/null; or command -v fd 2>/dev/null)
test -n "$_fd"; and alias fd "$_fd"

alias ls 'eza --icons'
alias l 'eza --icons'
alias ll 'eza -lah --icons --git'
alias lt 'eza --tree --level=2 --icons'
alias la 'eza -a --icons'

# ─────────────────────────────────────────────────────────────
# Navigation
# ─────────────────────────────────────────────────────────────
alias etc 'cd /etc'
alias mnt 'cd /mnt'
alias bak 'cd /mnt/mrt/backups'
alias media 'cd /mnt/mrt/media'
alias tik 'cd ~/mikrotik'
alias .. 'cd ..'
alias ... 'cd ../..'
alias bin 'cd ~/.local/bin'
alias func 'cd ~/.config/shell/functions.d'

# ─────────────────────────────────────────────────────────────
# Network  (funciones → ~/.config/shell/functions.d/network.sh, bridged below)
# ─────────────────────────────────────────────────────────────
alias p 'ping -i 0.2'
alias t 'traceroute'
alias ports 'ss -tulnp'
alias syslog 'journalctl -f'
alias bootlog 'journalctl -b'

# ─────────────────────────────────────────────────────────────
# SSH Shortcuts
# ─────────────────────────────────────────────────────────────
alias p4 'ssh f@10.88.88.8'
alias p5 'ssh f@10.88.88.9'
alias od 'ssh f@10.85.85.8'
alias ofa 'ssh f@10.80.1.8'
alias ofr 'ssh f@10.48.48.88'
# `or` is a reserved fish keyword, can't be a function/alias name — use an abbreviation instead
abbr -a or 'ssh -i ~/.ssh/oracle-micro ubuntu@193.122.224.162'
alias ora 'ssh -i ~/.ssh/oracle-micro ubuntu@158.101.104.122'
alias pv 'ssh root@10.48.48.99'
alias g2 'ssh f@10.85.85.1'
alias smb 'ssh root@10.48.48.111'
alias synct 'ssh root@10.48.48.110'
alias vr 'ssh f@10.48.48.1'
alias vb 'ssh f@10.47.48.0'
alias vk 'ssh f@10.48.48.101'
alias sshkey 'ssh-copy-id -i ~/.ssh/id_ed25519.pub'

# ─────────────────────────────────────────────────────────────
# Utilities
# ─────────────────────────────────────────────────────────────
alias path 'string join \n $PATH'
alias now 'date +"%Y-%m-%d %H:%M:%S"'
alias week 'date +%V'
alias extract 'tar -xvf'
alias md 'glow'

# Claude Code aliases
alias cl 'claude --strict-mcp-config --mcp-config ~/.claude/mcp-empty.json'
alias clr 'claude --resume --strict-mcp-config --mcp-config ~/.claude/mcp-empty.json'
alias clm 'claude --strict-mcp-config --mcp-config /home/f/mikrotik/.mcp.json'
alias clmr 'claude --resume --strict-mcp-config --mcp-config /home/f/mikrotik/.mcp.json'
alias einv '~/mikrotik/.venv/bin/python3 ~/mikrotik/einv.py'
