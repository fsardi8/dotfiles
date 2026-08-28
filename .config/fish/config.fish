source /usr/share/cachyos-fish-config/cachyos-config.fish

# overwrite greeting
# potentially disabling fastfetch
#function fish_greeting
#    # smth smth
#end
export PATH="$HOME/.local/bin:$PATH"

# fix washed-out LibreOffice theme on KDE/Wayland
set -gx SAL_USE_VCLPLUGIN qt6

### zoxide — must be last so it hooks into cd after everything else loads
zoxide init fish | source
