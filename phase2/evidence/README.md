# Master Evidence Index — Phase 2

This directory contains the verification artifacts, command outputs, packet inspection logs, and placeholders for the Phase 2 extensions.

---

## Consolidated Evidence Matrix

| Evidence ID | Extension | Target Feature | Description / Objective | Status | Primary Artifact File(s) |
|:---:|:---:|---|---|:---:|---|
| **A1** | **A** | Primary DNS Shutdown | Verification that stopping `dnsmasq` on Mac B halts port 53 responses from `10.7.18.87`. | **Previously captured** | [`backup-dns/`](backup-dns/README.md) |
| **A2** | **A** | Backup Resolver Response | Verification that client queries fall back to Mac A (`10.7.5.56`) returning valid records. | **Previously captured** | [`backup-dns/`](backup-dns/README.md) |
| **C1** | **C** | PF Rules & Counters | `pfctl` output demonstrating anchor `com.local.backend-isolation` rule evaluation and block counters. | **Previously captured** | [`firewall-isolation/`](firewall-isolation/README.md) |
| **C2** | **C** | Backend Isolation Packet Capture | Packet capture (`tcpdump`) showing TCP RST generation on LAN queries to port 3001/3002. | **Previously captured** | [`firewall-isolation/`](firewall-isolation/README.md) |
| **D1** | **D** | Backend Failover | Phase 1 proof showing Nginx seamlessly rerouting traffic when Backend A is killed. | **Phase 1 evidence required** | [`failover/`](failover/README.md) |
| **E1** | **E** | Standby Nginx HTTP 200 | HTTP 200 responses received via Mac B (`10.7.18.87:8081`) for `app.my_team.test`. | **Previously captured** | [`edge-migration/`](edge-migration/README.md) |
| **E2** | **E** | Alternating Backend Responses | Consecutive curls demonstrating `X-Backend: A` and `X-Backend: B` headers via Mac B. | **Previously captured** | [`edge-migration/`](edge-migration/README.md) |
| **E3** | **E** | DNS Cutover | Verification of updated A record `app.my_team.test` pointing to `10.7.18.87`. | **Previously captured** | [`edge-migration/`](edge-migration/README.md) |
| **E4** | **E / B** | TTL Countdown & Stale Cache | Python `dnslib` caching resolver output showing TTL decrement and cached response. | **Partially captured** | [`ttl-migration/`](ttl-migration/README.md) |

---

## Evidence Authenticity and Safety Standards

1. **No Fabricated Data**: Placeholder files explicitly identify where raw terminal logs or screenshots from testing are referenced.
2. **Clear Demarcation**: Content is labeled as either verified from lab execution or pending attachment.
3. **No Sensitive Leaks**: Network traces and outputs strip internal credentials, tokens, or unnecessary personal identifiers.
