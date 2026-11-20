# OverlordsXI — VPS Gateway, WireGuard, Cloudflare DNS & Privacy Guide

Covers **Phases 6, 7, 8, and 10**:

```text
Players ──► play.<domain> (Cloudflare DNS-only) ──► Ubuntu LTS VPS (Public IPv4)
                                                         │
                                            WireGuard Tunnel (10.77.0.0/24)
                                            Unraid (10.77.0.2) ──► VPS (10.77.0.1)
                                            (outbound from Unraid — NO home port-forwards!)
                                                         │
                                                         ▼
                                            Unraid Docker (OverlordsXI)
```

---

## 1. Phase 6 — WireGuard & VPS Gateway Setup

### Subnet & Conflict Check

Default tunnel subnet: `10.77.0.0/24` (`10.77.0.1` VPS, `10.77.0.2` Unraid).  
Before applying, verify no conflict on Unraid (`ip route`) or VPS (`ip route`).

### Audited Ports Forwarded Through VPS

| Protocol | Port(s) | Service | Forwarded? |
|---|---|---|---|
| TCP | `54231`, `54230`, `54001` | `xi_connect` (Auth TLS, Lobby Data, Lobby View) | **YES** |
| TCP | `54002` | `xi_search` (Search / AH) | **YES** |
| TCP | `51220`, `51240` | `xi_profile` (POL Profile TLS / IRC) | **YES** |
| **UDP** | `54230` | `xi_map` (FFXI Zone / Gameplay) | **YES** |
| UDP | `51820` | WireGuard tunnel (VPS input only) | **VPS only** |
| TCP | `3306` | MariaDB | **NEVER** |
| TCP | `54003`, `8088` | ZeroMQ IPC / HTTP API | **NEVER** |
| TCP | `80`, `443` (Unraid UI) | Unraid Administration | **NEVER** |

### SNAT (`masquerade`) vs Policy Routing — Important Trade-off

The provided `deploy/vps/firewall/nftables-overlordsxi.conf.template` uses **DNAT + SNAT (`masquerade`)** on `wg0`:
- **Advantage:** Simple split-tunnel setup on Unraid (`AllowedIPs = 10.77.0.1/32`). Unraid **always** routes game replies back through `wg0` to the VPS, completely preventing asymmetric routing and residential IP leaks, while normal Unraid traffic stays on your LAN/WAN.
- **Trade-off (Documented):** Because traffic is SNATed to `10.77.0.1`, OverlordsXI game logs and `accounts_sessions.client_addr` see `10.77.0.1` as the client IP.
  - Ensure `settings/login.lua` has `LOGIN_LIMIT = 0` (already `0` on OverlordsXI) so multiple players behind `10.77.0.1` are not blocked.
  - Ensure `settings/network.lua` has `TCP_ALLOW = '10.77.0.1'` (or high `TCP_CONNECT_COUNT`) so LandSandBoat's per-IP TCP flood guard does not rate-limit legitimate players sharing `10.77.0.1`.
  - **IP-based bans** must be enforced on the **VPS `nftables` firewall** (where real player IPs are visible), while account/character bans work normally in-game.
- **Alternative (Full Real-IP Preservation):** Remove `masquerade` on `wg0` and configure a dedicated Linux policy routing table (`ip rule` + `fwmark`) on Unraid so all replies from game ports exit `wg0`. Only use this if you explicitly need real client IPs inside `xi_connect`/`xi_map` logs.

### VPS Setup Steps (Ubuntu LTS)

1. Generate WireGuard keys on VPS and Unraid (never commit private keys to Git):
   ```bash
   umask 077
   wg genkey | tee /etc/wireguard/vps.key | wg pubkey > /etc/wireguard/vps.pub
   wg genpsk > /etc/wireguard/unraid.psk
   ```
2. Populate `/etc/wireguard/wg0.conf` from `deploy/vps/wireguard/vps-wg0.conf.template`.
3. Populate `/etc/nftables.conf` from `deploy/vps/firewall/nftables-overlordsxi.conf.template` (confirm `WAN_IF` with `ip route get 1.1.1.1`).
4. Run `sudo ./deploy/vps/scripts/setup-vps-gateway.sh`.
5. Configure Unraid WireGuard (`Settings -> VPN Manager`) using `deploy/vps/wireguard/unraid-wg0.conf.template` with `PersistentKeepalive = 25`.
6. Verify tunnel from VPS: `./deploy/vps/scripts/wg-healthcheck.sh 10.77.0.2`.

---

## 2. Phase 7 — Cloudflare DNS Configuration

Create the following DNS record in Cloudflare for your domain (only when authorized):

| Type | Name | Content | Proxy Status | TTL |
|---|---|---|---|---|
| `A` | `play` (`play.<your-domain>`) | `<VPS_PUBLIC_IPV4>` | **DNS only (Grey Cloud)** | Auto / 300s |

> **Important Security & DDoS Clarification:**
> - Standard Cloudflare orange-cloud proxying **only** supports HTTP/HTTPS and breaks FFXI's custom TCP/UDP protocols. Unless you have a paid **Cloudflare Spectrum** Enterprise/Pro plan configured for raw TCP+UDP, `play.<domain>` **must** be **DNS-only (grey cloud)**.
> - Consequently, Cloudflare DNS does **not** provide DDoS proxying for FFXI traffic. Choose a VPS provider with built-in L3/L4 DDoS mitigation (e.g., OVH, Hetzner + mitigation, Path/BuyVM/FranTech, etc.).

---

## 3. Phase 8 — FFXI Client & Launcher Connectivity

1. On Unraid, set `OVERLORDS_ZONE_IP=<VPS_PUBLIC_IPV4>` in `deploy/unraid/.env` and apply it:
   ```bash
   ./scripts/overlords-ctl.sh set-zone-ip <VPS_PUBLIC_IPV4>
   ./scripts/overlords-ctl.sh restart xi-connect xi-map
   ```
2. Verify in `xi_connect` logs (`./scripts/overlords-ctl.sh logs xi-connect`) that on login:
   `zoneipp: <VPS_PUBLIC_IPV4>:54230, searchipp: <VPS_PUBLIC_IPV4>:54002`
3. Test from an **external network** (e.g. mobile hotspot, NOT home LAN):
   - Launch Ashita v4 via OverlordsXI Launcher pointed at `play.<domain>` (using `overlords-server.json` override during staging; update `manifest.json` `defaultHost` in `overlordsxi-launcher` only upon approved cutover).
   - Confirm: login, character select, zone load, zone-to-zone transition, auction/search, logout, and reconnect.
   - Players do **not** need WireGuard or Tailscale installed.

---

## 4. Phase 10 — Security & Privacy Verification Checklist

Run `./deploy/vps/scripts/verify-privacy.sh play.<domain> <VPS_PUBLIC_IPV4> <RESIDENTIAL_IP>` from an external host, then confirm every item:

- [ ] `dig +short A play.<domain> @1.1.1.1` returns **only** `<VPS_PUBLIC_IPV4>`.
- [ ] `xi_connect` login logs show `zoneipp` and `searchipp` = `<VPS_PUBLIC_IPV4>` (never residential IP, never `10.77.0.2`, never `192.168.x.x`).
- [ ] External client login, zoning, logout, and reconnect succeed over `play.<domain>`.
- [ ] Residential router has **zero** game port-forwards (`54001–54231`, `51220`, `51240`) and **UPnP** has no mappings for OverlordsXI or Unraid.
- [ ] MariaDB (`3306`) is bound strictly to `127.0.0.1` on Unraid and unreachable from VPS/LAN/WAN.
- [ ] Unraid WebUI (`80`/`443`) is unreachable via VPS or public internet.
- [ ] VPS `nftables` exposes only SSH, WireGuard (`51820/udp`), and the 7 audited FFXI ports.
- [ ] No `.env`, `*.key`, `*.cert`, or populated `wg0.conf` files are tracked in Git (`git status` / `git ls-files`).
- [ ] **Residual Origin-IP Disclosure Audit:**
  - Verify your Wiki / Combat Analytics domain (served via SWAG) is Cloudflare orange-cloud proxied (or hosted on the VPS) and that historical DNS records (e.g., SecurityTrails) or mail SPF/MX records do not expose your residential IP.
  - Launcher updates & DAT downloads come from GitHub (`raw.githubusercontent.com` / `api.github.com`), so they do not expose your residential IP.
