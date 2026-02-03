esamba() {
  sudo -e /etc/samba/smb.conf || return
  sudo systemctl restart smbd 2>/dev/null || sudo systemctl restart samba 2>/dev/null
  sudo systemctl restart nmbd 2>/dev/null || true
}