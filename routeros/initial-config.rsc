# =============================================================
# MikroTik CHR - Initial Bootstrap Configuration
# Role: VPN Gateway for CentOS Backend Services
# =============================================================
# Jalankan script ini via:
#   - Winbox: New Terminal > /import file=initial-config.rsc
#   - SSH: /import file=initial-config.rsc
#   - API: setelah container up
# =============================================================

# --- System Identity ---
/system identity set name=CHR-VPN-Gateway

# --- Interface Naming ---
# eth0 = Management (mgmt network - 172.20.0.0/24)
# eth1 = Internal (internal network - 192.168.100.0/24)
/interface set ether1 name=mgmt
/interface set ether2 name=internal

# --- IP Addresses ---
/ip address add address=172.20.0.2/24 interface=mgmt comment="Management"
/ip address add address=192.168.100.1/24 interface=internal comment="Internal LAN"

# --- Default Route via Management Gateway ---
/ip route add dst-address=0.0.0.0/0 gateway=172.20.0.1 comment="Default via mgmt"

# --- DNS ---
/ip dns set servers=8.8.8.8,1.1.1.1 allow-remote-requests=yes

# =============================================================
# FIREWALL
# =============================================================

# Filter rules
/ip firewall filter

# Allow established/related
add chain=input connection-state=established,related action=accept comment="Allow established"
add chain=forward connection-state=established,related action=accept

# Allow from management network
add chain=input src-address=172.20.0.0/24 action=accept comment="Allow mgmt network"

# Allow VPN protocols from WAN
add chain=input protocol=udp dst-port=51820 action=accept comment="WireGuard"
add chain=input protocol=udp dst-port=500,4500 action=accept comment="IPSec IKE/NAT-T"
add chain=input protocol=udp dst-port=1701 action=accept comment="L2TP"
add chain=input protocol=tcp dst-port=1723 action=accept comment="PPTP"
add chain=input protocol=tcp dst-port=443 action=accept comment="SSTP"

# Allow Winbox & API
add chain=input protocol=tcp dst-port=8291 action=accept comment="Winbox"
add chain=input protocol=tcp dst-port=8728,8729 action=accept comment="API"

# Allow ICMP
add chain=input protocol=icmp action=accept comment="ICMP"

# Drop everything else to router
add chain=input action=drop comment="Drop all other input"

# Allow VPN clients to reach internal network
add chain=forward src-address=10.0.0.0/8 dst-address=192.168.100.0/24 action=accept comment="VPN to internal"
add chain=forward src-address=192.168.100.0/24 dst-address=10.0.0.0/8 action=accept comment="Internal to VPN"

# Drop direct access to internal from outside (bukan via VPN)
add chain=forward dst-address=192.168.100.0/24 action=drop comment="Block direct to internal"

# NAT
/ip firewall nat
add chain=srcnat src-address=10.0.0.0/8 out-interface=internal action=masquerade comment="VPN clients NAT to internal"

# =============================================================
# VPN POOLS (siap pakai, client pilih protocol)
# =============================================================

/ip pool
add name=vpn-pool ranges=10.10.10.2-10.10.10.254 comment="VPN client IP pool"

# =============================================================
# WIREGUARD (aktifkan jika dipilih client)
# =============================================================
# /interface wireguard add name=wg0 listen-port=51820 comment="WireGuard VPN"
# /ip address add address=10.10.10.1/24 interface=wg0
# Tambahkan peer:
# /interface wireguard peers add interface=wg0 public-key="<CLIENT_PUBKEY>" allowed-address=10.10.10.x/32

# =============================================================
# L2TP/IPSec (aktifkan jika dipilih client)
# =============================================================
# /interface l2tp-server server set enabled=yes use-ipsec=yes ipsec-secret=<SECRET> default-profile=default
# /ppp secret add name=<USERNAME> password=<PASSWORD> service=l2tp local-address=10.10.10.1 remote-address=10.10.10.2

# =============================================================
# PPTP (aktifkan jika dipilih client)
# =============================================================
# /interface pptp-server server set enabled=yes
# /ppp secret add name=<USERNAME> password=<PASSWORD> service=pptp local-address=10.10.10.1 remote-address=10.10.10.2

# =============================================================
# SSTP (aktifkan jika dipilih client)
# =============================================================
# /interface sstp-server server set enabled=yes certificate=none

# =============================================================
# SERVICES - nonaktifkan yang tidak perlu
# =============================================================
/ip service
set telnet disabled=yes
set ftp disabled=yes
set www disabled=yes
set ssh address=172.20.0.0/24
set api address=172.20.0.0/24
set winbox address=172.20.0.0/24
set api-ssl address=172.20.0.0/24

# =============================================================
# NTP Client
# =============================================================
/system ntp client set enabled=yes server-dns-names=pool.ntp.org

# =============================================================
# Logging
# =============================================================
/system logging
add topics=vpn action=memory comment="Log VPN events"
add topics=firewall action=memory comment="Log firewall events"

:log info "CHR VPN Gateway initial config applied successfully"
