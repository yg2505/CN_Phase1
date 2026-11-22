# IP Addressing and Interface Specifications

## 1. Network Addressing Scheme

The Phase 2 infrastructure operates over a shared IEEE 802.11 / Wi-Fi local area network within the private Class A subnet `10.7.0.0/16`. Both nodes acquire dynamic or DHCP-reserved IP addresses within this range.

| Host Identifier | Operating System | Network Interface | IP Address | Subnet Mask | Broadcast | Default Gateway |
|---|---|---|---|---|---|---|
| **Mac A** | macOS (Darwin) | `en0` (Wi-Fi) | `10.7.5.56` | `255.255.0.0` (`/16`) | `10.7.255.255` | `10.7.0.1` |
| **Mac B** | macOS (Darwin) | `en0` (Wi-Fi) | `10.7.18.87` | `255.255.0.0` (`/16`) | `10.7.255.255` | `10.7.0.1` |

---

## 2. Port and Service Allocation Table

| Host | Node IP | Layer 4 Protocol | Port | Service / Daemon | Process Context | Operational Function |
|---|---|---|---|---|---|---|
| **Mac B** | `10.7.18.87` | UDP / TCP | `53` | `dnsmasq` | `brew services` / Root | Primary DNS resolver for `my_team.test` |
| **Mac B** | `10.7.18.87` | TCP | `8081` | `nginx` | Open-source Nginx Worker | Standby Edge Proxy for `app.my_team.test` |
| **Mac A** | `10.7.5.56` | UDP / TCP | `53` | `dnsmasq` | `brew services` / Root | Backup DNS resolver for `my_team.test` |
| **Mac A** | `10.7.5.56` | TCP | `8081` | `nginx` | Open-source Nginx Worker | Original Edge Proxy for `api.my_team.test` |
| **Mac A** | `10.7.5.56` (0.0.0.0) | TCP | `3001` | Python 3 / Flask | `backend-a/venv` | Backend Server A (`X-Backend: A`) |
| **Mac A** | `10.7.5.56` (0.0.0.0) | TCP | `3002` | Python 3 / Flask | `backend-b/venv` | Backend Server B (`X-Backend: B`) |

---

## 3. Fully Qualified Domain Names (FQDN) Mapping

The custom private namespace `my_team.test` is configured in authoritative resolver configuration files (`dnsmasq.conf`) on both hosts.

```text
$TTL 30
; Final Intended Configuration
app.my_team.test.       30      IN      A       10.7.18.87
api.my_team.test.       30      IN      A       10.7.5.56
```

### URL and Endpoint Routing

| FQDN & Port | Target IP | Upstream Service Destination | Description |
|---|---|---|---|
| `http://app.my_team.test:8081/` | `10.7.18.87:8081` (Mac B) | Round-Robin across `10.7.5.56:3001` & `10.7.5.56:3002` | Web application home endpoint routed via standby edge on Mac B |
| `http://app.my_team.test:8081/api/status` | `10.7.18.87:8081` (Mac B) | Round-Robin across `10.7.5.56:3001` & `10.7.5.56:3002` | JSON status endpoint routed via standby edge on Mac B |
| `http://api.my_team.test:8081/api/status` | `10.7.5.56:8081` (Mac A) | Round-Robin across `127.0.0.1:3001` & `127.0.0.1:3002` | API status endpoint routed via original edge on Mac A |

---

## 4. Client Resolver Configuration

On client machines (Mac A, Mac B, or another test client), DNS resolution is configured through macOS network settings (`networksetup` or `/etc/resolv.conf`):

```bash
# macOS Wi-Fi DNS configuration command
sudo networksetup -setdnsservers Wi-Fi 10.7.18.87 10.7.5.56
```

Verification via `scutil --dns`:
```text
resolver #1
  nameserver[0] : 10.7.18.87
  nameserver[1] : 10.7.5.56
  flags         : Request A records, Request AAAA records
  reach         : Reachable
```
