#!/bin/bash
# dracut check module for newminhh

check() {
    # Include by default if newminhh-run is installed on the host, or if explicitly requested
    require_binaries /usr/bin/newminhh-run || return 1
    return 255
}

depends() {
    return 0
}

install() {
    # Install the x32 runner binary and its dependencies
    inst_multiple /usr/bin/newminhh-run \
                  /usr/bin/newminhh \
                  /usr/lib/x86_64-linux-gnux32/libnewminhh_compat.so \
                  /usr/lib/x86_64-linux-gnux32/libnewminhh_dbt.so \
                  /usr/libx32/libnewminhh_compat.so \
                  /usr/libx32/libnewminhh_dbt.so 2>/dev/null || true

    # Install ld-linux-x32.so dynamic linker and runtime libraries
    inst_libdir_file "ld-linux-x32.so.2"
    inst_libdir_file "libc.so.6"
    inst_libdir_file "libdl.so.2"
    inst_libdir_file "libm.so.6"
    inst_libdir_file "libpthread.so.0"

    # Install the pre-pivot hook script
    inst_hook pre-pivot 05 "$moddir/newminhh-binfmt-initrd.sh"
}
