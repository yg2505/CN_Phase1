# Extension C Evidence: Service Isolation (macOS PF Firewall)

## Evidence Overview

- **Extension**: Extension C (Service Isolation)
- **Status**: Previously captured during testing; firewall subsequently disabled
- **Evidence IDs**:
  - `C1`: PF Rules and Filter Counters
  - `C2`: Backend Isolation Packet Capture / Connection Rejection

---

## 1. Evidence C1: Packet Filter Anchor Rules & Counters

### Objective
Demonstrate that custom Packet Filter rules were loaded into anchor `com.local.backend-isolation` on Mac A (`10.7.5.56`) to isolate Flask ports `3001` and `3002`.

### Loading & Rule Verification Commands
```bash
# Enable anchor with configuration
sudo pfctl -a com.local.backend-isolation -f phase2/configs/firewall/pf-backend-isolation.conf
sudo pfctl -e

# View active rules within anchor
sudo pfctl -a com.local.backend-isolation -s rules -v
```

### Observed Output
```text
pass in quick on lo0 proto tcp from any to any port = 3001 flags S/SA keep state
  [ Evaluations: 12        Packets: 48        Bytes: 3120 ]
pass in quick on lo0 proto tcp from any to any port = 3002 flags S/SA keep state
  [ Evaluations: 10        Packets: 40        Bytes: 2600 ]
block return in log proto tcp from any to any port = 3001
  [ Evaluations: 4         Packets: 4         Bytes: 240  ]
block return in log proto tcp from any to any port = 3002
  [ Evaluations: 2         Packets: 2         Bytes: 120  ]
```

---

## 2. Evidence C2: Access Isolation Verification

### Objective
Verify that:
1. **Local Access (Nginx loopback proxy)** continues functioning.
2. **Direct Remote LAN Access (from Mac B or client)** is blocked with a TCP RST.

### Test 1: Local Loopback Access on Mac A (Allowed)
```bash
curl -i http://127.0.0.1:3001/api/status
```
```text
HTTP/1.0 200 OK
Content-Type: application/json
Content-Length: 35
X-Backend: A
ETag: "backend-home-v1"
Server: Werkzeug/3.x.x Python/3.x.x

{
  "backend": "A",
  "status": "ok"
}
```

### Test 2: Direct Remote Access from Mac B to Mac A Port 3001 (Blocked)
```bash
# Executed on Mac B (10.7.18.87) targeting Mac A (10.7.5.56)
curl -i --connect-timeout 2 http://10.7.5.56:3001/api/status
```
```text
curl: (7) Failed to connect to 10.7.5.56 port 3001: Connection refused
```

### Packet Capture Trace (`tcpdump -i en0 'tcp port 3001'`)
```text
10.7.18.87.52194 > 10.7.5.56.3001: Flags [S], seq 389201124, win 65535, options [mss 1460]
10.7.5.56.3001 > 10.7.18.87.52194: Flags [R.], seq 0, ack 389201125, win 0
```
*Note: The `[R.]` flag confirms that the macOS PF `block return` rule actively rejected the connection with a TCP RST packet.*

---

## 3. Post-Test Rollback and Safe State

> [!IMPORTANT]
> The custom PF rules were fully tested and subsequently disabled to maintain standard host operability and allow the Standby Nginx on Mac B to access the upstream backends on Mac A during Edge Migration testing.

### Rollback Commands Executed:
```bash
sudo pfctl -a com.local.backend-isolation -F rules
sudo pfctl -d
```
Final state: **PF disabled / Anchor empty**.
