#!/bin/bash -e

SCRIPT_DIR=$(dirname "${BASH_SOURCE[0]}")
source "${SCRIPT_DIR}/../tools/bash/messages.sh"
source "${SCRIPT_DIR}/../tools/bash/keepassxc.sh"

LXD_CONTAINER_NAME="wireguard"
LXD_CONTAINER_IMAGE=images:alpine/3.15

# Get VPN port
echo "What is the VPN port?"
read -r -e -p "Port: " VPN_PORT
if [ "${VPN_PORT}" -gt 65535 ]; then
    fatal "Invalid port number '${VPN_PORT}'"
fi

# Get VPN config to use
configs_list=$(ls configs)
echo "What configuration do you want install?"
echo "${configs_list}"
read -n 1 -p "Choice: " CONFIG_ID
echo
if [ ! -d "configs/${CONFIG_ID}" ]; then
    fatal "Invalid config selection. Abort"
fi

# Load VPN secrets database
keepassxc_set_error_fatal "true"
keepassxc_get_database_path_from_user
keepassxc_get_password_from_user_with_verify

# Substitute function
substitute()
{
    if ! sed -i -e "0,/${1}/s|${1}|${2}|" "${3}"; then
         fatal "Substitution failed"
    fi
}

info "Generate config file..."
tmp_config_file="/tmp/wg0.conf"
cp "configs/${CONFIG_ID}/wg0.conf" "${tmp_config_file}"
for var in $(grep -o "@.*@" /tmp/wg0.conf); do
    echo "Substitute: '${var}' ..."
    if [ "${var}" == "@vpn_port@" ]; then
        substitute "${var}" "${VPN_PORT}" ${tmp_config_file}
    elif [ "${var:0:10}" == "@keepassxc" ]; then
        secret=$(keepassxc_get_attribute "VPN WireGuard/$(echo "${var}" | awk -F[:@] '{print $3}')" "$(echo "${var}" | awk -F[:@] '{print $4}')")
	substitute "${var}" "${secret}" ${tmp_config_file}
    else
        fatal "No substitute rule found"
    fi
done

info "Create and configure container ${LXD_CONTAINER_NAME}..."
lxc launch ${LXD_CONTAINER_IMAGE} ${LXD_CONTAINER_NAME}
lxc config device add ${LXD_CONTAINER_NAME} vpnPort proxy listen=udp:0.0.0.0:${VPN_PORT} connect=udp:127.0.0.1:${VPN_PORT}
lxc config set ${LXD_CONTAINER_NAME} linux.kernel_modules wireguard

# Waiting container startup
sleep 1

info "Copy config file..."
lxc file push "overlay/root/install.sh" "${LXD_CONTAINER_NAME}/root/"
lxc exec ${LXD_CONTAINER_NAME} -- mkdir -p "/etc/wireguard"
lxc file push "${tmp_config_file}" "${LXD_CONTAINER_NAME}/etc/wireguard/"
rm "${tmp_config_file}"

info "Copy wireguard init file..."
lxc file push "overlay/etc/init.d/wg-quick"  "${LXD_CONTAINER_NAME}/etc/init.d/"

info "Run install.sh..."
lxc exec ${LXD_CONTAINER_NAME} /root/install.sh

info "Reboot container ${LXD_CONTAINER_NAME}..."
lxc exec ${LXD_CONTAINER_NAME} -- reboot
