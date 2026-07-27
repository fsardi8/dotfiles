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

## Which tool: this skill (SSH) vs `routeros-api` vs `mikrotik-mcp`

This is the canonical decision — the other two places router work can
happen (`routeros-api`'s `SKILL.md`, `mikrotik-mcp`) point back here rather
than duplicating it, so update it here first if the guidance changes.

**Skill-vs-skill is a free choice you make silently, mid-conversation** — no
user action needed, just pick whichever fits and proceed:

- **Default to `routeros-api`** for reads and bounded writes: `print`-type
  lookups, `add`/`set`/`remove` on a single resource, bounded operational
  commands (`ping` and similar). Structured JSON, no ANSI/box-drawing to
  strip, ~30-40ms/call vs. this skill's SSH handshake+PTY overhead — the
  right default for anything fleet-wide or repeated.
- **Use this skill (SSH) instead** for: `/export`/config export, binary
  backups, anything interactive or continuously-streaming (live
  `/tool/traceroute`, continuous `/interface monitor-traffic`), or genuinely
  arbitrary console actions the API model can't express as a bounded
  request/response (confirmed the hard way once: an OSPF interface-template
  reorder on `vr` needed plain SSH remove+re-add — no clean API equivalent).
  Also use this skill if a device's `api` service isn't enabled at all.

**MCP (`mikrotik-mcp`) is a different kind of choice — not a mid-task
swap.** It only loads at session start (enabling/disabling it requires
quitting and restarting Claude Code — see `ENABLE_MCP.sh`/`.mcp.json` in
`/home/f/mikrotik`), unlike the two skills above, which cost nothing until
invoked and can be switched between freely inside one conversation. That
asymmetry means: **never suggest turning on MCP mid-conversation** as a fix
for the task in front of you — that forces the user to abandon the running
session. MCP is a decision the user makes *before* starting a session they
already know will be router-heavy, not something to dynamically reach for.
If asked whether to enable it, say so plainly rather than quietly assuming
it, and let the user decide.

If MCP is already connected (check for `mcp__routeros__*` tools in the
current session), prefer its **minimal** mode (5 tools: `list_devices`,
`system_info`, `command`, `config`, `ping`) over full mode (22 tools) unless
you genuinely need the extra dedicated tools — minimal mode's generic
`command()` covers the same ground at a fraction of the standing
per-message token cost. Note `mcp__routeros__command` only supports
`print`/`add`/`set`/`remove` on a path, same ceiling as `routeros-api`'s
CRUD verbs (its own `call` verb for arbitrary operational commands has no
MCP equivalent today).

---

## Devices

Read `/home/f/mikrotik/inventory.yaml` to get the current device list. Only use devices where `enabled: true` (devices without the field are disabled by default).

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

**SSH-key auth is not currently wired up anywhere** (this skill or
`mikrotik-mcp` — its client accepts a `private_key` param but never actually
uses it, always authenticates with `password=`), and no fleet device has a
Claude-usable pubkey imported. Password-based `sshpass` is the working
state; don't assume `-i <key>` will work. Keys would be a real improvement
(drops the `sshpass` dependency, and stops a plaintext router password from
appearing in every SSH command string — which matters most when that command
gets fanned out through cheap subagents or background Bash for fleet
rollouts) but that's a future per-device rollout (`/user ssh-keys import`),
not something to assume is already done.

---

## Dispatch

Parse `$ARGUMENTS`. If no command is named, show device status.

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
Read `inventory.yaml`, show all enabled devices with name, address, fallback_ip, comment.

### `<device>` (just a name, no command)
Connect to that device and show its status (same as no-args but targeting that device).

### Config / export
```bash
ssh ... "/export verbose terse"
```
Strip ANSI escapes from output. Present as a code block. Offer to save to `/home/f/mikrotik/tiks/<device>-export-<date>.rsc`.

### Ping test
```bash
ssh ... "/tool/ping address=<target> count=4"
```

### Traceroute test
```bash
ssh ... "/tool/traceroute address=<target>"
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

### Routes
```bash
ssh ... "/ip route print
/ip route print where active=yes"
```

### DHCP
```bash
ssh ... "/ip dhcp-server lease print
/ip dhcp-server print
/ip pool print"
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

## Fleet-wide rollout pattern (apply one change to many devices)

This is a constantly-recurring shape of task (RADIUS server rollout, mesh
routing-primary switch, syslog onboarding, `permitidas` gap sweep, WG
listen-port fixes) — don't reinvent it each time:

1. Read `inventory.yaml`, filter to `enabled: true`, build a per-device task
   list (name + address + fallback_ip + whatever per-device parameter the
   change needs).
2. Apply mechanically — background `Bash` with `xargs -P <n>` running one
   script per device (script takes the SSH idiom above, writes its result to
   a per-device file), or delegate the identical step to a cheap Haiku
   subagent if it's purely mechanical with no judgment calls (see this
   project's memory on agent model choice). Keep planning/judgment calls
   (which value per site, how to handle an unreachable device) with the
   primary model — only the repetitive apply step is a good fit for
   cheap/background execution.
3. **Never trust an exit-0 "COMPLETE" status alone.** Independently verify
   every device's result file afterward — grep for the expected end-state
   and the absence of error strings, spot-check at least one file in full.
   A script that silently no-ops (e.g. a non-executable file, a permission
   error) can still report success at the process-exit level while doing
   nothing on-device.
4. Document what shipped and to which devices in the relevant `CLAUDE.md` —
   fleet state drifts fast and the next session needs to know what's already
   done vs. still pending.

---

## Debugging cross-device reachability ("why can't X reach Y")

When asked why a host/device can't reach some other IP through the mesh (routers, OSPF, WireGuard tunnels), don't guess or dump full configs — work through this checklist in order. It's ordered by cost/signal ratio: cheap, high-signal checks first, expensive live-packet tracing only if the cheap checks don't explain it. Prefer structured tools over raw SSH when available — `routeros-api`'s `OSPF neighbors`/`Firewall review`/`WireGuard peers`/`Conntrack` dispatch entries, or `mcp__routeros__*` tools (routes, ospf_neighbors, firewall_filter, wireguard_peers, ping, command) if MCP happens to be connected — they're structured and cheaper to reason over than parsing SSH output.

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

8. **If a target device is not `enabled: true` in inventory.yaml (i.e. missing the field, or explicitly `enabled: false`) and MCP can't reach it, the MCP server caches the device list at startup** — editing the file has no live effect. You'll need the user to restart the session/MCP connection after flipping the flag, and revert it back (remove the `enabled: true` line, or set `enabled: false`) when done unless the user says otherwise.

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
