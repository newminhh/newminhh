# newminhh lookup table regeneration hook for Gentoo Portage
#
# Installation:
#   Copy this file to /etc/portage/bashrc, or source it from your existing
#   /etc/portage/bashrc:
#     . /usr/share/newminhh/newminhh-lookup.bashrc
#
# This hook regenerates the system newminhh lookup table after package
# installs/upgrades/removals so runtime lookups see newly installed libraries.
# Failures are non-fatal because newminhh falls back to the compiled-in base
# lookup table.

_newminhh_lookup_regen() {
    if [ -x /usr/bin/newminhh-lookup-gen ]; then
        /usr/bin/newminhh-lookup-gen --system --quiet || \
            echo "newminhh: lookup regen failed; using compiled-in base table" >&2
    fi
}

post_pkg_postinst() {
    _newminhh_lookup_regen
}

post_pkg_postrm() {
    _newminhh_lookup_regen
}
