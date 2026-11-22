# Network Request and Traffic Flow

This document details the step-by-step packet and transport flows across the Phase 2 system for DNS resolution, edge proxying, backend failover, and firewall isolation.

---

## 1. End-to-End Client Request Flow (Post Edge-Migration)

Following the controlled edge migration of `app.my_team.test` to Mac B (`10.7.18.87`), client requests follow this path:

```mermaid
sequenceDiagram
    autonumber
    actor Client as Client Browser / cURL
    participant DNS_B as Primary DNS (Mac B: 10.7.18.87)
    participant Nginx_B as Standby Edge Nginx (Mac B: 10.7.18.87:8081)
    participant Backend_A as Backend A (Mac A: 10.7.5.56:3001)
    participant Backend_B as Backend B (Mac A: 10.7.5.56:3002)

    Note over Client,DNS_B: Step 1: DNS Resolution Phase
    Client->>DNS_B: UDP DNS Query: A? app.my_team.test (Port 53)
    DNS_B-->>Client: DNS Response: app.my_team.test -> 10.7.18.87 (TTL 30s)

    Note over Client,Nginx_B: Step 2: HTTP Connection & Reverse Proxy
    Client->>Nginx_B: TCP SYN (Port 8081)
    Nginx_B-->>Client: TCP SYN-ACK
    Client->>Nginx_B: TCP ACK & HTTP GET / HTTP/1.1 (Host: app.my_team.test:8081)

    Note over Nginx_B,Backend_A: Step 3: Upstream Proxy via LAN
    Nginx_B->>Backend_A: TCP Connection to 10.7.5.56:3001
    Nginx_B->>Backend_A: HTTP GET / (X-Forwarded-For, Host header)
    Backend_A-->>Nginx_B: HTTP 200 OK (Header: X-Backend: A, ETag: "backend-home-v1")
    Nginx_B-->>Client: HTTP 200 OK (Header: X-Backend: A, X-Proxy-Edge: Mac-B)

    Note over Client,Backend_B: Step 4: Next Request (Round-Robin Balancing)
    Client->>Nginx_B: HTTP GET /api/status HTTP/1.1
    Nginx_B->>Backend_B: TCP Connection to 10.7.5.56:3002
    Backend_B-->>Nginx_B: HTTP 200 OK (Header: X-Backend: B)
    Nginx_B-->>Client: HTTP 200 OK (Header: X-Backend: B)
```

---

## 2. DNS Resolver Failover Flow (Extension A)

When the Primary DNS server on Mac B experiences service failure or becomes unreachable, the client resolver switches to the Backup DNS server on Mac A.

```mermaid
sequenceDiagram
    autonumber
    actor Client as Client Resolver Stub
    participant DNS_B as Primary DNS (Mac B: 10.7.18.87:53)
    participant DNS_A as Backup DNS (Mac A: 10.7.5.56:53)

    Client->>DNS_B: UDP Query: A? app.my_team.test (Timeout timer starts)
    Note over DNS_B: Primary process stopped or unreachable (Port closed / silent drop)
    Client-xDNS_B: Timeout / ICMP Port Unreachable
    Note over Client: Fallback triggered to secondary nameserver in resolver list
    Client->>DNS_A: UDP Query: A? app.my_team.test
    DNS_A-->>Client: DNS Answer: 10.7.18.87 (TTL 30s)
    Note over Client: Resolution succeeds seamlessly; IP cached locally
```

---

## 3. High Availability Passive Backend Failover (Extension D)

Open-source Nginx employs **passive health checks** configured via the upstream parameters `max_fails` and `fail_timeout`.

```mermaid
sequenceDiagram
    autonumber
    actor Client as Client
    participant Nginx as Nginx Edge Proxy (Mac B: 8081)
    participant Backend_A as Backend A (10.7.5.56:3001) [Down]
    participant Backend_B as Backend B (10.7.5.56:3002) [Active]

    Client->>Nginx: HTTP GET /api/status
    Note over Nginx: Upstream scheduler picks Backend A
    Nginx->>Backend_A: TCP SYN (Port 3001)
    Backend_A--xNginx: TCP RST (Connection Refused - Process terminated)
    Note over Nginx: max_fails reached for Backend A.<br/>Marked inactive for fail_timeout (10s).<br/>proxy_next_upstream engages immediately.
    Nginx->>Backend_B: TCP SYN (Port 3002)
    Backend_B-->>Nginx: TCP SYN-ACK
    Nginx->>Backend_B: HTTP GET /api/status
    Backend_B-->>Nginx: HTTP 200 OK (X-Backend: B)
    Nginx-->>Client: HTTP 200 OK (X-Backend: B)
    Note over Client: Client experiences ZERO error (no 502 Bad Gateway)
```

---

## 4. Firewall Service Isolation Flow (Extension C)

The macOS PF rules in anchor `com.local.backend-isolation` enforce network perimeter security around backend ports `3001` and `3002`.

```mermaid
flowchart TD
    ClientReq["Incoming TCP Request to Port 3001 / 3002"] --> PFCheck{"Packet Filter Rule Evaluation<br/>(anchor: com.local.backend-isolation)"}
    
    PFCheck -->|"Source: 127.0.0.1 (Loopback)"| PassLocal["PASS QUICK<br/>(Allowed: Local Nginx on Mac A)"]
    PassLocal --> FlaskBackend["Flask Backend Process<br/>(Port 3001 / 3002)"]

    PFCheck -->|"Source: External LAN (10.7.18.87 / 10.7.0.0/16)"| BlockLAN["BLOCK RETURN<br/>(TCP RST / ICMP Unreachable)"]
    BlockLAN --> Drop["Connection Denied / Dropped<br/>PF Counter Increments"]
```
