# Extension E Evidence: Controlled Edge Migration

## Evidence Overview

- **Extension**: Extension E (Controlled Edge Migration)
- **Status**: Previously Captured
- **Evidence IDs**:
  - `E1`: Standby Nginx HTTP 200 via Mac B
  - `E2`: Alternating Backend Responses via Mac B
  - `E3`: DNS Cutover Verification

---

## 1. Evidence E1 & E2: Standby Edge Nginx Operation (Mac B)

### Objective
Demonstrate that the standby Nginx instance on Mac B (`10.7.18.87:8081`) receives client HTTP requests and load balances them across the two Flask backends on Mac A (`10.7.5.56:3001` and `10.7.5.56:3002`).

### Test Execution Command:
```bash
# Querying standby Nginx directly by IP and Host header
for i in {1..4}; do
    curl -i -s http://10.7.18.87:8081/api/status -H "Host: app.my_team.test" | grep -E "(HTTP/|X-Backend|X-Proxy-Edge)"
    echo "---"
done
```

### Observed Output:
```text
HTTP/1.1 200 OK
X-Backend: A
X-Proxy-Edge: Mac-B-Standby
---
HTTP/1.1 200 OK
X-Backend: B
X-Proxy-Edge: Mac-B-Standby
---
HTTP/1.1 200 OK
X-Backend: A
X-Proxy-Edge: Mac-B-Standby
---
HTTP/1.1 200 OK
X-Backend: B
X-Proxy-Edge: Mac-B-Standby
---
```
*Verification: Both `X-Backend: A` and `X-Backend: B` headers were returned in alternating round-robin fashion, with the `X-Proxy-Edge: Mac-B-Standby` header confirming termination at Mac B.*

---

## 2. Evidence E3: DNS Cutover Verification

### Objective
Demonstrate that DNS resolution for `app.my_team.test` points to Mac B (`10.7.18.87`), while `api.my_team.test` continues to point to Mac A (`10.7.5.56`).

### Query Commands:
```bash
dig @10.7.18.87 app.my_team.test +short
dig @10.7.18.87 api.my_team.test +short
```

### Observed Output:
```text
10.7.18.87
10.7.5.56
```

---

## 3. Network Transport Observations: UDP vs. TCP DNS

During testing across the shared local Wi-Fi network, intermittent UDP timeouts on port 53 were observed due to AP-level client isolation / UDP packet suppression.

### Verification of TCP DNS:
```bash
# Standard UDP query encountered occasional latency/timeout
dig @10.7.18.87 app.my_team.test +time=1

# TCP DNS query verified 100% reliable transport
dig @10.7.18.87 app.my_team.test +tcp +short
```
Output:
```text
10.7.18.87
```
This verified that the `dnsmasq` service on Mac B was actively listening on TCP port 53 and correctly serving records even when Wi-Fi multicast/UDP traffic exhibited instability.
