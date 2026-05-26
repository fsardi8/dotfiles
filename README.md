# dotfiles — fsardi8

Dotfiles personales gestionados con [yadm](https://yadm.io) y el wrapper `dot`.  
Incluye configuración de bash, SSH, rclone, GTK, y scripts de utilidad.

---

## Archivos rastreados

| Tipo | Archivos |
|------|----------|
| Shell | `.bashrc`, `.bash_aliases`, `.profile`, `.config/bash/**` |
| SSH | `.ssh/config`, `.ssh/*.pub` |
| Git | `.gitconfig`, `.gitignore_global` |
| UI | `.config/gtk-3.0/gtk.css`, `.config/gtk-4.0/gtk.css`, `qt5ct`, `qt6ct` |
| Scripts | `.local/bin/dot`, `.local/bin/gdmnt`, `.local/bin/zen-backup`, … |
| Systemd | `.config/systemd/user/syncthingy.service` |
| **Secretos (cifrados con GPG)** | `.ssh/id_ed25519`, `.ssh/id_rsa`, `.config/rclone/rclone.conf`, `.config/cf-ddns.env` |

---

## Comandos `dot`

```
dot st              # yadm status
dot ls              # lista archivos rastreados
dot diff            # diff local vs último commit
dot review          # diff local vs origin (GitHub)
dot add FILE...     # stage archivos específicos
dot skip FILE...    # ignorar cambios locales (esta máquina)
dot unskip FILE...  # reanudar tracking
dot com MESSAGE     # commit
dot amend           # amend último commit
dot pull            # pull desde origin
dot push            # push a origin
dot sync [MSG]      # add -u + commit + push (solo archivos rastreados)
```

---

## Setup en una máquina nueva

### 1. Instalar dependencias

```bash
sudo apt install yadm git rclone  # Debian/Ubuntu/Pop!_OS
```

### 2. Clonar el repo

```bash
yadm clone git@github.com:fsardi8/dotfiles.git
```

### 3. Importar la llave GPG

Los secretos del repo están cifrados con GPG. Sin la llave no se pueden descifrar.

**Opción A — desde Bitwarden (recomendado):**
```bash
# Copiar el contenido del secure note "GPG private key - fsardi8" de Bitwarden
# y pegarlo en un archivo temporal:
gpg --import /tmp/gpg-private.asc
rm /tmp/gpg-private.asc   # borrar inmediatamente
```

**Opción B — desde otra máquina en la misma red:**
```bash
# En la máquina origen:
gpg --export-secret-keys --armor A28F843C63852BF6 | ssh nueva-maquina 'gpg --import'
```

**Opción C — desde un disco montado (recuperación):**
```bash
sudo mount -o subvol=@home /dev/sdXN /mnt/pop4
cp /mnt/pop4/TU_USER/.gnupg/private-keys-v1.d/*.key ~/.gnupg/private-keys-v1.d/
cp /mnt/pop4/TU_USER/.gnupg/pubring.kbx ~/.gnupg/pubring.kbx
cp /mnt/pop4/TU_USER/.gnupg/trustdb.gpg ~/.gnupg/trustdb.gpg
gpg --list-secret-keys  # verificar
```

### 4. Descifrar los secretos

```bash
yadm decrypt
```

Esto restaura: `.ssh/id_ed25519`, `.ssh/id_rsa`, `.config/rclone/rclone.conf`, `.config/cf-ddns.env`.

### 5. Verificar

```bash
rclone lsd alma:          # Google Drive debe listar carpetas
ssh viking                # acceso a viking vía Tailscale
```

---

## Gestión de la llave GPG

### Exportar la llave (hacer esto **ahora** y en cada rotación)

```bash
gpg --export-secret-keys --armor A28F843C63852BF6 > /tmp/gpg-fsardi8.asc
```

### Dónde guardarla

| Opción | Recomendación | Por qué |
|--------|--------------|---------|
| **Bitwarden** (secure note) | ✅ **Mejor opción** | Cifrado E2E, accesible desde cualquier dispositivo, protegido por master password + 2FA |
| **Imprimir en papel** | ✅ Backup adicional | No hackeable remotamente; guardar en lugar físico seguro |
| **GitHub (repo privado)** | ❌ Nunca | Un repo privado puede quedar expuesto; la llave privada nunca debe estar en git |
| **Disco sin cifrar** | ❌ Evitar | Si pierdes el disco, pierdes el control |

### Procedimiento recomendado

```bash
# 1. Exportar con passphrase fuerte (ya la tiene si fue creada con passphrase)
gpg --export-secret-keys --armor A28F843C63852BF6

# 2. Copiar el bloque completo (-----BEGIN PGP PRIVATE KEY BLOCK----- ... -----END-----)
#    y pegarlo en Bitwarden > New Secure Note > "GPG private key - fsardi8"

# 3. Borrar el archivo temporal si lo usaste
rm -f /tmp/gpg-fsardi8.asc
```

> **Nota:** La llave ya está protegida con su propia passphrase — aunque alguien
> la robe de Bitwarden, no puede usarla sin esa passphrase.

---

## Agregar un nuevo secreto al repo

```bash
# 1. Agregar el path al archivo de encrypt
echo ".config/nuevo-secreto.conf" >> ~/.config/yadm/encrypt

# 2. Re-cifrar y commitear
yadm encrypt
dot add ~/.local/share/yadm/archive ~/.config/yadm/encrypt
dot com "add nuevo-secreto to encrypted files"
dot push
```

---

## Info

- **GPG key ID:** `A28F843C63852BF6`
- **GPG UID:** Felipe Sardi `<f@redsi.co>`
- **yadm remote:** `git@github.com:fsardi8/dotfiles.git`
- **Remoto rclone:** `alma` → Google Drive
