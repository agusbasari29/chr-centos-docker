# CHR + CentOS Docker Stack

MikroTik CHR sebagai VPN Gateway dengan CentOS sebagai backend services, berjalan di Docker.

## Arsitektur

```
Internet / Client VPN
        │
        ▼
┌───────────────────┐
│  MikroTik CHR     │  ← VPN Gateway (WireGuard/L2TP/PPTP/SSTP)
│  172.20.0.2       │  ← Management (Winbox/API)
│  192.168.100.1    │  ← Internal Gateway
└────────┬──────────┘
         │ internal network (isolated)
         ▼
┌───────────────────┐
│  CentOS Backend   │
│  192.168.100.10   │  ← Hanya bisa diakses via VPN
└───────────────────┘
```

## Requirement VPS

- OS: Ubuntu 20.04+ / Debian 11+ / CentOS 8+
- RAM: minimal 1GB (CHR butuh ~256MB, CentOS ~256MB)
- Docker: 20.10+
- Docker Compose: v2+
- Port yang perlu dibuka di firewall VPS:
  - `8291/tcp` — Winbox
  - `51820/udp` — WireGuard
  - `500,4500/udp` — IPSec
  - `1701/udp` — L2TP
  - `1723/tcp` — PPTP
  - `443/tcp` — SSTP

## Quick Start

### 1. Clone & Konfigurasi

```bash
git clone <repo-url> chr-centos-docker
cd chr-centos-docker
```

Edit file `.env`:
```bash
nano .env
```

Wajib diubah:
```env
CHR_ADMIN_PASSWORD=password_kuat_anda
```

### 2. Build & Jalankan

```bash
docker compose up -d --build
```

### 3. Cek Status

```bash
docker compose ps
docker compose logs -f chr
```

### 4. Akses CHR

**Via Winbox:**
- IP: `<IP_VPS>:8291`
- Username: `admin`
- Password: sesuai `CHR_ADMIN_PASSWORD` di `.env`

**Via SSH:**
```bash
ssh admin@<IP_VPS> -p 22
```

**Via API:**
- `<IP_VPS>:8728` (plain)
- `<IP_VPS>:8729` (SSL)

### 5. Apply Initial Config CHR

Setelah CHR boot (tunggu ~60 detik):

```bash
# Copy config ke container
docker compose exec chr /bin/bash

# Di dalam container CHR, via terminal RouterOS:
/import file=initial-config.rsc
```

Atau via Winbox: **New Terminal** > `/import file=initial-config.rsc`

---

## Konfigurasi VPN (Pilih Salah Satu)

### WireGuard (Recommended)

Di CHR Terminal:
```routeros
# Buat interface WireGuard
/interface wireguard add name=wg0 listen-port=51820

# Set IP
/ip address add address=10.10.10.1/24 interface=wg0

# Lihat public key CHR
/interface wireguard print

# Tambah peer (client)
/interface wireguard peers add \
    interface=wg0 \
    public-key="<PUBLIC_KEY_CLIENT>" \
    allowed-address=10.10.10.2/32

# Firewall - izinkan VPN ke internal
/ip firewall nat add chain=srcnat \
    src-address=10.10.10.0/24 \
    out-interface=internal \
    action=masquerade
```

Config client WireGuard:
```ini
[Interface]
PrivateKey = <PRIVATE_KEY_CLIENT>
Address = 10.10.10.2/24
DNS = 192.168.100.1

[Peer]
PublicKey = <PUBLIC_KEY_CHR>
Endpoint = <IP_VPS>:51820
AllowedIPs = 192.168.100.0/24
PersistentKeepalive = 25
```

### L2TP/IPSec

Di CHR Terminal:
```routeros
/interface l2tp-server server set \
    enabled=yes \
    use-ipsec=yes \
    ipsec-secret=rahasia123

/ppp secret add \
    name=user1 \
    password=pass123 \
    service=l2tp \
    local-address=10.10.10.1 \
    remote-address=10.10.10.2
```

### PPTP

Di CHR Terminal:
```routeros
/interface pptp-server server set enabled=yes

/ppp secret add \
    name=user1 \
    password=pass123 \
    service=pptp \
    local-address=10.10.10.1 \
    remote-address=10.10.10.2
```

---

## Akses CentOS Backend

Setelah terhubung VPN:
```bash
# SSH ke CentOS
ssh user@192.168.100.10

# Atau akses service langsung
curl http://192.168.100.10:80
```

### Install Service di CentOS

```bash
# Masuk ke container CentOS
docker compose exec centos bash

# Install Nginx (contoh)
yum install -y nginx
systemctl start nginx

# Atau tambahkan ke supervisor
cat > /etc/supervisor.d/nginx.conf << EOF
[program:nginx]
command=/usr/sbin/nginx -g "daemon off;"
autostart=true
autorestart=true
EOF
supervisorctl reread && supervisorctl update
```

---

## Manajemen

### Stop/Start

```bash
docker compose stop
docker compose start
docker compose restart chr
```

### Lihat Logs

```bash
docker compose logs -f          # semua
docker compose logs -f chr      # hanya CHR
docker compose logs -f centos   # hanya CentOS
```

### Backup Config CHR

```bash
# Di CHR terminal
/system backup save name=backup-$(date +%Y%m%d)
/export file=config-$(date +%Y%m%d)

# Copy dari container
docker cp mikrotik-chr:/routeros/backup-<DATE>.backup ./backups/
```

### Update

```bash
docker compose pull
docker compose up -d
```

---

## Struktur File

```
chr-centos-docker/
├── docker-compose.yml      # Stack definition
├── .env                    # Konfigurasi (jangan di-commit!)
├── Dockerfile.centos       # CentOS image
├── supervisord.conf        # Supervisor config untuk CentOS
├── routeros/
│   └── initial-config.rsc  # Bootstrap config CHR
└── README.md
```

## Troubleshooting

**CHR tidak mau boot:**
```bash
docker compose logs chr
# Pastikan /dev/net/tun tersedia
ls /dev/net/tun
```

**CentOS tidak bisa akses internet:**
```bash
# Pastikan VPN sudah connect dan NAT aktif di CHR
docker compose exec centos ping 8.8.8.8
```

**Winbox tidak bisa connect:**
```bash
# Cek port 8291 terbuka
ss -tlnp | grep 8291
# Cek firewall VPS
ufw allow 8291/tcp
```
