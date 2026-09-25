# Shared helpers for the /flow scripts. Source it:
#   . "$(cd "$(dirname "$0")" && pwd)/lib.sh"
# Portable to macOS bash 3.2 and BWK awk (no gawk, no yq).

flow_top() { git rev-parse --show-toplevel 2>/dev/null || pwd; }

flow_config() { printf '%s/docs/flow.config.yml\n' "${1:-$(flow_top)}"; }

# The YAML /flow init writes is flat: top-level keys and one level of
# nesting, one key per line, `# comments`, optional quotes. Anything richer
# (anchors, multi-line strings, deeper nesting) is not supported.
_cfg_awk='
function clean(v,   q, i) {
  sub(/^[ \t]+/, "", v)
  q = substr(v, 1, 1)
  if (q == "\"" || q == "\047") {           # quoted: up to the closing quote
    i = index(substr(v, 2), q)
    if (i > 0) return substr(v, 2, i - 1)
  }
  sub(/[ \t]+#.*$/, "", v); sub(/[ \t]+$/, "", v)
  return v
}
function keyof(s) { sub(/^[ \t]+/, "", s); sub(/:.*/, "", s); return s }
function valof(s) { sub(/^[^:]*:/, "", s); return clean(s) }
/^[ \t]*(#|$)/ { next }
'

# cfg <key> [config-file]: value of "language" or "ticket.tracker".
# Prints nothing when the key is absent.
cfg() {
  local file=${2:-$(flow_config)}
  [ -f "$file" ] || return 0
  awk -v want="$1" "$_cfg_awk"'
    /^[^ \t]/ { parent = keyof($0); if (parent == want) { print valof($0); exit } next }
    $0 !~ /^[ \t]+-/ { if (parent "." keyof($0) == want) { print valof($0); exit } }
  ' "$file"
}

# cfg_has <top-level-key> [config-file]: exit 0 when the key exists.
cfg_has() {
  local file=${2:-$(flow_config)}
  [ -f "$file" ] || return 1
  awk -v want="$1" "$_cfg_awk"'
    /^[^ \t]/ && keyof($0) == want { found = 1; exit }
    END { exit !found }
  ' "$file"
}

# cfg_map <top-level-key> [config-file]: "key<TAB>value" per nested key,
# in file order (commands run in the order they are written).
cfg_map() {
  local file=${2:-$(flow_config)}
  [ -f "$file" ] || return 0
  awk -v want="$1" "$_cfg_awk"'
    /^[^ \t]/ { parent = keyof($0); next }
    parent == want && $0 !~ /^[ \t]+-/ { print keyof($0) "\t" valof($0) }
  ' "$file"
}

# cfg_list <top-level-key> [config-file]: one item per line, from either
# `key: [a, b]` or a block list of `- a` lines.
cfg_list() {
  local file=${2:-$(flow_config)}
  [ -f "$file" ] || return 0
  awk -v want="$1" "$_cfg_awk"'
    /^[^ \t]/ {
      parent = keyof($0)
      if (parent == want) {
        v = valof($0)
        if (v ~ /^\[.*\]$/) {
          v = substr(v, 2, length(v) - 2); n = split(v, a, ",")
          for (i = 1; i <= n; i++) { x = clean(a[i]); if (x != "") print x }
        }
      }
      next
    }
    parent == want && /^[ \t]+-/ { x = $0; sub(/^[ \t]+-/, "", x); x = clean(x); if (x != "") print x }
  ' "$file"
}

# field <main.md> <name>: value from the state file's header table.
field() {
  awk -F'|' -v k="$2" '{ key=$2; gsub(/^[ \t]+|[ \t]+$/, "", key) }
    key == k { v=$3; gsub(/^[ \t]+|[ \t]+$/, "", v); print v; exit }' "$1"
}

flow_now() { date '+%Y-%m-%d %H:%M'; }

# is_open_status <status>: a run that is neither done nor canceled.
is_open_status() { case "$1" in done|canceled|'') return 1 ;; *) return 0 ;; esac; }
