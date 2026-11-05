#!/bin/sh
# gate.sh <dir>: the public export's redaction gate, generic classes only. Scans every text file under <dir> for
# per-unit and network identifiers and exits 1 on any match, printing file:line. Patterns, not values:
#   - MAC addresses (xx:xx:xx:xx:xx:xx)
#   - an unredacted Android serial-number property (serialno=...)
#   - the Ti50-style chip ID (8 hex - 8 hex)
#   - RFC 1918 addresses (10/8, 172.16/12, 192.168/16)
# The private host and user names are checked by the exporting repository, not here: listing them would publish them.
# Runs in the publishing workflow as well (.github/workflows/pages.yml). MIT License (see LICENSE).
set -u
dir=${1:?usage: gate.sh <dir>}
pat='([0-9A-Fa-f]{2}:){5}[0-9A-Fa-f]{2}'
pat="$pat|serialno=[^<[:space:]]"
pat="$pat|\\b[0-9A-Fa-f]{8}-[0-9A-Fa-f]{8}\\b"
pat="$pat|\\b10\\.[0-9]+\\.[0-9]+\\.[0-9]+\\b"
pat="$pat|\\b192\\.168\\.[0-9]+\\.[0-9]+\\b"
pat="$pat|\\b172\\.(1[6-9]|2[0-9]|3[01])\\.[0-9]+\\.[0-9]+\\b"
hits=$(grep -r -n -I -E --exclude-dir=book --exclude-dir=.git --exclude=gate.sh -e "$pat" "$dir")
if [ -n "$hits" ]; then
  printf '%s\n' "$hits"
  n=$(printf '%s\n' "$hits" | wc -l)
  echo "gate: $n identifier line(s) in $dir" >&2
  exit 1
fi
echo "gate: clean ($dir)"
