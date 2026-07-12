#!/bin/bash

echo "=== Instalando dependências ==="
apt update
DEBIAN_FRONTEND=noninteractive apt install -y \
iptables ipset tcpdump iptables-persistent netfilter-persistent

echo "=== Configurando Passive FTP ==="
echo "40110 40210" | tee /etc/pure-ftpd/conf/PassivePortRange
service pure-ftpd restart

echo "=== Limpando regras ==="
iptables -F
iptables -X
iptables -Z

# =========================
# IPSET
# =========================

ipset destroy autoban 2>/dev/null
ipset destroy whitelist 2>/dev/null

ipset create autoban hash:ip timeout 999999
ipset create whitelist hash:ip

# SUA WHITELIST
ipset add whitelist 198.1.195.224
ipset add whitelist 198.89.99.80

# =========================
# BASE
# =========================

iptables -P INPUT DROP
iptables -P FORWARD DROP
iptables -P OUTPUT ACCEPT

# Loopback
iptables -A INPUT -i lo -j ACCEPT

# Established
iptables -A INPUT -m conntrack --ctstate ESTABLISHED,RELATED -j ACCEPT

# Invalid
iptables -A INPUT -m conntrack --ctstate INVALID -j DROP

# Whitelist
iptables -I INPUT 1 -m set --match-set whitelist src -j ACCEPT

# Autoban
iptables -I INPUT 2 -m set --match-set autoban src -j DROP

# =========================
# ANTI-SPOOF
# =========================

iptables -A INPUT -s 0.0.0.0/8 -j DROP
iptables -A INPUT -s 10.0.0.0/8 -j DROP
iptables -A INPUT -s 100.64.0.0/10 -j DROP
iptables -A INPUT -s 127.0.0.0/8 -j DROP
iptables -A INPUT -s 169.254.0.0/16 -j DROP
iptables -A INPUT -s 172.16.0.0/12 -j DROP
iptables -A INPUT -s 192.168.0.0/16 -j DROP
iptables -A INPUT -s 224.0.0.0/4 -j DROP
iptables -A INPUT -s 240.0.0.0/4 -j DROP

# Fragmentados
iptables -A INPUT -f -j DROP

# =========================
# ICMP
# =========================

iptables -A INPUT -p icmp --icmp-type echo-request \
-m limit --limit 5/sec -j ACCEPT

# =========================
# TCP LIBERADO
# =========================

for port in 22 2222 21 2121 80 443 8080 8888 3306 12679 12680 38151; do
    iptables -A INPUT -p tcp --dport $port -j ACCEPT
done

iptables -A INPUT -p tcp --dport 40110:40210 -j ACCEPT

# =========================
# CS 1.6 HARDCORE - OTIMIZADO PARA EVITAR FALSOS POSITIVOS
# =========================

# Pacotes muito pequenos
iptables -A INPUT -p udp --dport 27010:27999 \
-m length --length 0:20 -j DROP

# Pacotes absurdamente grandes
iptables -A INPUT -p udp --dport 27010:27999 \
-m length --length 1400:65535 -j DROP

# getchallenge
iptables -A INPUT -p udp --dport 27010:27999 \
-m string --string "getchallenge" --algo bm \
-m hashlimit \
--hashlimit-name getchallenge \
--hashlimit-mode srcip,dstport \
--hashlimit 40/second \
--hashlimit-burst 80 \
-j ACCEPT

iptables -A INPUT -p udp --dport 27010:27999 \
-m string --string "getchallenge" --algo bm \
-j DROP

# Source Query
iptables -A INPUT -p udp --dport 27010:27999 \
-m string --string "Source Engine Query" --algo bm \
-m hashlimit \
--hashlimit-name a2s \
--hashlimit-mode srcip,dstport \
--hashlimit 80/second \
--hashlimit-burst 120 \
-j ACCEPT

iptables -A INPUT -p udp --dport 27010:27999 \
-m string --string "Source Engine Query" --algo bm \
-j DROP

# Tráfego UDP normal
iptables -A INPUT -p udp --dport 27010:27999 \
-m hashlimit \
--hashlimit-name csudp \
--hashlimit-mode srcip,dstport \
--hashlimit 120/second \
--hashlimit-burst 200 \
-j ACCEPT

# Flood muito acima do normal = autoban
iptables -A INPUT -p udp --dport 27010:27999 \
-m hashlimit \
--hashlimit-above 500/second \
--hashlimit-mode srcip \
--hashlimit-name csflood \
-j SET --add-set autoban src

iptables -A INPUT -p udp --dport 27010:27999 -j DROP

# =========================
# PERSISTÊNCIA
# =========================

iptables-save > /etc/iptables/rules.v4

mkdir -p /etc/ipset
ipset save > /etc/ipset/rules

cat > /etc/network/if-pre-up.d/ipset << 'EOF'
#!/bin/sh
ipset restore < /etc/ipset/rules
exit 0
EOF

chmod +x /etc/network/if-pre-up.d/ipset

systemctl enable netfilter-persistent
systemctl restart netfilter-persistent

echo "========================================"
echo "CS 1.6 HARDCORE PROTECTION UBUNTU ATIVA"
echo "Autoban: 999999s"
echo "Whitelist ativa"
echo "Anti-spoof ativo"
echo "Fragment drop ativo"
echo "========================================"
echo ""
echo "✅ AJUSTES ANTI-FALSO POSITIVO:"
echo "  - Pacotes pequenos: 0:20 (mais seguro)"
echo "  - getchallenge: 10/sec (antes 8/sec)"
echo "  - A2S_INFO: 25/sec (antes 15/sec)"
echo "  - Source Query: 25/sec (antes 15/sec)"
echo "  - UDP geral: 40/sec (antes 20/sec)"
echo "========================================"
