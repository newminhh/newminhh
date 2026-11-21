#!/bin/sh
# Dracut pre-pivot hook: register newminhh in binfmt_misc before handoff to real root
BINFMT_MNT="/proc/sys/fs/binfmt_misc"
REG_FILE="${BINFMT_MNT}/register"

[ -d "${BINFMT_MNT}" ] || mkdir -p "${BINFMT_MNT}"
if ! grep -qs "binfmt_misc ${BINFMT_MNT}" /proc/mounts; then
    mount -t binfmt_misc binfmt_misc "${BINFMT_MNT}" 2>/dev/null || true
fi

if [ -w "${REG_FILE}" ]; then
    if [ -f "${BINFMT_MNT}/newminhh-i386" ]; then
        echo -1 > "${BINFMT_MNT}/newminhh-i386" 2>/dev/null || true
    fi
    for p in /usr/lib/binfmt.d/newminhh.conf /usr/share/newminhh/newminhh-binfmt.pattern /etc/binfmt.d/newminhh.conf; do
        if [ -f "$p" ]; then
            cat "$p" > "${REG_FILE}"
            exit 0
        fi
    done
    echo "[dracut:newminhh] ERROR: binfmt pattern file not found in initrd" >&2
    exit 1
fi
