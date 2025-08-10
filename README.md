# Easy Pizi Wifi Squeeze (EPWS)

    🐧 Levanta y controla un punto de acceso WiFi en Linux de forma sencilla y rápida.

## Descripción

Easy Pizi Wifi Squeeze (EPWS) es un script para crear un punto de acceso WiFi (AP) con tu adaptador inalámbrico en Linux.
Automatiza la configuración de hostapd, dnsmasq, reglas de iptables y control de servicios (NetworkManager, systemd-resolved).

Ideal para crear un AP abierto o protegido con contraseña WPA2, con DHCP y NAT para compartir conexión a internet.
Características

    Compatible con distros basadas en Arch y Debian (próximamente más)

    Configuración fácil: SSID, contraseña opcional y parámetros DHCP ajustables

    Manejo automático de servicios y reglas iptables

    Scripts para iniciar y detener el AP correctamente

    Muestra una introducción amigable al iniciar

## Requisitos

    Adaptador WiFi con soporte modo AP (nl80211 compatible)

    hostapd

    dnsmasq

    iptables

    bash

    sudo

## MODO DE EMPLEO
Ejecuta el script, instalará dependencias en caso de ser necesario, y luego creará el AP. Te preguntará si quieres proteger el AP con contraseña o dejarlo abierto.
```bash
chmod +x EPWS.sh
bash EPWS.sh
```

Para detener el punto de acceso, simplemente presiona Ctrl + C. El script limpiará y restaurará la configuración original.
Configuración

Puedes modificar variables dentro del script para adaptar:

    Interfaz WiFi (INTERFACE)

    Interfaz de salida a internet (INTERNET_IF)

    SSID (SSID)

    Rango DHCP (DHCP_RANGE_START, DHCP_RANGE_END)

    Servidor DNS (DNS_SERVER)

## Notas

    El script detiene temporalmente NetworkManager y systemd-resolved para evitar conflictos con dnsmasq.

    Usa sudo para privilegios root.

    Funciona mejor en adaptadores y drivers compatibles con modo AP (nl80211).

## Contribuciones

Pull requests y sugerencias son bienvenidas.
Licencia

MIT License © 2025 Easy Pizi Wifi Squeeze
