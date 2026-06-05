#!/usr/bin/env bash
# fsardi8/dotfiles — bootstrap (runs ON the new machine)
#
# PREFERRED:  dot bootstrap user@newhost   (from your main machine — no token needed)
# FALLBACK:   if you're already on the new machine with SSH key copied:
#               bash <(curl -fsSL https://raw.githubusercontent.com/fsardi8/dotfiles/master/install.sh)
set -euo pipefail

DOTFILES_REPO="https://github.com/fsardi8/dotfiles.git"
DOTFILES_REPO_SSH="git@github.com:fsardi8/dotfiles.git"
GPG_KEY_ID="A28F843C63852BF6"

# ── colores ────────────────────────────────────────────────────────────────────
RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'
BLUE='\033[0;34m'; BOLD='\033[1m'; NC='\033[0m'

ok()   { echo -e "${GREEN}✔${NC}  $*"; }
info() { echo -e "${BLUE}→${NC}  $*"; }
warn() { echo -e "${YELLOW}⚠${NC}  $*"; }
die()  { echo -e "${RED}✖${NC}  $*" >&2; exit 1; }
hr()   { echo -e "${BOLD}──────────────────────────────────────────${NC}"; }

# ── detectar distro ────────────────────────────────────────────────────────────
detect_pkg_manager() {
  if command -v apt &>/dev/null; then echo "apt"
  elif command -v pacman &>/dev/null; then echo "pacman"
  else die "Gestor de paquetes no soportado. Instala manualmente: git yadm rclone gnupg"; fi
}

install_pkg() {
  local pm="$1"; shift
  case "$pm" in
    apt)    sudo apt-get install -y -q "$@" ;;
    pacman) sudo pacman -S --noconfirm --needed "$@" ;;
  esac
}

# ── instalar dependencias ──────────────────────────────────────────────────────
install_deps() {
  local pm; pm=$(detect_pkg_manager)
  info "Gestor de paquetes: ${BOLD}$pm${NC}"

  local pkgs=()
  command -v git   &>/dev/null || pkgs+=(git)
  command -v yadm  &>/dev/null || pkgs+=(yadm)
  command -v rclone &>/dev/null || pkgs+=(rclone)
  command -v gpg   &>/dev/null || pkgs+=(gnupg)

  if [[ ${#pkgs[@]} -gt 0 ]]; then
    info "Instalando: ${pkgs[*]}"
    [[ $pm == apt ]] && sudo apt-get update -q
    install_pkg "$pm" "${pkgs[@]}"
  fi
  ok "Dependencias listas"
}

# ── clonar repo ───────────────────────────────────────────────────────────────
clone_dotfiles() {
  if yadm status &>/dev/null 2>&1; then
    warn "yadm ya está inicializado — saltando clone"
    return
  fi
  info "Clonando dotfiles vía HTTPS..."
  yadm clone --no-bootstrap "$DOTFILES_REPO"
  ok "Repo clonado"
}

# ── importar llave GPG ─────────────────────────────────────────────────────────
import_gpg_key() {
  if gpg --list-secret-keys "$GPG_KEY_ID" &>/dev/null; then
    ok "Llave GPG $GPG_KEY_ID ya está importada"
    return
  fi

  hr
  echo -e "${BOLD}Importar llave GPG desde Bitwarden${NC}"
  echo ""
  echo "  1. Abre Bitwarden"
  echo "  2. Busca el Secure Note: ${BOLD}GPG private key - fsardi8${NC}"
  echo "  3. Copia todo el bloque (incluyendo las líneas BEGIN/END)"
  echo "  4. Pégalo aquí y presiona ${BOLD}Enter${NC}, luego ${BOLD}Ctrl+D${NC}"
  echo ""

  local tmpfile; tmpfile=$(mktemp)
  # Leer desde /dev/tty para que funcione con bash <(curl ...)
  cat /dev/tty > "$tmpfile"
  gpg --import "$tmpfile"
  rm -f "$tmpfile"

  # Verificar
  gpg --list-secret-keys "$GPG_KEY_ID" &>/dev/null || die "La llave no se importó correctamente"
  ok "Llave GPG importada"
}

# ── descifrar secretos ─────────────────────────────────────────────────────────
decrypt_secrets() {
  info "Descifrando secretos (rclone.conf, SSH keys, cf-ddns.env)..."
  yadm decrypt
  chmod 600 ~/.ssh/id_ed25519 ~/.ssh/id_rsa 2>/dev/null || true
  ok "Secretos descifrados"
}

# ── cambiar remote a SSH ───────────────────────────────────────────────────────
switch_to_ssh() {
  info "Cambiando remote a SSH..."
  yadm remote set-url origin "$DOTFILES_REPO_SSH"
  ok "Remote → $DOTFILES_REPO_SSH"
}

# ── verificación final ─────────────────────────────────────────────────────────
verify() {
  hr
  echo -e "${BOLD}Verificación${NC}"
  echo ""

  # SSH key
  if [[ -f ~/.ssh/id_ed25519 ]]; then
    ok "~/.ssh/id_ed25519 presente"
  else
    warn "~/.ssh/id_ed25519 no encontrada"
  fi

  # rclone
  if [[ -f ~/.config/rclone/rclone.conf ]]; then
    ok "rclone.conf presente"
    if rclone lsd alma: &>/dev/null 2>&1; then
      ok "rclone alma: conecta ✓"
    else
      warn "rclone alma: no conecta (puede necesitar re-auth)"
    fi
  else
    warn "rclone.conf no encontrada"
  fi

  # yadm status
  local dirty; dirty=$(yadm status --short 2>/dev/null | wc -l)
  if [[ $dirty -gt 0 ]]; then
    warn "$dirty archivo(s) con cambios locales — ejecuta 'dot st' para ver"
  fi
}

# ── main ───────────────────────────────────────────────────────────────────────
main() {
  hr
  echo -e "${BOLD}  fsardi8 dotfiles — bootstrap${NC}"
  hr
  echo ""

  install_deps
  clone_dotfiles
  import_gpg_key
  decrypt_secrets
  switch_to_ssh

  hr
  verify

  echo ""
  echo -e "${GREEN}${BOLD}¡Listo!${NC} Reinicia el shell o ejecuta: ${BOLD}source ~/.bashrc${NC}"
  echo ""
}

main "$@"
