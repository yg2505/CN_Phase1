# Extension D Evidence: High Availability Failover

## Evidence Overview

- **Extension**: Extension D (High Availability Failover)
- **Status**: Previously Demonstrated in Phase 1 / Phase 1 Evidence Required
- **Evidence ID**: `D1` (Backend Failover under Nginx Passive Health Check)

---

## 1. High Availability Architecture & Mechanism

The project uses open-source Nginx reverse proxying to manage two upstream Flask backends running on Mac A:
- `Backend A` (`127.0.0.1:3001`)
- `Backend B` (`127.0.0.1:3002`)

### Health Check Mechanism: Passive Health Checks
Open-source Nginx does **not** perform active background synthetic HTTP polling (which is an NGINX Plus proprietary feature). Instead, high availability is achieved through **passive health monitoring**:
- Directives: `server ... max_fails=1 fail_timeout=10s;`
- Failover directive: `proxy_next_upstream error timeout http_502 http_503 http_504;`

When an incoming client request is routed to an upstream backend that fails (e.g. process terminated, socket connection refused, or timed out), Nginx:
1. Catches the error instantly.
2. Marks that specific backend server as unviable for `fail_timeout` (10 seconds).
3. Immediately dispatches the *same* client request to the next available server in the upstream pool (`proxy_next_upstream`).
4. The client receives a transparent `200 OK` response with no interruption or `502 Bad Gateway` error.

---

## 2. Evidence D1: Demonstration Log

### Test Procedure:
1. Start both Backend A (`:3001`) and Backend B (`:3002`).
2. Run a continuous curl loop querying `/api/status` through Nginx.
3. Terminate Backend A (`Ctrl + C` in Terminal 1).
4. Observe the continuous stream of responses: traffic seamlessly transitions to `X-Backend: B`.
5. Restart Backend A: after `fail_timeout` expires, Nginx resumes round-robin distribution between A and B.

### Curl Loop Command:
```bash
for i in {1..10}; do
    curl -s http://localhost:8081/api/status | grep -o '"backend":"[AB]"'
    sleep 0.5
done
```

### Observed Transition Output:
```text
"backend":"A"
"backend":"B"
"backend":"A"
[Backend A Terminated via Ctrl+C on Port 3001]
"backend":"B"
"backend":"B"
"backend":"B"
"backend":"B"
[Backend A Restarted on Port 3001]
"backend":"B"
"backend":"A"
"backend":"B"
```

---
