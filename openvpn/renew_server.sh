#!/bin/bash

set -e

# Renew server certificate
#
# $1 - server crt path (e.g. server_abcdef.crt)

# Inspired by:
# https://github.com/angristan/openvpn-install/issues/974

curr_dir="$(dirname $(readlink -f $0))"
curr_crt="$(basename ${1})"

if [ ! -f "${curr_crt}" ]; then
    echo "No server certificate file: '${curr_crt}'"
    exit 1
fi

easyrsa_dir="${curr_dir}/easy-rsa"

if [ ! -d "${easyrsa_dir}" ]; then
    echo "easy-rsa directory not found: '${easyrsa_dir}'"
    exit 1
fi

openvpn_dir="${curr_dir}/../openvpn"

if [ ! -d "${openvpn_dir}" ]; then
    echo "openvpn directory not found: '${openvpn_dir}'"
    exit 1
fi

# Show certificate info
echo "Certificate: ${curr_crt}"
openssl x509 -enddate -subject -noout -in "${curr_crt}"

# Ask for renewal
yn="nope"

while [ "${yn}" != "n" ] && [ "${yn}" != "y" ]
do
    read -p "Please confirm: Certificate '${curr_crt}' will be updated [y/n] [Ctrl+C to exit]:" yn
done

if [ "${yn}" == "n" ]; then
    echo "Rejected by user"
    exit 1
fi

# Remove crt extension
crt_name="${curr_crt%.*}"

# Backup files
backup_dir="${curr_dir}/bak/$(date +'%Y-%m-%d-%H-%M-%S')"

mkdir -p "${backup_dir}"

mv "${easyrsa_dir}/pki/reqs/${crt_name}.req"    "${backup_dir}/" || true
mv "${easyrsa_dir}/pki/issued/${crt_name}.crt"  "${backup_dir}/" || true
mv "${easyrsa_dir}/pki/private/${crt_name}.key" "${backup_dir}/" || true

# Generate server certificate
pushd "${easyrsa_dir}" >/dev/null
    ./easyrsa build-server-full "${crt_name}" nopass
    ./easyrsa gen-crl
popd >/dev/null

# Copy new certificate
cp "${easyrsa_dir}/pki/crl.pem"                 "${openvpn_dir}/" || true
cp "${easyrsa_dir}/pki/issued/${crt_name}.crt"  "${openvpn_dir}/" || true
cp "${easyrsa_dir}/pki/private/${crt_name}.key" "${openvpn_dir}/" || true

# Show new certificate info
echo "Certificate: ${curr_crt}"
openssl x509 -enddate -subject -noout -in "${curr_crt}"
