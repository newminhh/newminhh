#!/bin/sh

/usr/bin/newminhh-lookup-gen --system --quiet || echo "newminhh: lookup regen failed; using compiled-in base table" >&2
exit 0
