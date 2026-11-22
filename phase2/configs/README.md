# Phase 2 Configuration Bundle Guide

## 1. Directory Structure

```text
phase2/configs/
├── README.md                      # This deployment and parameters guide
├── dnsmasq/
│   ├── primary-dnsmasq.conf       # Primary DNS (Mac B - 10.7.18.87)
│   └── backup-dnsmasq.conf        # Backup DNS (Mac A - 10.7.5.56)
├── nginx/
│   ├── original-mac-a-nginx.conf  # Original edge proxy (Mac A - 10.7.5.56)
│   └── standby-mac-b-nginx.conf   # Standby edge proxy (Mac B - 10.7.18.87)
└── firewall/
    ├── pf-backend-isolation.conf  # macOS PF firewall anchor rule definition
    └── pf-setup.sh                # Automation script for loading/flushing rules
```

---

## 2. Configuration Parameters and Placeholders

The configurations in this directory represent verified examples tailored to the two project hosts.

| Variable / Placeholder | Description | Concrete Value |
|---|---|---|
| `<MAC_A_IP>` | IPv4 address of Mac A | `10.7.5.56` |
| `<MAC_B_IP>` | IPv4 address of Mac B | `10.7.18.87` |
| `<DOMAIN_ROOT>` | Private authoritative root | `my_team.test` |
| `<APP_HOST>` | Application frontend hostname | `app.my_team.test` |
| `<API_HOST>` | API service hostname | `api.my_team.test` |
| `<EDGE_PORT>` | Nginx listening HTTP port | `8081` |
| `<BACKEND_A_PORT>` | Flask Backend A port | `3001` |
| `<BACKEND_B_PORT>` | Flask Backend B port | `3002` |

---

## 3. Deployment Instructions

### A. Deploying DNS Resolvers (`dnsmasq`)

#### On Mac B (Primary Resolver: `10.7.18.87`):
1. Install `dnsmasq` via Homebrew:
   ```bash
   brew install dnsmasq
   ```
2. Validate configuration syntax:
   ```bash
   dnsmasq --test -C phase2/configs/dnsmasq/primary-dnsmasq.conf
   ```
3. Start the service:
   ```bash
   sudo dnsmasq -C phase2/configs/dnsmasq/primary-dnsmasq.conf -d
   ```

#### On Mac A (Backup Resolver: `10.7.5.56`):
1. Validate configuration syntax:
   ```bash
   dnsmasq --test -C phase2/configs/dnsmasq/backup-dnsmasq.conf
   ```
2. Start the service:
   ```bash
   sudo dnsmasq -C phase2/configs/dnsmasq/backup-dnsmasq.conf -d
   ```

---

### B. Deploying Nginx Edge Proxies

#### On Mac A (Original Edge: `10.7.5.56`):
1. Test configuration:
   ```bash
   nginx -t -c $(pwd)/phase2/configs/nginx/original-mac-a-nginx.conf
   ```
2. Start Nginx:
   ```bash
   sudo nginx -c $(pwd)/phase2/configs/nginx/original-mac-a-nginx.conf
   ```

#### On Mac B (Standby Edge: `10.7.18.87`):
1. Test configuration:
   ```bash
   nginx -t -c $(pwd)/phase2/configs/nginx/standby-mac-b-nginx.conf
   ```
2. Start Nginx:
   ```bash
   sudo nginx -c $(pwd)/phase2/configs/nginx/standby-mac-b-nginx.conf
   ```

---

### C. Applying macOS PF Firewall Isolation

> [!WARNING]
> **Safety Notice**: PF rules directly affect packet processing in the macOS kernel. The custom rules are contained inside anchor `com.local.backend-isolation` to avoid mutating system rules in `/etc/pf.conf`. After testing, always disable the anchor.

1. Make setup script executable:
   ```bash
   chmod +x phase2/configs/firewall/pf-setup.sh
   ```
2. Enable isolation anchor:
   ```bash
   sudo ./phase2/configs/firewall/pf-setup.sh enable
   ```
3. Inspect active rules and counters:
   ```bash
   sudo ./phase2/configs/firewall/pf-setup.sh status
   ```
4. Rollback and disable firewall:
   ```bash
   sudo ./phase2/configs/firewall/pf-setup.sh disable
   ```
