# Fish bridge for ~/.config/shell/functions.d/*.sh.
# These functions are bash-specific (arrays, [[ ]], local -a, etc.) and not
# worth reimplementing in fish syntax — each one just re-execs the same
# bash function with the original args, so behavior stays identical
# across bash/zsh/fish.

function __dotfiles_bash_fn
    set -l file $argv[1]
    set -l fn $argv[2]
    bash -c 'file=$1; fn=$2; shift 2; source "$file"; "$fn" "$@"' bash "$file" "$fn" $argv[3..-1]
end

# disk.sh
for fn in disks blist bsize scrub btchk chk dedup hdspeed part trim
    function $fn --inherit-variable fn
        __dotfiles_bash_fn ~/.config/shell/functions.d/disk.sh $fn $argv
    end
end

# frsync.sh
function frsync
    __dotfiles_bash_fn ~/.config/shell/functions.d/frsync.sh frsync $argv
end

# network.sh
for fn in myip ipa dns ipscan network ipuf
    function $fn --inherit-variable fn
        __dotfiles_bash_fn ~/.config/shell/functions.d/network.sh $fn $argv
    end
end

# samba.sh
function esamba
    __dotfiles_bash_fn ~/.config/shell/functions.d/samba.sh esamba $argv
end

# tmux.sh
function mux
    __dotfiles_bash_fn ~/.config/shell/functions.d/tmux.sh mux $argv
end

# user.sh
function agroup
    __dotfiles_bash_fn ~/.config/shell/functions.d/user.sh agroup $argv
end
