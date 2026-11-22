# Phase 2 Final Project Demonstration Script & Viva Guide

**Environment Setup**:
- **Mac A (`10.7.5.56`)**: Runs Flask Backend A (`:3001`), Flask Backend B (`:3002`), Backup DNS (`:53`), Original Nginx (`:8081`).
- **Mac B (`10.7.18.87`)**: Runs Primary DNS (`:53`), Standby Nginx (`:8081`).
- **Client Terminal**: Any shell session with network access to the two MacBooks.

---

## 1. Live Demonstration Step-by-Step

### Demo Step 1: Verify Application Backends on Mac A
Open two terminal windows on **Mac A**:

```bash
# Terminal 1 - Start Backend A
cd CN_Phase1/backend-a
./venv/bin/python app.py

# Terminal 2 - Start Backend B
cd CN_Phase1/backend-b
./venv/bin/python app.py
```

*Verification from Client/Mac A*:
```bash
curl -i http://127.0.0.1:3001/api/status | grep -E "(HTTP/|X-Backend)"
curl -i http://127.0.0.1:3002/api/status | grep -E "(HTTP/|X-Backend)"
```
**Expected Output**:
```text
HTTP/1.0 200 OK
X-Backend: A
HTTP/1.0 200 OK
X-Backend: B
```

---

### Demo Step 2: Verify DNS Resolution & Redundancy (Extension A)

#### 2.1 Verify Authoritative Records on Primary DNS (Mac B):
```bash
dig @10.7.18.87 app.my_team.test +short
dig @10.7.18.87 api.my_team.test +short
```
**Expected Output**:
```text
10.7.18.87
10.7.5.56
```

#### 2.2 Demonstrate DNS Resolver Failover:
1. Stop primary DNS on Mac B:
   ```bash
   sudo killall dnsmasq
   ```
2. Verify resolution falls back to Backup DNS on Mac A (`10.7.5.56`):
   ```bash
   dig @10.7.5.56 app.my_team.test +short
   ```
**Expected Output**:
```text
10.7.18.87
```

---

### Demo Step 3: Standby Edge Proxy & Cross-Host Load Balancing (Extension E)

From the Client machine, issue multiple HTTP requests through the Standby Nginx Edge on Mac B (`10.7.18.87`):

```bash
for i in {1..4}; do
    curl -s -i http://10.7.18.87:8081/api/status -H "Host: app.my_team.test" | grep -E "(HTTP/|X-Backend|X-Proxy-Edge)"
    echo "---"
done
```

**Expected Output**:
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
*Key Takeaway*: Mac B successfully proxies across the LAN to both backends on Mac A and alternates responses between `Backend A` and `Backend B`.

---

### Demo Step 4: Demonstrate Backend Failover (Extension D)

While continuously querying the edge proxy, terminate Backend A on Mac A (`Ctrl+C` in Terminal 1):

```bash
for i in {1..6}; do
    curl -s http://10.7.18.87:8081/api/status -H "Host: app.my_team.test" | grep -o '"backend":"[AB]"'
    sleep 0.5
done
```

**Expected Output**:
```text
"backend":"A"
"backend":"B"
"backend":"B"
"backend":"B"
"backend":"B"
"backend":"B"
```
*Key Takeaway*: When Backend A stops, Nginx immediately routes all traffic to Backend B without generating any client error.

---

### Demo Step 5: Service Isolation via macOS PF Firewall (Extension C)

Demonstrate anchor loading, verification, and rollback:

```bash
# On Mac A: Enable PF anchor
sudo ./phase2/configs/firewall/pf-setup.sh enable

# Test 1: Local Loopback access (Allowed)
curl -s -o /dev/null -w "%{http_code}\n" http://127.0.0.1:3001/api/status
# Expected: 200

# Test 2: External LAN access (from Mac B - Blocked)
curl -s --connect-timeout 2 http://10.7.5.56:3001/api/status || echo "Connection Rejected as Expected"
# Expected: curl error (7) Connection refused

# Rollback: Disable firewall
sudo ./phase2/configs/firewall/pf-setup.sh disable
```

---

## 2. Likely Viva / Technical Evaluation Questions & Answers

### Q1: Why are both Flask backends located on Mac A instead of split across both Macs?
**Answer**: Hosting both backends on Mac A while hosting the Standby Nginx Edge on Mac B accurately models real-world enterprise infrastructure where the edge proxy layer (DMZ) is physically separated from internal application tiers. This configuration allowed us to test cross-host reverse proxying across the physical LAN, verify firewall isolation, and execute edge traffic migration without moving application data.

### Q2: Does open-source Nginx perform active health checks on the backend servers?
**Answer**: No. Open-source Nginx only supports **passive health checks** through directives like `max_fails=1` and `fail_timeout=10s`, coupled with `proxy_next_upstream`. It only detects that a backend is down when an actual client request fails. Active synthetic health checks (proactively pinging backends in the background) are an NGINX Plus commercial feature.

### Q3: What is the technical difference between a DNS failure and an Application failure?
**Answer**: 
- **DNS Failure** occurs at Layer 7 during name resolution before any TCP handshake begins. The client cannot map the FQDN to an IP address, resulting in `curl: (6) Could not resolve host`.
- **Application/Edge Failure** occurs at Layer 4 or Layer 7 after DNS resolution succeeds. The client has the IP, but the TCP handshake fails (`curl: (7) Connection refused`) or the proxy returns an HTTP error such as `502 Bad Gateway` or `504 Gateway Timeout`.

### Q4: Why did standard UDP DNS queries occasionally experience timeouts during testing?
**Answer**: The two MacBooks operated on a shared campus Wi-Fi network. Many enterprise wireless access points implement multicast/broadcast suppression and rate-limit UDP packets between wireless clients. When we forced DNS over TCP using `dig +tcp`, resolution was instantaneous and 100% reliable, confirming that the `dnsmasq` service was healthy and the issue was Layer 2/3 wireless packet suppression.

### Q5: What happened during Extension B with DNS TTL and caching?
**Answer**: We configured a short TTL of 30 seconds in `dnsmasq`. In an isolated test harness using Python `dnslib`, we verified that records are cached, served with decremented TTLs, and expire after 30 seconds. However, capturing this live in client browsers was inconclusive because the macOS native resolver (`mDNSResponder`) implements aggressive client-side caching heuristics that do not always strictly honor low TTLs. We documented this honestly as partially completed rather than fabricating data.

### Q6: How does the macOS PF firewall differ from Linux iptables?
**Answer**: macOS PF (Packet Filter) is derived from OpenBSD PF. It evaluates rules sequentially and applies the last matching rule unless the `quick` keyword is specified (`pass in quick`). In our implementation, we used anchors (`com.local.backend-isolation`) to isolate our custom rules without modifying system configuration in `/etc/pf.conf`, and used `block return` to send an active TCP RST rather than silently dropping packets.
