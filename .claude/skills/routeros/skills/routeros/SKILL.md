---
name: routeros
description: RouterOS/MikroTik network management. Use when the user asks about routers, MikroTik, RouterOS, firewall rules, IP addresses, interfaces, routes, DHCP, DNS, NAT, VPN, PPPoE, queues, bandwidth, ping tests, config export/backup, or any network configuration on their infrastructure.
argument-hint: [device] [command or task]
allowed-tools:
  - Bash(ssh *)
  - Bash(sshpass *)
  - Read(/home/f/mikrotik/inventory.yaml)
---

# RouterOS Skill

You are an expert RouterOS/MikroTik network engineer. You manage routers via SSH using the RouterOS CLI.

**Arguments:** `$ARGUMENTS`

---

## Devices

Read `/home/f/mikrotik/inventory.yaml` to get the current device list. Only use devices where `disabled: false`. Default device is `g2`.

For each device, use `address` as the SSH target. If connection fails, retry with `fallback_ip` (if set). Credentials: use per-device `username`/`password`; if null, fall back to `defaults.username`/`defaults.password`.

---

## SSH Idiom

All RouterOS commands go through SSH via `sshpass` (required — Claude Code sessions are non-interactive, plain `ssh` password auth will fail). The pattern:

```bash
sshpass -p '<password>' ssh -o StrictHostKeyChecking=no -o ConnectTimeout=8 <user>@<address> "<routeros-command>"
```

**Multi-command session** (avoids repeated SSH handshakes):
```bash
sshpass -p '<password>' ssh -o StrictHostKeyChecking=no -o ConnectTimeout=8 <user>@<address> "
/ip address print
/ip route print
"
```

---

## Dispatch

Parse `$ARGUMENTS`. If no device is named, default to `g2`. If no command is named, show device status.

### No args — device status
Run in one SSH session:
```
/system resource print
/system identity print
/interface print
/ip address print
```
Present as a clean summary: identity, uptime, version, CPU load, memory, interfaces with IPs.

### `list` or `devices`
Read `inventory.yaml`, show all non-disabled devices with name, address, fallback_ip, comment.

### `<device>` (just a name, no command)
Connect to that device and show its status (same as no-args but targeting that device).

### Config / export
```bash
ssh ... "/export verbose terse"
```
Strip ANSI escapes from output. Present as a code block. Offer to save to `/home/f/mikrotik/<device>-export-<date>.rsc`.

### Ping test
```bash
ssh ... "/tool/ping address=<target> count=4"
```

### Firewall review
```bash
ssh ... "/ip firewall filter print
/ip firewall nat print
/ip firewall mangle print"
```
Flag rules with `action=accept` on `chain=input` with no `src-address` restriction. Flag any `passthrough` mangle rules accumulating traffic unexpectedly.

### Interface / traffic
```bash
ssh ... "/interface print stats
/interface monitor-traffic [find] duration=3"
```

### DHCP
```bash
ssh ... "/ip dhcp-server lease print
/ip dhcp-server print
/ip pool print"
```

### Routes
```bash
ssh ... "/ip route print
/ip route print where active=yes"
```

### DNS
```bash
ssh ... "/ip dns print
/ip dns cache print"
```

### Queue / bandwidth
```bash
ssh ... "/queue simple print
/queue tree print"
```

### Apply a config change
Before making any change:
1. Show the user the exact command(s) you will run.
2. State what it does and any risk.
3. Wait for explicit confirmation ("yes", "do it", "apply").
4. After applying, verify with a follow-up read command.

Never apply changes without confirmation.

---

## Debugging cross-device reachability ("why can't X reach Y")

When asked why a host/device can't reach some other IP through the mesh (routers, OSPF, WireGuard tunnels), don't guess or dump full configs — work through this checklist in order. It's ordered by cost/signal ratio: cheap, high-signal checks first, expensive live-packet tracing only if the cheap checks don't explain it. Prefer the `mcp__routeros__*` tools (routes, ospf_neighbors, firewall_filter, wireguard_peers, ping, command) over raw SSH when available — they're structured and cheaper to reason over.

1. **OSPF adjacency + route presence, every hop.** `ospf_neighbors` should show `Full` on each hop between source and destination; `ip_routes` should show the destination subnet with a sane next-hop on every router in the path. This is cheap and rules out routing before you touch firewalls or WireGuard.

2. **Pick the right firewall chain — this depends on *who* the packet is for, not who sent it.**
   - Destination is the router's *own* address (a loopback, a wg-interface IP) → check **`input`**.
   - Destination is a host *behind* the router (LAN, or further down the mesh) → check **`forward`**.
   Checking the wrong chain gives a false "looks fine" read — e.g. a router's `forward` chain can explicitly accept ICMP while its `input` chain silently drops the same ICMP type for non-WAN sources, because there's no chain-spanning implicit accept.

3. **Check every hop's WireGuard `allowed-address` against the actual source IP you're testing with.** This is the single highest-value check for silent, config-looks-fine failures — do it early, not as a last resort. RouterOS WireGuard drops any decrypted inbound packet whose source doesn't match the receiving peer's `allowed-address`, and it does this *below* conntrack/firewall — so a dropped packet leaves zero trace in logs, connection tables, or firewall counters. Symptoms: the sending hop's conntrack shows the packet went out (`orig-packets` > 0), the next hop shows literally nothing for that flow, and this repeats identically regardless of which firewall rules you check.
   - Note the test's *actual* source IP first — pings run from a router's own console source from that router's own interface/loopback address, not from an arbitrary host behind it. Testing from the router itself proves less than testing from the real client.
   - Cross-reference that source against the `allowed-address` list on **every** peer in the path, not just the last hop.

4. **If routes/firewall/allowed-address all look correct, diff conntrack around a live test — immediately.** Fire the test ping and read `/ip firewall connection print` on each hop back-to-back with no delay in between. ICMP conntrack entries expire in ~8-10s; a slow round-trip between tool calls gives a false "nothing happened" read even when the packet did transit. Filter by `dst-address` to isolate the flow.

5. **WireGuard rx/tx byte-counter diffing only works on quiet spoke links.** On a busy hub-to-hub trunk carrying OSPF hellos, keepalives, and real traffic for the whole mesh, a few tiny test packets are noise you can't isolate — don't rely on this check there. On a quiet spoke link it's a reasonable secondary signal that packets are actually arriving at the WG layer.

6. **A live, currently-active connection from a *different* source through the same path is strong evidence the path itself works** (routing, WG tunnel, remote host alive) — it narrows the problem to something specific about the failing source/protocol, not a total mesh break. Don't discard this signal just because your own test still fails.

7. **After adding a firewall rule with `place-before`, re-verify with a plain, unfiltered `print`.** The assigned rule `.id` numbers can display out of actual execution order — trust the *order rules appear in the print output*, not their numeric ids, when confirming a new rule actually landed before the catch-all it needs to precede.

8. **If a target device is `disabled: true` in inventory.yaml and MCP can't reach it, the MCP server caches the device list at startup** — editing the file has no live effect. You'll need the user to restart the session/MCP connection after flipping the flag, and revert it back to `disabled: true` when done unless the user says otherwise.

---

## RouterOS CLI Conventions

- Print commands: `/ip address print`, `/interface print`, `/ip firewall filter print`
- Terse/detail flags: `print terse`, `print detail`, `print where`
- Add: `/ip address add address=192.168.1.1/24 interface=ether1`
- Set (by number): `/ip address set 0 comment="WAN"`
- Remove: `/ip address remove 0`
- RouterOS uses kebab-case for properties: `src-address`, `dst-port`, `in-interface`
- Comments are set with `comment=` not `#`
- Boolean properties: `disabled=yes|no`, `passive=yes|no`
- Chains: `input`, `forward`, `output`
- Connection tracking states: `established,related` (comma-separated, no spaces)

## Common patterns

**Block port on input:**
```
/ip firewall filter add chain=input protocol=tcp dst-port=<port> action=drop comment="block <port>"
```

**NAT hairpin / masquerade:**
```
/ip firewall nat add chain=srcnat out-interface=<wan> action=masquerade
```

**Static route:**
```
/ip route add dst-address=10.0.0.0/8 gateway=192.168.1.1
```

**DHCP static lease:**
```
/ip dhcp-server lease add mac-address=AA:BB:CC:DD:EE:FF address=192.168.1.50 comment="device-name"
```

**Backup (binary):**
```
/system backup save name=<device>-<date>
```
Then `scp` it locally if needed.

---

## Output Style

- Use tables for `print` output when it has multiple fields.
- Highlight anything that looks like a misconfiguration, open port, or suboptimal rule.
- For firewall chains, always show rules in order — sequence matters in RouterOS.
- When reporting errors, include the raw SSH stderr.
