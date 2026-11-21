#!/bin/sh
# Helper script to mount binfmt_misc and register/unregister newminhh
set -eu

BINFMT_MNT="/proc/sys/fs/binfmt_misc"
REG_FILE="${BINFMT_MNT}/register"
ENTRY_FILE="${BINFMT_MNT}/newminhh-i386"

find_pattern_rule() {
    # 1. Environment variable override
    if [ -n "${NEWMINHH_BINFMT_RULE:-}" ]; then
        printf '%s' "${NEWMINHH_BINFMT_RULE}"
        return 0
    fi

    # 2. Candidate pattern file paths (file must exist)
    for p in \
        /usr/lib/binfmt.d/newminhh.conf \
        /usr/share/newminhh/newminhh-binfmt.pattern \
        /etc/binfmt.d/newminhh.conf \
        "$(dirname "$0")/../common/newminhh-binfmt.pattern" \
        "$(dirname "$0")/newminhh.conf" \
        "$(dirname "$0")/systemd/newminhh.conf"; do
        if [ -f "$p" ]; then
            head -n 1 "$p" | tr -d '\r\n'
            return 0
        fi
    done

    echo "[newminhh-binfmt] ERROR: pattern file not found in any standard location" >&2
    return 1
}

mount_binfmt() {
    if [ ! -d "${BINFMT_MNT}" ]; then
        mkdir -p "${BINFMT_MNT}" 2>/dev/null || true
    fi
    if ! grep -qs "binfmt_misc ${BINFMT_MNT}" /proc/mounts; then
        mount -t binfmt_misc binfmt_misc "${BINFMT_MNT}" 2>/dev/null || true
    fi
}

start() {
    mount_binfmt
    if [ ! -w "${REG_FILE}" ]; then
        echo "[newminhh-binfmt] WARNING: ${REG_FILE} is not writable or binfmt_misc unsupported" >&2
        return 1
    fi
    if [ -f "${ENTRY_FILE}" ]; then
        echo -1 > "${ENTRY_FILE}" 2>/dev/null || true
    fi
    rule="$(find_pattern_rule)"
    printf '%s\n' "${rule}" > "${REG_FILE}"
    echo "[newminhh-binfmt] Successfully registered newminhh-i386 binfmt handler"
}

stop() {
    if [ -f "${ENTRY_FILE}" ]; then
        echo -1 > "${ENTRY_FILE}" 2>/dev/null || true
        echo "[newminhh-binfmt] Unregistered newminhh-i386 binfmt handler"
    fi
}

status() {
    if [ -f "${ENTRY_FILE}" ]; then
        cat "${ENTRY_FILE}"
    else
        echo "[newminhh-binfmt] newminhh-i386 is not registered"
        return 1
    fi
}

case "${1:-start}" in
    start)
        start
        ;;
    stop)
        stop
        ;;
    restart)
        stop
        start
        ;;
    status)
        status
        ;;
    *)
        echo "Usage: $0 {start|stop|restart|status}" >&2
        exit 1
        ;;
esac
