# Phase 2 — Multi-Host Network Edge, DNS Redundancy & Controlled Migration

## Overview

Phase 2 expands the **Computer Networks Project** from a single-host load-balanced system into a distributed dual-host local area network (LAN) deployment across two physical Apple MacBooks (**Mac A** and **Mac B**). 

This phase focuses on high availability (HA), DNS redundancy, controlled traffic cutover, service isolation via OS-level packet filtering (PF), and systematic network fault isolation.

---

## Physical and Network Topology Summary

The deployment spans two MacBooks operating on a shared Wi-Fi/LAN subnet (`10.7.0.0/16`):

| Node / Component | Physical Host | IP Address | Port(s) | Operational Role |
|---|---|---|---|---|
| **Primary DNS Resolver** | Mac B | `10.7.18.87` | `53` (UDP/TCP) | Authoritative / forwarding resolver for `my_team.test` |
| **Backup DNS Resolver** | Mac A | `10.7.5.56` | `53` (UDP/TCP) | Redundant secondary resolver for `my_team.test` |
| **Original Edge Nginx** | Mac A | `10.7.5.56` | `8081` | Reverse proxy and load balancer for `api.my_team.test` and original edge |
| **Standby Edge Nginx** | Mac B | `10.7.18.87` | `8081` | Reverse proxy handling migrated edge traffic for `app.my_team.test` |
| **Backend A (Flask)** | Mac A | `10.7.5.56` | `3001` | Application service A emitting `X-Backend: A` |
| **Backend B (Flask)** | Mac B | `10.7.5.56` | `3002` | Application service B emitting `X-Backend: B` |

> [!IMPORTANT]
> **Host Placement Clarification**: Both application backends (**Backend A** and **Backend B**) run concurrently on **Mac A**. **Mac B** acts as the independent standby edge proxy and primary DNS host. Requests arriving at Mac B's Nginx edge on port `8081` are reverse-proxied over the LAN to the upstream backends on `10.7.5.56:3001` and `10.7.5.56:3002`.

---

## Final Intended DNS Configuration

The private domain zone `my_team.test` is partitioned across the two edge nodes:

```text
app.my_team.test.   30   IN   A   10.7.18.87   ; Standby Nginx Edge on Mac B (Migrated)
api.my_team.test.   30   IN   A   10.7.5.56    ; Original Nginx Edge on Mac A
```

Application access points:
- **Web App**: `http://app.my_team.test:8081`
- **API Endpoint**: `http://api.my_team.test:8081/api/status`

---

## Phase 2 Extensions & Completion Status

| Extension | Objective | Status | Implementation Summary |
|---|---|---|---|
| **Extension A** | Backup DNS Resolver | **Completed** | Primary `dnsmasq` on Mac B (`10.7.18.87`), backup `dnsmasq` on Mac A (`10.7.5.56`). Primary shutdown triggers backup query resolution via macOS client resolver list. |
| **Extension B** | DNS TTL & Controlled Record Change | **Partially Completed** | 30s TTL configured; custom `dnslib` caching test script verified Cache HIT/MISS and TTL countdown. Authoritative vs. stale client comparison was not conclusively captured. |
| **Extension C** | Service Isolation | **Completed & Rolled Back** | macOS Packet Filter (PF) anchor `com.local.backend-isolation` blocked external LAN access to ports 3001/3002 while allowing loopback proxy access. Rules were verified and subsequently disabled. |
| **Extension D** | High Availability Failover | **Previously Demonstrated** | Phase 1 passive failover demonstrated via Nginx upstream `max_fails=1 fail_timeout=10s`. Backends shut down with `Ctrl+C` demonstrated graceful zero-downtime rerouting. |
| **Extension E** | Controlled Edge Migration | **Completed** | Standby Nginx deployed on Mac B (`10.7.18.87:8081`) upstreaming to Mac A backends. DNS cutover redirected `app.my_team.test` to Mac B while `api` remained on Mac A. |
| **Extension F** | Faculty Troubleshooting Challenge | **Methodology Documented** | Formal in-lab fault injection was skipped. A 4-tier structured diagnosis protocol (DNS → TCP → TLS/Transport → Application) was established and documented. |

---

## Directory Layout

```text
phase2/
├── README.md                      # This navigation and overview document
├── architecture/
│   ├── network-topology.md        # Physical & logical topology with Mermaid diagrams
│   ├── ip-addressing.md           # Interface, subnet, and port mapping specifications
│   └── request-flow.md            # Sequence diagrams for DNS, Edge Proxy, and Failover
├── configs/
│   ├── README.md                  # Configuration deployment guide and variable glossary
│   ├── dnsmasq/
│   │   ├── primary-dnsmasq.conf   # Mac B primary resolver configuration
│   │   └── backup-dnsmasq.conf    # Mac A backup resolver configuration
│   ├── nginx/
│   │   ├── original-mac-a-nginx.conf # Mac A original edge proxy configuration
│   │   └── standby-mac-b-nginx.conf  # Mac B standby edge proxy configuration
│   └── firewall/
│       ├── pf-backend-isolation.conf # macOS PF rule definition for anchor
│       └── pf-setup.sh               # Safe loading and flushing script for PF rules
├── evidence/
│   ├── README.md                  # Master evidence index (A1 through E4)
│   ├── backup-dns/                # Evidence A1, A2 (dnsmasq logs, dig outputs)
│   ├── ttl-migration/             # Evidence E4 / B (dnslib cache logs, TTL countdown)
│   ├── firewall-isolation/        # Evidence C1, C2 (pfctl rule dumps, tcpdump captures)
│   ├── failover/                  # Evidence D1 (curl loop logs during backend stop)
│   ├── edge-migration/            # Evidence E1, E2, E3 (Mac B curl outputs, cutover logs)
│   └── troubleshooting/           # Extension F diagnostics logs and testing traces
├── report/
│   └── phase2-final-report.md     # Full 20-section formal technical project report
└── presentation/
    ├── presentation-outline.md    # 10-slide viva / evaluation slide deck outline
    └── demo-script.md             # Live terminal demo script with expected outputs & Q&A
```

---

## Getting Started & Verification

1. **Review Architecture**: Start by reviewing [`architecture/network-topology.md`](architecture/network-topology.md) and [`architecture/request-flow.md`](architecture/request-flow.md).
2. **Review Configurations**: Inspect [`configs/README.md`](configs/README.md) to understand how the services are deployed and configured.
3. **Inspect Test Evidence**: Consult [`evidence/README.md`](evidence/README.md) for the consolidated test results and placeholder descriptions.
4. **Read the Final Report**: Read the complete formal documentation in [`report/phase2-final-report.md`](report/phase2-final-report.md).
5. **Presentation & Live Demo**: Review [`presentation/demo-script.md`](presentation/demo-script.md) for execution commands during technical review.
