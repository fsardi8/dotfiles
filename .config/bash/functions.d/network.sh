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
# -------------------------
# Cloudflare DDNS update (secrets stored separately)
# Create ~/.config/cf-ddns.env with:
# CF_ZONE_ID=...
# CF_API_TOKEN=...
# CF_RECORD_NAME=...
# and: chmod 600 ~/.config/cf-ddns.env
# -------------------------
  local env="$HOME/.config/cf-ddns.env"
  [[ -r "$env" ]] || { echo "Missing $env — ver README del repo dotfiles o yadm decrypt"; return 1; }
  source "$env"

  : "${CF_ZONE_ID:?Missing CF_ZONE_ID}" "${CF_API_TOKEN:?Missing CF_API_TOKEN}" "${CF_RECORD_NAME:?Missing CF_RECORD_NAME}"
  command -v jq >/dev/null || { echo "jq is required (apt install -y jq  /  pacman -S jq)"; return 1; }

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