#!/usr/bin/env bash
# Build dist/ct_<version>_all.deb.
#
#   ./build-deb.sh 1.2.0   explicit version (a leading "v" is dropped, so tag names work too)
#   ./build-deb.sh         version from the latest git tag
set -euo pipefail

here=$(cd "$(dirname "$0")" && pwd)
version=${1:-$(git -C "$here" describe --tags --abbrev=0 2>/dev/null || true)}
version=${version#v}
if [[ ! $version =~ ^[0-9][0-9A-Za-z.+~-]*$ ]]; then
  echo "build-deb: missing or invalid version '$version'" >&2
  exit 1
fi

root=$(mktemp -d)
trap 'rm -rf "$root"' EXIT

install -Dm755 "$here/ct" "$root/usr/bin/ct"
install -Dm644 "$here/ct.bash-completion" "$root/usr/share/bash-completion/completions/ct"
install -Dm644 "$here/README.md" "$root/usr/share/doc/ct/README.md"
install -Dm644 "$here/LICENSE" "$root/usr/share/doc/ct/copyright"

# pve-container provides pct, so the package only installs on Proxmox VE.
mkdir "$root/DEBIAN"
cat >"$root/DEBIAN/control" <<EOF
Package: ct
Version: $version
Architecture: all
Maintainer: Tomáš Pecka <tomas.pecka@cesnet.cz>
Depends: bash (>= 4.4), pve-container
Section: admin
Priority: optional
Homepage: https://github.com/peckato1/ct
Description: pct wrapper that takes container names instead of VMIDs
 ct runs Proxmox VE's pct with a container name (or a fragment of it)
 instead of a VMID. Comes with bash completion.
EOF

mkdir -p "$here/dist"
dpkg-deb --root-owner-group --build "$root" "$here/dist/ct_${version}_all.deb"
