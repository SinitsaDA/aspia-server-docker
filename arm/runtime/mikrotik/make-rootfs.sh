#!/bin/bash
#
# Builds a minimal root file system for the MikroTik image: only the commands the scripts use,
# their libraries (found with ldd), CA certificates and time zones. Runs inside debian:bookworm-slim.
set -euo pipefail

ROOT="${1:?usage: make-rootfs.sh <dir>}"
mkdir -p "${ROOT}/usr/bin" "${ROOT}/usr/lib" "${ROOT}/usr/sbin"
# merged /usr as in Debian 12: /bin, /lib, /sbin are links
for link in bin lib sbin; do
    ln -sfn "usr/${link}" "${ROOT}/${link}"
done

COMMANDS=(
    bash sh cat cp mv rm rmdir mkdir ls ln chmod touch tee tr cut head tail sort seq sleep date
    uname basename dirname du sha256sum xargs env id true false wc
    find grep sed awk tar gzip pgrep pkill ps mountpoint curl jq
)

copy() {
    local file="$1" dir
    # resolve the directory (/lib -> /usr/lib), keep the file name (it may be a link)
    file="$(cd "$(dirname "${file}")" && pwd -P)/$(basename "${file}")"
    [[ -e "${ROOT}${file}" || -L "${ROOT}${file}" ]] && return 0
    dir="$(dirname "${file}")"
    mkdir -p "${ROOT}${dir}"
    cp -a "${file}" "${ROOT}${file}"
    # follow symbolic links link by link (awk -> /etc/alternatives/awk -> mawk)
    if [[ -L "${file}" ]]; then
        local target
        target="$(readlink "${file}")"
        [[ "${target}" == /* ]] || target="$(dirname "${file}")/${target}"
        copy "${target}"
    fi
}

copy_libs() {
    local lib
    while read -r lib; do
        [[ -n "${lib}" ]] && copy "${lib}"
    done < <(ldd "$1" 2>/dev/null | grep -oE '/[^ ]+' || true)
}

copy_with_libs() {
    copy "$1"
    copy_libs "$1"
}

for cmd in "${COMMANDS[@]}"; do
    path="$(type -P "${cmd}")" || { echo "not found: ${cmd}"; exit 1; }
    copy_with_libs "${path}"
done

# libraries of the Aspia binaries and of what they load at run time
for file in /tmp/aspia/*; do
    copy_libs "${file}"
done
for lib in /usr/lib/*/libnss_dns.so.2 /usr/lib/*/libnss_files.so.2 /usr/lib/*/libresolv.so.2; do
    [[ -e "${lib}" ]] && copy_with_libs "${lib}"
done

# data files
mkdir -p "${ROOT}/etc/ssl/certs" "${ROOT}/usr/share/zoneinfo"
cp -a /etc/ssl/certs/ca-certificates.crt "${ROOT}/etc/ssl/certs/"
(cd /usr/share/zoneinfo && tar -cf - --exclude=right --exclude=posix .) | tar -xf - -C "${ROOT}/usr/share/zoneinfo"
# UTF-8 locale for Qt (LANG=C.UTF-8)
mkdir -p "${ROOT}/usr/lib/locale"
cp -a /usr/lib/locale/C.utf8 "${ROOT}/usr/lib/locale/"
cp -a /etc/passwd /etc/group /etc/nsswitch.conf "${ROOT}/etc/"
cp -a /etc/localtime "${ROOT}/etc/" 2>/dev/null || true
mkdir -p "${ROOT}/tmp" "${ROOT}/run" "${ROOT}/var/tmp" "${ROOT}/etc/aspia" "${ROOT}/var/lib/aspia" "${ROOT}/var/log/aspia"
chmod 1777 "${ROOT}/tmp" "${ROOT}/var/tmp"

du -sh "${ROOT}"
