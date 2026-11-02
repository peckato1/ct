#!/usr/bin/env bash
# Build a signed APT repository (for GitHub Pages) from ct .deb files.
#
#   ./build-apt-repo.sh <dir with ct_*_all.deb> <output dir>
#
# Signs with the first secret key in gpg's keyring. Besides the repository itself,
# the output has ct.gpg (the public key) and ct.sources (the apt source) for clients.
set -euo pipefail

debs=$1 out=$2
url=${APT_REPO_URL:-https://peckato1.github.io/ct}

key=$(gpg --batch --list-secret-keys --with-colons | awk -F: '$1 == "fpr" { print $10; exit }')
if [[ -z $key ]]; then
  echo "build-apt-repo: no secret key in gpg's keyring" >&2
  exit 1
fi

mkdir -p "$out/pool/main/c/ct"
cp "$debs"/ct_*_all.deb "$out/pool/main/c/ct/"
cd "$out"

# arch:all packages are listed under every architecture, like in the Debian archive.
for arch in amd64 arm64; do
  mkdir -p "dists/stable/main/binary-$arch"
  apt-ftparchive packages pool >"dists/stable/main/binary-$arch/Packages"
  gzip -9kf "dists/stable/main/binary-$arch/Packages"
done

apt-ftparchive \
  -o APT::FTPArchive::Release::Origin=ct \
  -o APT::FTPArchive::Release::Label=ct \
  -o APT::FTPArchive::Release::Suite=stable \
  -o APT::FTPArchive::Release::Codename=stable \
  -o APT::FTPArchive::Release::Architectures="amd64 arm64" \
  -o APT::FTPArchive::Release::Components=main \
  release dists/stable >Release
mv Release dists/stable/Release

gpg --batch --yes --local-user "$key" --clearsign -o dists/stable/InRelease dists/stable/Release
gpg --batch --yes --local-user "$key" --armor --detach-sign -o dists/stable/Release.gpg dists/stable/Release
gpg --batch --export "$key" >ct.gpg

cat >ct.sources <<EOF
Types: deb
URIs: $url
Suites: stable
Components: main
Signed-By: /usr/share/keyrings/ct.gpg
EOF
