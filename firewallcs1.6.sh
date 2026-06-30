#!/bin/bash

echo "=== Instalando ipset e iptables-persistent ==="
apt update
apt install ipset iptables-persistent pure-ftpd -y

echo "=== Configurando Passive FTP ==="
echo "40110 40210" | tee /etc/pure-ftpd/conf/PassivePortRange
service pure-ftpd restart

echo "=== Limpando regras ==="
iptables -F
iptables -X
iptables -Z

# -------------------------

# WHITELIST

# -------------------------

ipset destroy whitelist 2>/dev/null
ipset create whitelist hash:ip -exist

#ipset add whitelist 177.54.151.114 -exist
#ipset add whitelist 177.54.151.234 -exist

# -------------------------

# ORDEM CORRETA

# -------------------------

# Loopback

iptables -A INPUT -i lo -j ACCEPT

# Conexões válidas

iptables -A INPUT -m conntrack --ctstate ESTABLISHED,RELATED -j ACCEPT

# Invalid

iptables -A INPUT -m conntrack --ctstate INVALID -j DROP

# Whitelist

iptables -A INPUT -m set --match-set whitelist src -j ACCEPT

# Ping

iptables -A INPUT -p icmp --icmp-type echo-request -j ACCEPT

# -------------------------

# PROTEÇÕES CS 1.6

# -------------------------

# Challenge flood

iptables -A INPUT -p udp --dport 27015:27900 -m string --string "getchallenge" --algo bm -m hashlimit --hashlimit 80/sec --hashlimit-burst 160 --hashlimit-mode srcip --hashlimit-name challenge -j ACCEPT
iptables -A INPUT -p udp --dport 27015:27900 -m string --string "getchallenge" --algo bm -j DROP

# Pacotes pequenos (VSE flood)

iptables -A INPUT -p udp --dport 27015:27900 -m length --length 0:12 -m hashlimit --hashlimit 80/sec --hashlimit-burst 160 --hashlimit-mode srcip --hashlimit-name vse -j ACCEPT
iptables -A INPUT -p udp --dport 27015:27900 -m length --length 0:12 -j DROP

# Flood geral UDP

iptables -A INPUT -p udp --dport 27015:27900 -m hashlimit --hashlimit 250/sec --hashlimit-burst 500 --hashlimit-mode srcip --hashlimit-name cs16 -j ACCEPT
iptables -A INPUT -p udp --dport 27015:27900 -j DROP

# -------------------------

# LIBERAÇÕES TCP (SEU ORIGINAL)

# -------------------------

iptables -A INPUT -p tcp --dport 21 -j ACCEPT
iptables -A INPUT -p tcp --dport 22 -j ACCEPT
iptables -A INPUT -p tcp --dport 2222 -j ACCEPT
iptables -A INPUT -p tcp --dport 2121 -j ACCEPT
iptables -A INPUT -p tcp --dport 443 -j ACCEPT
iptables -A INPUT -p tcp --dport 80 -j ACCEPT
iptables -A INPUT -p tcp --dport 3306 -j ACCEPT
iptables -A INPUT -p tcp --dport 12680 -j ACCEPT
iptables -A INPUT -p tcp --dport 8888 -j ACCEPT
iptables -A INPUT -p tcp --dport 8080 -j ACCEPT
iptables -A INPUT -p tcp --dport 8989 -j ACCEPT

# Passive FTP (SEU ORIGINAL)

iptables -A INPUT -p tcp --dport 40110:40210 -j ACCEPT

# -------------------------

# DNS saída

# -------------------------

iptables -A OUTPUT -p udp --dport 53 -j ACCEPT
iptables -A OUTPUT -p tcp --dport 53 -j ACCEPT

# Política padrão

iptables -P INPUT DROP
iptables -P FORWARD DROP
iptables -P OUTPUT ACCEPT

# Salvar regras

iptables-save > /etc/iptables/rules.v4

echo "=== Firewall + Anti-DDoS + FTP Passive ativo ==="
