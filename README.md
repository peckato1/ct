# ct

A wrapper around Proxmox VE's `pct` that takes a container name, or a fragment of it, instead of a VMID.

```console
$ ct enter web
→ pct enter 100 (web)
root@web:~#
```

## Usage

```
ct <command> <name|fragment|vmid> [args...]
```

| Command                   | Runs                                              |
|---------------------------|---------------------------------------------------|
| `ct enter web`            | `pct enter 100` — exact name                      |
| `ct stop stag`            | `pct stop 101` — unique fragment of `web-staging` |
| `ct snapshot web pre-upg` | `pct snapshot 100 pre-upg` — extra args unchanged |
| `ct start 102`            | `pct start 102` — plain VMIDs still work          |
| `ct list`, `ct help`      | passed to `pct` unchanged                         |

- An exact name wins over a fragment; fragments are case-insensitive.
- When more containers match, ct lists them and runs nothing.
- A number is a VMID or an exact name, never a fragment, so `ct restore 11 … --force` can't overwrite container 111.
- `ct destroy` with a fragment asks for confirmation.

Bash completion completes container names and leaves the rest to `pct`'s own completion.
See `ct --help` for the details.

## Installation

On the Proxmox host (the package depends on `pve-container`):

```sh
wget https://github.com/peckato1/ct/releases/latest/download/ct_all.deb
apt install ./ct_all.deb
```

Without the package (needs bash 4.4 or newer):

```sh
install -m 755 ct /usr/local/bin/ct
install -m 644 ct.bash-completion /usr/share/bash-completion/completions/ct
```

## Development

Run `./test.sh` for the tests (against a fake `pct`) and `./build-deb.sh 1.0.0` to build the package into `dist/`.
A pushed `v1.0.0` tag makes CI publish the release.
