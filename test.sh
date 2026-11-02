#!/usr/bin/env bash
# Small tests for ct and its bash completion, run against a fake `pct`.
set -uo pipefail

here=$(cd "$(dirname "$0")" && pwd)
tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT

# Fake pct: `list` prints a fixed table, `bashcomplete` echoes what it got, anything else echoes its arguments.
cat >"$tmp/pct" <<'EOF'
#!/usr/bin/env bash
case ${1-} in
  list)
    [[ -z ${PCT_LIST_FAILS-} ]] || { echo "pct list failed" >&2; exit 2; }
    cat <<'LIST'
VMID       Status     Lock         Name
100        running                 web
101        stopped                 web-staging
102        running    backup       db
103        running                 Mail
110        running                 42
111        running                 111
120        stopped                 102
LIST
    ;;
  bashcomplete) echo "$COMP_LINE|$3|$4" ;;
  *) echo "pct $*" ;;
esac
EOF
chmod +x "$tmp/pct"
export PATH="$tmp:$here:$PATH"

failures=0

# check <description> <expected> <actual>
check() {
  if [[ $2 == "$3" ]]; then
    echo "ok   $1"
  else
    printf 'FAIL %s\n  expected: %s\n  actual:   %s\n' "$1" "$2" "$3"
    failures=$((failures + 1))
  fi
}

# Run ct and report "<exit status>: <stdout>"; stdout is what the fake pct received.
ct_out() {
  local out
  out=$(ct "$@" 2>/dev/null)
  echo "$?: $out"
}

# Run ct and report only its first stderr line.
ct_err() { ct "$@" 2>&1 >/dev/null | head -n1; }

echo "# ct"
check "exact name wins over fragment"   "0: pct enter 100"                     "$(ct_out enter web)"
check "unique fragment"                 "0: pct stop 101"                      "$(ct_out stop stag)"
check "exact name ignoring case wins"   "0: pct enter 100"                     "$(ct_out enter WEB)"
check "fragment is case-insensitive"    "0: pct enter 103"                     "$(ct_out enter mail)"
check "lock column is skipped"          "0: pct enter 102"                     "$(ct_out enter db)"
check "extra arguments are kept"        "0: pct snapshot 101 pre-upg --vmstate" "$(ct_out snapshot stag pre-upg --vmstate)"
check "ambiguous fragment runs nothing" "1: "                                  "$(ct_out enter we)"
check "ambiguous fragment message"      "ct: 'we' matches multiple containers:" "$(ct_err enter we)"
check "no match runs nothing"           "1: "                                  "$(ct_out enter nope)"
check "no match message"                "ct: no container matches 'nope'"      "$(ct_err enter nope)"
check "--help shows ct usage"           "0: Usage: ct <command> <name|fragment|vmid> [args...]" "$(ct_out --help | head -n1)"
check "-h shows ct usage"               "0: Usage: ct <command> <name|fragment|vmid> [args...]" "$(ct_out -h | head -n1)"
check "VMID passes through"             "0: pct enter 100"                     "$(ct_out enter 100)"
check "unknown VMID passes through"     "0: pct create 999 local:tmpl"         "$(ct_out create 999 local:tmpl)"
check "number matching only a name"     "0: pct enter 110"                     "$(ct_out enter 42)"
check "number is never a fragment"      "0: pct restore 11 x.tar --force"      "$(ct_out restore 11 x.tar --force)"
check "VMID clashing with another name" "1: "                                  "$(ct_out enter 102)"
check "VMID clash message"              "ct: '102' is the VMID of 'db' and also the name of another container, doing nothing:" "$(ct_err enter 102)"
check "VMID equal to its own name"      "0: pct enter 111"                     "$(ct_out enter 111)"
check "__resolve of such a VMID"        "0: 111"                               "$(ct_out __resolve 111)"
check "no arguments pass through"       "0: pct "                              "$(ct_out)"
check "help passes through"             "0: pct help enter"                    "$(ct_out help enter)"
check "option instead of VMID"          "0: pct enter --help"                  "$(ct_out enter --help)"
check "__resolve prints the VMID"       "0: 101"                               "$(ct_out __resolve stag)"
check "__resolve keeps a plain VMID"    "0: 555"                               "$(ct_out __resolve 555)"
check "failing pct list runs nothing"   "1: "                                  "$(PCT_LIST_FAILS=1 ct_out enter web)"
check "failing pct list message"        "ct: cannot list containers"           "$(PCT_LIST_FAILS=1 ct enter web 2>&1 >/dev/null | tail -n1)"
check "failing pct list, VMID"          "1: "                                  "$(PCT_LIST_FAILS=1 ct_out enter 100)"
check "destroy by exact name"           "0: pct destroy 100"                   "$(ct_out destroy web)"
# Without a terminal the confirmation prompt cannot be answered, so nothing must run.
# shellcheck disable=SC2016
check "destroy by fragment needs a tty" "1: "                                  "$(setsid -w bash -c 'out=$(ct destroy stag 2>/dev/null); echo "$?: $out"')"
# shellcheck disable=SC2016
check "destroy by number-as-name needs a tty" "1: "                            "$(setsid -w bash -c 'out=$(ct destroy 42 2>/dev/null); echo "$?: $out"')"
# shellcheck disable=SC2016
check "destroy ignoring case needs a tty" "1: "                                "$(setsid -w bash -c 'out=$(ct destroy WEB 2>/dev/null); echo "$?: $out"')"
check "destroy by VMID"                 "0: pct destroy 100"                   "$(ct_out destroy 100)"

echo "# completion"
# shellcheck source=ct.bash-completion
source "$here/ct.bash-completion"

# complete_ct <word>...: complete the last word and print the candidates.
complete_ct() {
  COMP_WORDS=(ct "$@")
  COMP_CWORD=$#
  _ct
  echo "${COMPREPLY[*]}"
}

check "names by prefix"                 "web web-staging"                      "$(complete_ct enter w)"
check "names by fragment"               "web-staging"                          "$(complete_ct enter STAG)"
check "all names"                       "web web-staging db Mail 42 111 102" "$(complete_ct enter '')"
check "subcommand goes to pct"          "pct sta|sta|pct"                      "$(complete_ct sta)"
check "help gets no names"              "pct help e|e|help"                    "$(complete_ct help e)"
check "name is replaced by VMID"        "pct snapshot 101 ||101"               "$(complete_ct snapshot stag '')"

echo
if ((failures)); then
  echo "$failures test(s) failed"
  exit 1
fi
echo "all tests passed"
