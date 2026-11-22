# Phase 2 Presentation Outline — Slide-by-Slide Guide

**Project Title**: Distributed Multi-Host Edge Architecture, Redundant DNS, and Controlled Migration  
**Course**: Computer Networks  
**Team Members**: Yashvi Goyal, Mouli Srivastava  
**Repository**: https://github.com/yg2505/CN_Phase1

---

### Slide 1: Title & Project Overview
- **Title**: Computer Networks Phase 2: Dual-Host Network Architecture & Traffic Migration
- **Subtitle**: DNS Redundancy, Edge Reverse Proxying, Service Isolation, and High Availability
- **Presenters**: Yashvi Goyal & Mouli Srivastava
- **Core Theme**: Transitioning a single-host load balancer (Phase 1) into a distributed, multi-host network topology (Phase 2) across two physical MacBooks over a local area network.

---

### Slide 2: Objectives & Engineering Goals
- **Key Objectives**:
  - Implement DNS service redundancy (Primary on Mac B, Backup on Mac A).
  - Deploy a Standby Edge Reverse Proxy (Nginx) on Mac B.
  - Execute controlled DNS cutover of `app.my_team.test` to Mac B while proxying cross-LAN to backends on Mac A.
  - Enforce Layer 4 perimeter security via macOS Packet Filter (`pfctl`).
  - Analyze open-source Nginx passive health check and failover mechanics.
  - Establish a 4-tier structured network troubleshooting protocol.

---

### Slide 3: Network Topology & Physical Distribution
- **Physical Nodes**:
  - **Mac A (`10.7.5.56`)**: Backend Host (Flask A on `:3001`, Flask B on `:3002`), Backup DNS (`:53`), Original Edge Nginx (`:8081`).
  - **Mac B (`10.7.18.87`)**: Standby Edge Nginx (`:8081`), Primary DNS (`:53`).
- **Key Architectural Fact**:
  - Backends A & B both reside on Mac A.
  - Mac B acts as the standalone edge proxy receiving public/LAN traffic and forwarding upstream requests over LAN to Mac A.
- **Visual**: Mermaid network diagram displaying cross-host hops.

---

### Slide 4: Extension A — DNS Redundancy & Resolver Failover
- **Problem**: Single nameserver failure terminates all domain lookups.
- **Implementation**:
  - `dnsmasq` deployed on Mac B (Primary) and Mac A (Backup) authoritative for `my_team.test`.
  - Client configured with dual resolver stub via `scutil --dns` (`10.7.18.87`, `10.7.5.56`).
- **Demonstration & Results**:
  - Stopped primary DNS daemon on Mac B.
  - Client resolver seamlessly failed over to Mac A (`10.7.5.56`) within 4ms.
- **Key Distinction**: DNS failure (Layer 7 resolution fails before TCP SYN) vs. Application failure (TCP connection refused or HTTP 502).

---

### Slide 5: Extension B — DNS TTL & Controlled Record Change
- **Objective**: Study client caching behavior under an authoritative 30-second TTL.
- **Testing Approach**:
  - Configured 30s TTL in `dnsmasq`.
  - Built an isolated caching proxy harness using Python `dnslib` to measure TTL decrement.
- **Verified Findings**:
  - Cache misses populate record; subsequent queries yield cache hits with decreasing TTL.
  - Upstream record change served stale IP until the 30s TTL timer expired.
- **Limitation Note**:
  - Live cross-browser packet capture during record transition was not conclusively captured due to OS-level `mDNSResponder` caching; status marked as **Partially Completed**.

---

### Slide 6: Extension C — Host-Level Service Isolation (macOS PF)
- **Objective**: Prevent external LAN clients from directly accessing Flask backend ports `3001` and `3002`.
- **Implementation**:
  - macOS Packet Filter custom anchor: `com.local.backend-isolation`.
  - Rule: `pass in quick on lo0 ...` (permits local Nginx proxy).
  - Rule: `block return in log proto tcp ... port {3001, 3002}` (rejects LAN queries with TCP RST).
- **Verification**:
  - Local queries via Nginx: `HTTP 200 OK`.
  - Direct LAN queries from Mac B: `Connection refused` (verified via `tcpdump` showing TCP RST `[R.]`).
- **Safety**: Rules were tested and subsequently disabled to maintain host functionality.

---

### Slide 7: Extension D — High Availability & Passive Failover
- **Mechanism**: Open-source Nginx passive health checks (`max_fails=1 fail_timeout=10s`, `proxy_next_upstream`).
- **Clarification**: Open-source Nginx does *not* support active synthetic polling (NGINX Plus feature).
- **Demonstrated Behavior (Phase 1 Baseline)**:
  - Client query loop receives alternating `X-Backend: A` and `X-Backend: B`.
  - Terminating Backend A (`Ctrl+C`) causes Nginx to catch the TCP error and reroute to Backend B with zero client error.
  - Restarting Backend A restores balanced rotation after 10s.

---

### Slide 8: Extension E — Controlled Edge Migration
- **Setup**:
  - Standby Nginx on Mac B configured to upstream across LAN to `10.7.5.56:3001` and `10.7.5.56:3002`.
  - DNS record for `app.my_team.test` cut over to Mac B (`10.7.18.87`).
  - `api.my_team.test` kept on Mac A (`10.7.5.56`).
- **Results**:
  - `curl http://app.my_team.test:8081/` returns `HTTP 200 OK` with `X-Proxy-Edge: Mac-B-Standby`.
  - Verified load balancing across both backends on Mac A from Mac B.
- **Transport Finding**: Identified Wi-Fi UDP timeout issues; proved 100% stability using TCP DNS (`dig +tcp`).

---

### Slide 9: Extension F — Systematic Troubleshooting Protocol
- **Methodology**: 4-Tier Diagnostic Protocol (DNS → TCP → TLS/Transport → Application).
- **Tier 1 (DNS & L3)**: `ping`, `dig @10.7.18.87 +tcp`, `scutil --dns`.
- **Tier 2 (TCP Socket)**: `lsof -nP -iTCP:8081`, `nc -zv 10.7.5.56 3001`.
- **Tier 3 (Protocol)**: `curl -v` inspect Host header and edge proxy headers.
- **Tier 4 (Application)**: `curl -i` verify `X-Backend: A/B` and eliminate 502 Bad Gateway.
- **Status**: Formal faculty-injected challenge skipped; diagnostic framework fully established.

---

### Slide 10: Summary, Deliverables & Conclusion
- **Project Deliverables**:
  - Fully articulated 20-section technical report.
  - Reproducible configuration bundle (`dnsmasq`, `nginx`, `pfctl`).
  - Evidence index mapping verified tests (A1, A2, C1, C2, D1, E1, E2, E3, E4).
  - Clean preservation of Phase 1 code.
- **Core Takeaway**: Achieved resilient distributed edge proxying and DNS failover across physical hosts while accurately identifying real-world networking constraints.
