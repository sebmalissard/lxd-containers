#!/bin/bash

if ! command -v wg &> /dev/null
then
    echo "wg is not installed."
    echo "sudo apt install wireguard-tools"
    exit 1
fi


private_key=$(wg genkey)
public_key=$(echo "${private_key}" | wg pubkey)

echo "Private key : ${private_key}"
echo "Public key  : ${public_key}"

private_key="xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx"
public_key="xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx"
