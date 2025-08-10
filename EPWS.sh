#!/bin/bash
#!/bin/bash

# Colores
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m' # Sin color

clear
echo -e "${CYAN}"
echo "███████╗██████╗ ██╗    ██╗███████╗"
echo "██╔════╝██╔══██╗██║    ██║██╔════╝"
echo "█████╗  ██████╔╝██║ █╗ ██║███████╗"
echo "██╔══╝  ██╔══██╗██║███╗██║╚════██║"
echo "███████╗██║  ██║╚███╔███╔╝███████║"
echo "╚══════╝╚═╝  ╚═╝ ╚══╝╚══╝ ╚══════╝"
echo -e "${YELLOW}      E   P   W   S${NC}"
echo ""
echo -e "${GREEN}🚀 Easy Pizi Wifi Squeeze 🚀${NC}"
echo -e "${CYAN}Creado para levantar AP's fácil y rápido${NC}"
echo ""
sleep 1

# ===============================
# CONFIGURACIÓN GENERAL
# ===============================
INTERFACE="wlan0" # Cambia por tu interfaz que levantará el AP
INTERNET_IF="enp0s20f0u2" # Cambia por tu interfaz real de salida
AP_IP="192.168.50.1"
DHCP_RANGE_START="192.168.50.10"
DHCP_RANGE_END="192.168.50.50"
DHCP_LEASE_TIME="12h"
DNS_SERVER="1.1.1.1"
SSID="Mi_AP_2"
HOSTAPD_CONF="/tmp/hostapd_ap.conf"
DNSMASQ_CONF="/tmp/dnsmasq_ap.conf"
DEPENDENCIAS="hostapd dnsmasq iptables iw net-tools wireless_tools"

# ===============================
# FUNCIÓN: DETECTAR GESTOR E INSTALAR
# ===============================
instalar_dependencias() {
    echo "[+] Detectando gestor de paquetes..."
    if command -v pacman >/dev/null 2>&1; then
        echo "[+] Detectado sistema con pacman (Arch-based)"
        sudo pacman -Sy --needed $DEPENDENCIAS
    elif command -v apt >/dev/null 2>&1; then
        echo "[+] Detectado sistema con apt (Debian/Ubuntu-based)"
        sudo apt update
        sudo apt install -y $DEPENDENCIAS
    elif command -v dnf >/dev/null 2>&1; then
        echo "[+] Detectado sistema con dnf (Fedora/RHEL-based)"
        sudo dnf install -y $DEPENDENCIAS
    elif command -v yum >/dev/null 2>&1; then
        echo "[+] Detectado sistema con yum (CentOS/RHEL-based)"
        sudo yum install -y $DEPENDENCIAS
    elif command -v zypper >/dev/null 2>&1; then
        echo "[+] Detectado sistema con zypper (OpenSUSE-based)"
        sudo zypper install -y $DEPENDENCIAS
    else
        echo "[X] No se reconoce el gestor de paquetes."
        echo "Instala manualmente: $DEPENDENCIAS"
        exit 1
    fi
}

# ===============================
# FUNCIÓN: LIMPIEZA AL SALIR
# ===============================
cleanup() {
    echo -e "\n[!] Ctrl+C detectado: apagando AP y restaurando configuración..."
    kill "$DNSMASQ_PID" 2>/dev/null
    kill "$HOSTAPD_PID" 2>/dev/null
    ip addr flush dev $INTERFACE
    ip link set $INTERFACE down

    echo "[+] Limpiando reglas iptables y desactivando IP forwarding..."
    iptables -t nat -F
    iptables -F
    iptables -P INPUT ACCEPT
    iptables -P OUTPUT ACCEPT
    iptables -P FORWARD ACCEPT
    sysctl -w net.ipv4.ip_forward=0 > /dev/null

    echo "[+] Reiniciando servicios NetworkManager y systemd-resolved..."
    systemctl start NetworkManager
    systemctl start systemd-resolved

    echo "[+] AP apagado. Saliendo."
    exit 0
}
trap cleanup SIGINT

# ===============================
# MAIN
# ===============================

# Verificar privilegios root
if [ "$EUID" -ne 0 ]; then
    echo "[!] Este script necesita privilegios de root. Solicitando con sudo..."
    exec sudo bash "$0" "$@"
fi

# Instalar dependencias
instalar_dependencias

echo "[+] Parando NetworkManager y systemd-resolved..."
systemctl stop NetworkManager
systemctl stop systemd-resolved

echo "[+] Configurando IP estática en $INTERFACE..."
ip link set $INTERFACE up
ip addr flush dev $INTERFACE
ip addr add $AP_IP/24 dev $INTERFACE

# Preguntar si será con contraseña
read -p "[?] ¿Quieres que el AP tenga contraseña? (s/n): " RESP
if [[ "$RESP" =~ ^[Ss]$ ]]; then
    read -s -p "[+] Introduce la contraseña para el AP: " AP_PASS
    echo
    cat > $HOSTAPD_CONF <<EOF
interface=$INTERFACE
driver=nl80211
ssid=$SSID
hw_mode=g
channel=6
auth_algs=1
ignore_broadcast_ssid=0
wpa=2
wpa_passphrase=$AP_PASS
wpa_key_mgmt=WPA-PSK
rsn_pairwise=CCMP
EOF
else
    cat > $HOSTAPD_CONF <<EOF
interface=$INTERFACE
driver=nl80211
ssid=$SSID
hw_mode=g
channel=6
auth_algs=1
ignore_broadcast_ssid=0
EOF
fi

echo "[+] Creando configuración dnsmasq..."
cat > $DNSMASQ_CONF <<EOF
interface=$INTERFACE
dhcp-range=$DHCP_RANGE_START,$DHCP_RANGE_END,$DHCP_LEASE_TIME
dhcp-option=3,$AP_IP
dhcp-option=6,$DNS_SERVER
server=$DNS_SERVER
log-dhcp
log-queries
EOF

echo "[+] Activando IP forwarding..."
sysctl -w net.ipv4.ip_forward=1 > /dev/null

echo "[+] Configurando iptables para NAT y permitir tráfico..."
iptables -t nat -F
iptables -F
iptables -t nat -A POSTROUTING -o $INTERNET_IF -j MASQUERADE
iptables -A FORWARD -i $INTERNET_IF -o $INTERFACE -m state --state RELATED,ESTABLISHED -j ACCEPT
iptables -A FORWARD -i $INTERFACE -o $INTERNET_IF -j ACCEPT
iptables -A INPUT -i $INTERFACE -p udp --dport 67 -j ACCEPT
iptables -A INPUT -i $INTERFACE -p udp --dport 53 -j ACCEPT

echo "[+] Levantando dnsmasq..."
dnsmasq --conf-file=$DNSMASQ_CONF --no-daemon --log-facility=- &
DNSMASQ_PID=$!

echo "[+] Levantando hostapd..."
hostapd $HOSTAPD_CONF > /dev/null 2>&1 &
HOSTAPD_PID=$!

echo "[+] AP activo. Presiona Ctrl+C para apagarlo."

# Esperar indefinidamente
while true; do
    sleep 1
done

