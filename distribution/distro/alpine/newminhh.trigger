#!/bin/sh

case "$1" in
    post-install|post-upgrade)
        if [ -x /usr/libexec/newminhh/binfmt-helper.sh ]; then
            /usr/libexec/newminhh/binfmt-helper.sh start 2>/dev/null || true
        fi
        ;;
    pre-deinstall)
        if [ -x /usr/libexec/newminhh/binfmt-helper.sh ]; then
            /usr/libexec/newminhh/binfmt-helper.sh stop 2>/dev/null || true
        fi
        ;;
esac
exit 0
