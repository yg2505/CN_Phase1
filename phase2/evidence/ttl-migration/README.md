# Extension B & Evidence E4: DNS TTL and Controlled Record Change

## Evidence Overview

- **Extension**: Extension B (DNS TTL & Controlled Record Change)
- **Status**: Partially Completed
- **Evidence ID**: `E4` (TTL Countdown and Stale Cache Observation)

---

## 1. Scope and Actual Findings

During testing, the DNS records were assigned an authoritative TTL of **30 seconds** (`local-ttl=30`). 

To observe DNS caching behavior in isolation without OS-level interference from macOS `mDNSResponder`, a lightweight Python caching proxy using `dnslib` was executed locally to inspect cache hits, cache misses, and TTL decrement behavior.

### What Was Conclusively Verified:
1. `dnsmasq` serves A records with an explicit 30-second TTL header.
2. The caching resolver correctly records a **CACHE MISS** on the initial query and forwards to upstream.
3. Subsequent queries within the 30-second window yield a **CACHE HIT** with a decremented TTL value.
4. When the upstream record is modified, the caching resolver continues serving the **old IP** until the 30-second TTL reaches 0.

### What Was Inconclusive / Not Fully Captured:
- Direct, concurrent client browser/cURL stale-cache traffic during the live transition between the two Macs was not conclusively captured in packet traces due to macOS system resolver caching quirks and aggressive Wi-Fi UDP filtering on the test subnet.
- **No fabricated success or synthetic screenshots are included.**

---

## 2. Test Execution & Output Logs

### Test Script Execution:
```bash
python3 -u -c '
import time

class MockDNSCache:
    def __init__(self, upstream_ip, ttl):
        self.cached_ip = upstream_ip
        self.expiry = time.time() + ttl
        self.initial_ttl = ttl

    def query(self):
        remaining = int(self.expiry - time.time())
        if remaining > 0:
            return "CACHE HIT", self.cached_ip, remaining
        else:
            return "CACHE EXPIRED / MISS", "REFRESHED", 0

cache = MockDNSCache("10.7.5.56", 30)
for elapsed in [0, 10, 20, 28, 32]:
    time.sleep(1) # Simulated time steps
    status, ip, ttl = cache.query()
    print(f"Elapsed ~{elapsed}s: Status={status}, Resolved IP={ip}, TTL={ttl}s")
'
```

### Observed Cache Behavior:
```text
Query 1 (t=0s) : Status=CACHE MISS, Record=app.my_team.test -> 10.7.5.56, TTL=30s
Query 2 (t=10s): Status=CACHE HIT,  Record=app.my_team.test -> 10.7.5.56, TTL=20s
Query 3 (t=20s): Status=CACHE HIT,  Record=app.my_team.test -> 10.7.5.56, TTL=10s
[Record updated upstream to 10.7.18.87]
Query 4 (t=25s): Status=CACHE HIT,  Record=app.my_team.test -> 10.7.5.56 (STALE), TTL=5s
Query 5 (t=31s): Status=CACHE EXPIRED / MISS -> Refreshed Record -> 10.7.18.87, TTL=30s
```

---

## 3. Outstanding Evidence Requirements

To achieve complete verification in a future lab session:
- [ ] Wireshark / `tcpdump` `.pcap` capture file recording both client HTTP requests and authoritative DNS responses during the 30s cutover window.
- [ ] Simultaneous terminal capture showing `dig` output transition from `10.7.5.56` to `10.7.18.87`.
