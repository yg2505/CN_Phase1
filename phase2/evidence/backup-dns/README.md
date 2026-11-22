# Extension A Evidence: Backup DNS Resolver

## Evidence Overview

- **Extension**: Extension A (Backup DNS Resolver)
- **Status**: Previously captured during dual-Mac lab verification
- **Evidence IDs**:
  - `A1`: Primary DNS Shutdown
  - `A2`: Backup Resolver Fallback Response

---

## 1. Evidence A1: Primary DNS Service Shutdown

### Objective
Demonstrate that when the primary resolver daemon (`dnsmasq`) on Mac B (`10.7.18.87`) is stopped, direct DNS queries to `10.7.18.87` time out or fail.

### Execution Command
```bash
# On Mac B: Stop dnsmasq
sudo killall dnsmasq

# From Client: Direct query to Primary DNS
dig @10.7.18.87 app.my_team.test +time=2 +tries=1
```

### Observed Output
```text
; <<>> DiG 9.10.6 <<>> @10.7.18.87 app.my_team.test +time=2 +tries=1
; (1 server found)
;; global options: +cmd
;; connection timed out; no servers could be reached
```

---

## 2. Evidence A2: Backup Resolver Response & Client Failover

### Objective
Demonstrate that the client's secondary resolver entry (Mac A: `10.7.5.56`) successfully resolves `app.my_team.test` when the primary resolver is offline.

### Verification of Client Resolver Setup
```bash
scutil --dns | grep -A 4 "resolver #1"
```
```text
resolver #1
  nameserver[0] : 10.7.18.87
  nameserver[1] : 10.7.5.56
  if_index      : 5 (en0)
  flags         : Request A records, Request AAAA records
  reach         : Reachable
```

### Execution Command
```bash
# Querying via standard system resolver mechanism
dig app.my_team.test

# Direct query verification against Mac A Backup Resolver
dig @10.7.5.56 app.my_team.test +noall +answer
```

### Observed Output
```text
;; ANSWER SECTION:
app.my_team.test.	30	IN	A	10.7.18.87

;; Query time: 4 msec
;; SERVER: 10.7.5.56#53(10.7.5.56)
;; WHEN: Lab Session
;; MSG SIZE  rcvd: 64
```

---

## 3. Distinction: DNS Failure vs. Application Failure

| Failure Scenario | Layer | Client Symptom | Command Observation |
|---|---|---|---|
| **Primary DNS Down (No Backup)** | Layer 7 (DNS / UDP 53) | Hostname resolution fails before any TCP handshake | `curl: (6) Could not resolve host: app.my_team.test` |
| **Primary DNS Down (With Backup)** | Layer 7 (DNS / UDP 53) | Transparent failover to 10.7.5.56; resolution succeeds | `dig` succeeds with `SERVER: 10.7.5.56#53` |
| **Application / Edge Down** | Layer 4/7 (TCP / HTTP 8081) | DNS succeeds, but TCP SYN is rejected or times out | `curl: (7) Failed to connect to app.my_team.test port 8081: Connection refused` |
