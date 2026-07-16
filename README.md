# dotfiles — fsardi8

Dotfiles personales gestionados con [yadm](https://yadm.io) y el wrapper `dot`.

---

## Instalación en una PC nueva

### Método preferido — desde tu máquina principal (repo privado, sin token)

```bash
# 1. Copiar tu SSH key a la nueva máquina (pide password una sola vez)
ssh-copy-id -i ~/.ssh/id_ed25519.pub user@newhost

# 2. Bootstrap completo desde aquí
dot bootstrap user@newhost
```

`dot bootstrap` hace todo automáticamente:
- Copia `id_ed25519` → nueva máquina puede autenticarse con GitHub
- Instala `yadm` y `gnupg`
- Clona el repo vía SSH
- Configura sudo sin contraseña (`/etc/sudoers.d/90-nopasswd`)
- Pide la llave GPG de Bitwarden → descifra secretos (SSH keys, rclone, cf-ddns)
- Ejecuta el bootstrap de yadm (servicios systemd, etc.)

Necesitas la **llave GPG privada** en Bitwarden (`GPG private key - fsardi8`).
La pegas interactivamente — nunca viaja por la red.

### Método alternativo — directamente en la nueva máquina (SSH key ya copiada)

Si ya copiaste `id_ed25519` manualmente a `~/.ssh/`:

```bash
bash <(curl -fsSL https://raw.githubusercontent.com/fsardi8/dotfiles/master/install.sh)
```

---

## La regla de oro: ¿qué va dónde?

```
¿Es secreto?
    │
    ├── SÍ → ¿lo necesitas en todas tus máquinas?
    │            ├── SÍ → dot encrypt    (.ssh/id_rsa, rclone.conf, .env con tokens)
    │            └── NO → déjalo fuera de todo
    │
    └── NO → ¿es igual en todas tus máquinas?
                 ├── SÍ → dot add        (.bashrc, scripts, .gitconfig, .pub keys)
                 └── NO → ni dot add ni encrypt
                          (.config/gtk, qt5ct, user-dirs — cambian por tema/DPI)
```

### Ejemplos concretos

| Archivo | Dónde | Por qué |
|---------|-------|---------|
| `~/.ssh/id_ed25519` (privada) | `dot encrypt` | secreta |
| `~/.ssh/id_ed25519.pub` (pública) | `dot add` | no es secreta, es útil rastrearla |
| `~/.config/rclone/rclone.conf` | `dot encrypt` | contiene tokens OAuth |
| `~/.config/cf-ddns.env` | `dot encrypt` | contiene API keys de Cloudflare |
| `~/.bashrc`, scripts, `.gitconfig` | `dot add` | no secretos, iguales en todas partes |
| `~/.config/gtk-3.0/gtk.css` | ninguno | cambia por tema/máquina |
| `~/.config/qt5ct/qt5ct.conf` | ninguno | cambia por DPI/resolución |

---

## Comandos `dot`

### Flujo normal — siempre termina en `dot sync`

```bash
# Editaste un archivo ya rastreado (lo más común):
dot sync "mensaje"

# Agregás un archivo público nuevo:
dot add ~/.config/micro/settings.json
dot sync "add micro config"

# Agregás un secreto nuevo:
dot encrypt ~/.config/nuevo-servicio.env
dot sync "encrypt: nuevo-servicio"

# Un secreto existente cambió (ej. rclone.conf con nuevos tokens):
dot encrypt ~/.config/rclone/rclone.conf
dot sync "encrypt: update rclone"
```

> `dot sync` siempre es el último paso. Hace `add -u` + `commit` + `push` en uno.  
> `dot add` y `dot encrypt` preparan el stage — después `dot sync` lo sube todo.

### Inspección

```bash
dot st                   # ver qué cambió
dot diff                 # ver los cambios en detalle
dot review               # comparar local vs GitHub
dot ls                   # listar archivos rastreados (públicos)
dot lse                  # listar secretos cifrados (encrypt list)
```

### Sincronización con GitHub

| Comando | Qué hace |
|---------|----------|
| `dot pull` | GitHub → local. Úsalo al llegar a una PC desactualizada |
| `dot sync` | `add -u` + `commit` + `push` todo en uno |

### Otros

```bash
dot skip ~/.bashrc       # ignorar cambios locales (solo en esta máquina)
dot unskip ~/.bashrc     # reanudar el tracking
```

---

## Setup manual en una PC nueva (paso a paso)

Si prefieres hacer los pasos a mano (la nueva máquina ya tiene `id_ed25519` copiada):

```bash
# 1. Instalar dependencias
sudo apt install yadm git rclone gnupg zoxide eza micro bat fd-find fzf jq   # Debian/Ubuntu/Pop!_OS
sudo pacman -S yadm git rclone gnupg zoxide eza micro bat fd fzf jq          # Arch/CachyOS

# 1b. Nerd Font para los iconos de eza (eza --icons)
#     Arch:
sudo pacman -S ttf-nerd-fonts-symbols
#     Debian — descargar NerdFontsSymbolsOnly desde https://github.com/ryanoasis/nerd-fonts/releases
#     y copiar los .ttf a ~/.local/share/fonts/ && fc-cache -f
#     (install.sh hace esto automáticamente)

# 2. Clonar via SSH
ssh-keyscan github.com >> ~/.ssh/known_hosts
yadm clone --no-bootstrap git@github.com:fsardi8/dotfiles.git

# 3. Importar llave GPG desde Bitwarden
#    (copiar el bloque BEGIN/END PGP PRIVATE KEY del Secure Note)
gpg --import   # pegar y Ctrl+D
fpr=$(gpg --list-secret-keys --with-colons A28F843C63852BF6 | awk -F: '/^fpr/{print $10; exit}')
echo "$fpr:6:" | gpg --import-ownertrust

# 4. Descifrar secretos → restaura SSH keys, rclone.conf, cf-ddns.env
yadm decrypt
chmod 600 ~/.ssh/id_ed25519 ~/.ssh/id_rsa

# 5. Ejecutar bootstrap (servicios systemd, etc.)
yadm bootstrap

# 6. Verificar
rclone lsd alma:          # Google Drive debe listar carpetas
ssh viking                # acceso via Tailscale
```

---

## Recuperación desde otro disco (cuando el sistema no arranca)

```bash
# Montar la partición (btrfs con subvolúmenes)
sudo mount /dev/sda4 /mnt/pop
sudo mount -o subvol=@home /dev/sda4 /mnt/pop4

# Copiar el keyring GPG
cp /mnt/pop4/f/.gnupg/private-keys-v1.d/*.key ~/.gnupg/private-keys-v1.d/
cp /mnt/pop4/f/.gnupg/pubring.kbx ~/.gnupg/pubring.kbx
cp /mnt/pop4/f/.gnupg/trustdb.gpg ~/.gnupg/trustdb.gpg

# Verificar y descifrar
gpg --list-secret-keys
yadm decrypt
```

---

## Gestión de la llave GPG

**Key ID:** `A28F843C63852BF6`  
**UID:** Felipe Sardi `<f@redsi.co>`

### Exportar (hacer esto al crear o renovar la llave)

```bash
gpg --export-secret-keys --armor A28F843C63852BF6
# Copiar el bloque → Bitwarden → New Secure Note → "GPG private key - fsardi8"
```

### Dónde guardarla

| Opción | Veredicto | Por qué |
|--------|-----------|---------|
| **Bitwarden** (Secure Note) | ✅ Mejor | Cifrado E2E + master password + 2FA. Accesible desde cualquier dispositivo |
| **Papel impreso** | ✅ Backup adicional | No hackeable remotamente |
| **GitHub** (repo privado) | ❌ Nunca | Un repo privado puede quedar expuesto |
| **Disco sin cifrar** | ❌ Evitar | Si pierdes el disco, pierdes el control |

> La llave ya tiene su propia passphrase — aunque alguien la robe de Bitwarden, no puede usarla sin ella. Son dos capas de protección.

---

## Compatibilidad Debian / Arch

Los dotfiles funcionan en ambas distros. Algunas notas:

| Tool | Debian/Ubuntu | Arch/CachyOS |
|------|--------------|--------------|
| `bat` | paquete `bat`, binario `batcat` | paquete `bat`, binario `bat` |
| `fd` | paquete `fd-find`, binario `fdfind` | paquete `fd`, binario `fd` |
| SSH service | `systemctl restart ssh` | `systemctl restart sshd` |
| Package mgr | `apt` | `pacman` |
| Nerd Font | descarga manual (install.sh lo automatiza) | `ttf-nerd-fonts-symbols` vía pacman |

Los aliases `ai/ar/au`, `bat`, `cat`, `fd`, `essh` y `MANPAGER` se adaptan automáticamente al detectar el binario o gestor de paquetes disponible — no requieren configuración manual.

> **Nerd Font:** `eza --icons` (usado en `ls`, `ll`, `la`, `lt`) requiere una Nerd Font en el terminal. `install.sh` instala **Symbols Nerd Font** automáticamente — una fuente de símbolos que actúa como fallback sin necesidad de cambiar la fuente del terminal.

---

## Archivos rastreados

| Tipo | Archivos |
|------|----------|
| Shell | `.bashrc`, `.bash_aliases`, `.profile`, `.config/bash/**` |
| SSH | `.ssh/config`, `.ssh/*.pub` |
| Git | `.gitconfig`, `.gitignore_global` |
| Scripts | `.local/bin/dot`, `.local/bin/gdmnt`, `.local/bin/zen-backup`, … |
| Systemd | `.config/systemd/user/syncthingy.service` |
| Editor | `.config/micro/settings.json` |
| **Secretos (cifrados GPG)** | `.ssh/id_ed25519`, `.ssh/id_rsa`, `.config/rclone/rclone.conf`, `.config/cf-ddns.env` |
| **No rastreados** | gtk.css, qt5ct, qt6ct, user-dirs (machine-specific) |

---

## Info

- **yadm remote:** `git@github.com:fsardi8/dotfiles.git`
- **Remoto rclone:** `alma` → Google Drive (Hotel Alma)
- **GPG key ID:** `A28F843C63852BF6`
