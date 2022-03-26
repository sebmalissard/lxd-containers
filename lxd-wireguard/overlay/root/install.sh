#/bin/sh

echo "Install packages..."
apk update
apk upgrade
apk add wireguard-tools

echo "Enable IP forwarding..."
echo "net.ipv4.ip_forward = 1" >> "/etc/sysctl.d/local.conf"

echo "Set correct permission to wg0.conf"
chmod 660 "/etc/wireguard/wg0.conf"
chmod 755 "/etc/init.d/wg-quick"
chown root:root "/etc/init.d/wg-quick"

echo "Enable wg-quick service"
rc-update add wg-quick default
