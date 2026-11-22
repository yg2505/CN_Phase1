# Extension F: Troubleshooting Methodology & Diagnostic Protocols

## Overview

- **Extension**: Extension F (Faculty-Injected Troubleshooting Challenge)
- **Status**: Formal faculty fault challenge skipped during evaluation.
- **Deliverable**: Systematic 4-tier network and application troubleshooting protocol established for multi-host edge and DNS environments.

---

## 1. Structured 4-Tier Diagnostic Framework

When isolating network anomalies across distributed nodes (Mac A, Mac B, Client), the following hierarchical investigation procedure is applied:

```mermaid
flowchart TD
    T1["Tier 1: DNS Resolution & Layer 3 Reachability<br/>(dig, ping, scutil, arp)"] --> T1Check{Resolved & Reachable?}
    T1Check -->|No| FixT1["Action: Check dnsmasq daemon, /etc/resolv.conf, IP routing, Wi-Fi subnet"]
    T1Check -->|Yes| T2["Tier 2: Layer 4 TCP Connectivity & Port Listening<br/>(nc -zv, lsof -nP, curl -v)"]
    
    T2 --> T2Check{Port Open & SYN-ACK received?}
    T2Check -->|No| FixT2["Action: Check Nginx process, PF firewall rules (pfctl -s rules), socket bindings"]
    T2Check -->|Yes| T3["Tier 3: TLS / Transport Layer & Protocol Validation<br/>(OpenSSL s_client, HTTP header compliance)"]
    
    T3 --> T3Check{Handshake & Protocol Clean?}
    T3Check -->|No| FixT3["Action: Inspect certificates, ALPN, Host header matching in Nginx"]
    T3Check -->|Yes| T4["Tier 4: Application & Backend Response<br/>(HTTP status codes, X-Backend headers, upstream logs)"]
    
    T4 --> T4Check{200 OK & Proper Header?}
    T4Check -->|502 / 504| FixT4["Action: Inspect Python Flask processes on Mac A, upstream timeout, LAN connectivity"]
    T4Check -->|Yes| Stable["System Healthy & Operational"]
```

---

## 2. Command Diagnostic Matrix

| Tier | Focus Area | Diagnostic Command | Expected Output / Indicator | Failure Symptom & Cause |
|---|---|---|---|---|
| **Tier 1** | DNS Resolution | `dig @10.7.18.87 app.my_team.test +short` | `10.7.18.87` | `connection timed out` → `dnsmasq` down or UDP blocked; retry with `+tcp`. |
| **Tier 1** | Resolver Config | `scutil --dns` | Lists `10.7.18.87` then `10.7.5.56` | Wrong DNS server listed in system network settings. |
| **Tier 2** | TCP Socket Listening | `lsof -nP -iTCP:8081 -sTCP:LISTEN` | `nginx (LISTEN)` | Port 8081 closed → Nginx daemon not running. |
| **Tier 2** | Remote Port Connect | `nc -zv -G 2 10.7.5.56 3001` | `Connection to 10.7.5.56 port 3001 succeeded!` | `Connection refused` → PF firewall blocking port or Flask stopped. |
| **Tier 3** | HTTP Request Trace | `curl -v http://app.my_team.test:8081/` | `Connected to 10.7.18.87 port 8081` | Connection timeout or HTTP 400 Bad Request (Host header mismatch). |
| **Tier 4** | Backend Integrity | `curl -i http://localhost:8081/api/status` | `HTTP/1.1 200 OK`, `X-Backend: A/B` | `HTTP/1.1 502 Bad Gateway` → Both backends down on Mac A. |

---

## 3. Real-World Diagnostic Case: UDP vs. TCP DNS Discrepancy

During the lab configuration of Mac B's `dnsmasq`, standard `dig` queries occasionally stalled for 2-3 seconds before resolving.

### Investigation Steps Applied:
1. **Tier 1 Check**: `ping 10.7.18.87` showed consistent 3-5ms RTT. ICMP layer was fully operational.
2. **Layer 4 UDP Check**: `nc -zvu 10.7.18.87 53` showed packet loss on Wi-Fi broadcast/multicast boundaries.
3. **Layer 4 TCP Check**: `dig @10.7.18.87 app.my_team.test +tcp` responded in 2ms consistently.
4. **Resolution**: Identified Wi-Fi router UDP packet throttling. Validated that `dnsmasq` TCP listener was fully functional.
