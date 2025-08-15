#!/bin/bash
clear

# ===============================
# COLORES
# ===============================
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
echo "██╔══╝  ██╔═══╝ ██║███╗██║╚════██║"
echo "███████╗██║     ╚███╔███╔╝███████║"
echo "╚══════╝╚═╝      ╚══╝╚══╝ ╚══════╝"
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
SSID="GLMBX"
AP_DEFAULT_PASS="12345678!"
HOSTAPD_CONF="/tmp/hostapd_ap.conf"
DNSMASQ_CONF="/tmp/dnsmasq_ap.conf"
DEPENDENCIAS="hostapd dnsmasq iptables iw net-tools wireless_tools"

# ===============================
# FUNCIÓN: DETECTAR GESTOR E INSTALAR
# ===============================
instalar_dependencias() {
    echo -e "${CYAN}[i] Verificando dependencias...${NC}"
    FALTAN=()
    for pkg in $DEPENDENCIAS; do
        if ! command -v $pkg >/dev/null 2>&1; then
            FALTAN+=($pkg)
        fi
    done

    if [ ${#FALTAN[@]} -eq 0 ]; then
        echo -e "${GREEN}[✔] Todas las dependencias están instaladas${NC}"
        return
    fi

#    echo -e "${RED}[✖] Faltan dependencias: ${FALTAN[*]}${NC}"
    echo -e "${YELLOW}[i] Detectando gestor de paquetes para instalarlas...${NC}"

    if command -v pacman >/dev/null 2>&1; then
        echo -e "${YELLOW}[i] Detectado sistema con pacman (Arch-based)${NC}"
        sudo pacman -Sy --needed ${FALTAN[*]}
    elif command -v apt >/dev/null 2>&1; then
        echo -e "${YELLOW}[i] Detectado sistema con apt (Debian/Ubuntu-based)${NC}"
        sudo apt update
        sudo apt install -y ${FALTAN[*]}
    elif command -v dnf >/dev/null 2>&1; then
        echo -e "${YELLOW}[i] Detectado sistema con dnf (Fedora/RHEL-based)${NC}"
        sudo dnf install -y ${FALTAN[*]}
    elif command -v yum >/dev/null 2>&1; then
        echo -e "${YELLOW}[i] Detectado sistema con yum (CentOS/RHEL-based)${NC}"
        sudo yum install -y ${FALTAN[*]}
    elif command -v zypper >/dev/null 2>&1; then
        echo -e "${YELLOW}[i] Detectado sistema con zypper (OpenSUSE-based)${NC}"
        sudo zypper install -y ${FALTAN[*]}
    else
        echo -e "${RED}[✖] No se reconoce el gestor de paquetes.${NC}"
        echo -e "${YELLOW}[i] Instala manualmente: ${FALTAN[*]}${NC}"
        exit 1
    fi
}

# ===============================
# FUNCIÓN: LIMPIEZA AL SALIR
# ===============================
cleanup() {
    echo -e "\n${RED}[!] Ctrl+C detectado: apagando AP y restaurando configuración...${NC}"
    kill "$DNSMASQ_PID" 2>/dev/null
    kill "$HOSTAPD_PID" 2>/dev/null
    ip addr flush dev $INTERFACE
    ip link set $INTERFACE down

    echo -e "${YELLOW}[i] Limpiando reglas iptables y desactivando IP forwarding...${NC}"
    iptables -t nat -F
    iptables -F
    iptables -P INPUT ACCEPT
    iptables -P OUTPUT ACCEPT
    iptables -P FORWARD ACCEPT
    sysctl -w net.ipv4.ip_forward=0 > /dev/null

    echo -e "${YELLOW}[i] Reiniciando servicios NetworkManager y systemd-resolved...${NC}"
    systemctl start NetworkManager
    systemctl start systemd-resolved

    echo -e "${GREEN}[✔] AP apagado. Saliendo.${NC}"
    exit 0
}
trap cleanup SIGINT

# ===============================
# MAIN
# ===============================

# Verificar privilegios root
if [ "$EUID" -ne 0 ]; then
    echo -e "${RED}[!] Este script necesita privilegios de root. Solicitando con sudo...${NC}"
    exec sudo bash "$0" "$@"
fi

# Instalar dependencias
instalar_dependencias

echo -e "${YELLOW}[i] Parando NetworkManager y systemd-resolved...${NC}"
systemctl stop NetworkManager
systemctl stop systemd-resolved

echo -e "${CYAN}[i] Configurando IP estática en $INTERFACE...${NC}"
ip link set $INTERFACE up
ip addr flush dev $INTERFACE
ip addr add $AP_IP/24 dev $INTERFACE

# Preguntar si será con contraseña
read -p "[?] ¿Quieres que el AP tenga contraseña? (s/n): " RESP
if [[ "$RESP" =~ ^[Ss]$ ]]; then
    AP_PASS="$AP_DEFAULT_PASS"
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
    echo -e "${GREEN}[✔] AP: \"$SSID\"${NC}"
    echo -e "${GREEN}[✔] Contraseña: \"$AP_PASS\"${NC}"
    echo -e "${YELLOW}[i] Si quieres cambiar nombre de AP, Contraseña o demás opciones, edita EPWS.sh${NC}"
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
    echo -e "${GREEN}[✔] AP: \"$SSID\" (sin contraseña)${NC}"
fi
echo -e "${CYAN}[i] Creando configuración dnsmasq...${NC}"
cat > $DNSMASQ_CONF <<EOF
interface=$INTERFACE
bind-interfaces
dhcp-range=$DHCP_RANGE_START,$DHCP_RANGE_END,$DHCP_LEASE_TIME
dhcp-option=3,$AP_IP
dhcp-option=6,$DNS_SERVER
server=$DNS_SERVER
log-dhcp
log-queries
EOF

echo -e "${YELLOW}[i] Activando IP forwarding...${NC}"
sysctl -w net.ipv4.ip_forward=1 > /dev/null

echo -e "${YELLOW}[i] Configurando iptables para NAT y permitir tráfico...${NC}"
iptables -t nat -F
iptables -F
iptables -t nat -A POSTROUTING -o $INTERNET_IF -j MASQUERADE
iptables -A FORWARD -i $INTERNET_IF -o $INTERFACE -m state --state RELATED,ESTABLISHED -j ACCEPT
iptables -A FORWARD -i $INTERFACE -o $INTERNET_IF -j ACCEPT
iptables -A INPUT -i $INTERFACE -p udp --dport 67 -j ACCEPT
iptables -A INPUT -i $INTERFACE -p udp --dport 53 -j ACCEPT

echo -e "${YELLOW}[i] Levantando dnsmasq...${NC}"
dnsmasq --conf-file=$DNSMASQ_CONF --no-daemon --log-facility=- &
DNSMASQ_PID=$!

echo -e "${YELLOW}[i] Levantando hostapd...${NC}"
hostapd $HOSTAPD_CONF > /dev/null 2>&1 &
HOSTAPD_PID=$!

echo -e "${GREEN}[✔] AP activo. Presiona Ctrl+C para apagarlo.${NC}"

# Esperar indefinidamente
while true; do
    sleep 1
done
