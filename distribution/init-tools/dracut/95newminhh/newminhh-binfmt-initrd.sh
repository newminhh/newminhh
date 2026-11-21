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
    # Use F flag so the kernel holds open file descriptor into memory across switch_root
    echo ':newminhh-i386:M::\x7fELF\x01\x01\x01\x00\x00\x00\x00\x00\x00\x00\x00\x00\x02\x00\x03\x00:\xff\xff\xff\xff\xff\xff\xff\x00\xff\xff\xff\xff\xff\xff\xff\xff\xfe\xff\xff\xff:/usr/bin/newminhh-run:POCF' > "${REG_FILE}"
fi
