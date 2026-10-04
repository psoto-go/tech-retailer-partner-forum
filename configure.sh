#!/usr/bin/env bash
# AuraTech Partner Kit — set YOUR values for the <YOUR_...> placeholders.
#
#   ./configure.sh                                        # interactive: asks for your values (Enter keeps the current one)
#   ./configure.sh --set GCP_PROJECT_ID=<id>              # non-interactive (used by Antigravity)
#   ./configure.sh --set STITCH_DESIGN_SYSTEM_ID=assets/… # Antigravity saves the design system it bootstraps
#   ./configure.sh --show                                 # print the stored values
#
# Keys: GCP_PROJECT_ID (required), STITCH_PROJECT_ID (required, your own Stitch project),
#       STITCH_DESIGN_SYSTEM_ID (optional: leave empty and Antigravity creates it from DESIGN.md on first run).
# Jira needs no config (your Jira MCP).
#
# The values are stored OUTSIDE the repo in ~/.auratech/<repo>.env (never committed) and written into
# .agent/rules, .agent/skills, Dockerfile and the scripts.
# After every reset (git reset --hard / git clean), just run ./configure.sh again: no questions asked.
# Compatible with macOS default bash 3.2 (no associative arrays).
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "${ROOT}"
REMOTE="$(git remote get-url origin 2>/dev/null || true)"
NAME="$(basename "${REMOTE:-${ROOT}}" .git)"
CFG_DIR="${HOME}/.auratech"
CFG="${CFG_DIR}/${NAME}.env"
KEYS="GCP_PROJECT_ID STITCH_PROJECT_ID STITCH_DESIGN_SYSTEM_ID"

command -v python3 >/dev/null 2>&1 || { echo "❌ python3 is required (macOS: xcode-select --install)"; exit 1; }

help_for() {
  case "$1" in
    GCP_PROJECT_ID)          echo "Google Cloud project ID (e.g. my-project-123)  [README Step 4]" ;;
    STITCH_PROJECT_ID)       echo "Your Stitch project ID: digits from the URL stitch.withgoogle.com/projects/<ID>  [README Step 2]" ;;
    STITCH_DESIGN_SYSTEM_ID) echo "Stitch design system (assets/…) — leave EMPTY: Antigravity creates it from DESIGN.md on first run  [README Step 2]" ;;
  esac
}
valid_key() { case " ${KEYS} " in *" $1 "*) return 0 ;; *) return 1 ;; esac; }
get()  { eval "printf '%s' \"\${$1:-}\""; }   # get VAR_NAME -> value ('' if unset)
setv() { printf -v "$1" '%s' "$2"; }          # setv VAR_NAME value

# Load stored values (OLD_*), start NEW_* from them.
for k in ${KEYS}; do setv "OLD_${k}" ""; done
if [[ -f "${CFG}" ]]; then
  while IFS='=' read -r k v; do
    valid_key "${k}" || continue
    v="${v%\"}"; v="${v#\"}"; v="${v%\'}"; v="${v#\'}"
    setv "OLD_${k}" "${v}"
  done < "${CFG}"
fi
for k in ${KEYS}; do setv "NEW_${k}" "$(get "OLD_${k}")"; done

MODE="interactive"
if [[ "${1:-}" == "--show" ]]; then
  echo "Values for ${NAME} (${CFG}):"
  for k in ${KEYS}; do v="$(get "OLD_${k}")"; printf '  %-24s %s\n' "${k}" "${v:-<empty>}"; done
  exit 0
elif [[ "${1:-}" == "--set" ]]; then
  MODE="set"; shift
  [[ $# -gt 0 ]] || { echo "Usage: ./configure.sh --set KEY=VALUE   (keys: ${KEYS})"; exit 1; }
  for kv in "$@"; do
    [[ "${kv}" == "--set" ]] && continue   # tolerate: --set A=1 --set B=2
    k="${kv%%=*}"; v="${kv#*=}"
    valid_key "${k}" || { echo "❌ Unknown key '${k}'. Valid: ${KEYS}"; exit 1; }
    setv "NEW_${k}" "${v}"
  done
elif [[ -n "${1:-}" ]]; then
  sed -n '2,11p' "$0"; exit 1
fi

if [[ "${MODE}" == "interactive" ]]; then
  echo "🔧 AuraTech configuration for ${NAME}  (stored in ${CFG})"
  echo "   Press Enter to keep the value in [brackets]. Type '-' to clear a value."
  if [[ -t 0 && -z "$(get OLD_GCP_PROJECT_ID)" ]] && command -v gcloud >/dev/null 2>&1; then
    setv NEW_GCP_PROJECT_ID "$(gcloud config get-value project 2>/dev/null || true)"
  fi
  for k in ${KEYS}; do
    cur="$(get "NEW_${k}")"
    echo "  $(help_for "${k}")"
    val=""
    read -r -p "    ${k} [${cur}]: " val || true
    if [[ "${val}" == "-" ]]; then setv "NEW_${k}" ""; elif [[ -n "${val}" ]]; then setv "NEW_${k}" "${val}"; fi
  done
fi

GP0="$(get NEW_GCP_PROJECT_ID)"
[[ -z "${GP0}" || "${GP0}" =~ ^[a-z][a-z0-9-]{4,28}[a-z0-9]$ ]] || echo "⚠️  '${GP0}' doesn't look like a GCP project ID (lowercase letters, digits, hyphens)."
SP0="$(get NEW_STITCH_PROJECT_ID)"; SP0="${SP0##*/projects/}"; SP0="${SP0%%[/?]*}"; setv NEW_STITCH_PROJECT_ID "${SP0}"   # accept a pasted URL
[[ -z "${SP0}" || "${SP0}" =~ ^[0-9]{10,25}$ ]] || echo "⚠️  '${SP0}' doesn't look like a Stitch project ID (digits only, from the project URL)."
DS0="$(get NEW_STITCH_DESIGN_SYSTEM_ID)"
[[ -z "${DS0}" || "${DS0}" =~ ^assets/[0-9a-f]+$ ]] || echo "⚠️  '${DS0}' doesn't look like a Stitch design system ID (assets/<hex>)."

mkdir -p "${CFG_DIR}" && chmod 700 "${CFG_DIR}"
: > "${CFG}"
for k in ${KEYS}; do printf '%s=%s\n' "${k}" "$(get "NEW_${k}")" >> "${CFG}"; done
chmod 600 "${CFG}"

for k in ${KEYS}; do export "OLD_${k}" "NEW_${k}"; done
python3 - <<'PY'
import os, re
keys = ["GCP_PROJECT_ID", "STITCH_PROJECT_ID", "STITCH_DESIGN_SYSTEM_ID"]
old = {k: os.environ.get("OLD_" + k, "") for k in keys}
new = {k: os.environ.get("NEW_" + k, "") for k in keys}

files = ["Dockerfile", "deploy.sh", "rollback.sh", "mark-baseline.sh", "setup.sh", "scripts/check-cloud.sh"]
for d in (".agent/rules", ".agent/skills"):
    for dp, _, fns in os.walk(d):
        files += [os.path.join(dp, f) for f in fns if f.endswith(".md")]

# 1) Values that changed since the last run: swap old -> new (longest first, whole tokens only).
changes = sorted(((old[k], new[k] or "<YOUR_%s>" % k) for k in keys if old[k] and old[k] != new[k]),
                 key=lambda p: -len(p[0]))
changed_files, left = set(), set()
for f in files:
    if not os.path.isfile(f):
        continue
    with open(f) as fh:
        s = n = fh.read()
    for o, v in changes:
        n = re.sub(r"(?<![\w-])" + re.escape(o) + r"(?![\w-])", lambda _m, v=v: v, n)
    # 2) Fill placeholders with the current values.
    for k in keys:
        ph = "<YOUR_%s>" % k
        if new[k]:
            n = n.replace(ph, new[k])
        elif ph in n:
            left.add(k)
    if n != s:
        with open(f, "w") as fh:
            fh.write(n)
        changed_files.add(f)

print("✅ Updated %d file(s). These are local changes: do NOT commit them to the shared repo." % len(changed_files))
if left:
    print("⚠️  Still empty: " + ", ".join(sorted(left)) + "  → run ./configure.sh again once you have them.")
else:
    print("🎉 All placeholders filled.")
PY

GP="$(get NEW_GCP_PROJECT_ID)"
if [[ -n "${GP}" ]] && command -v gcloud >/dev/null 2>&1; then
  CUR="$(gcloud config get-value project 2>/dev/null || true)"
  [[ "${CUR}" == "${GP}" ]] || echo "ℹ️  gcloud points to '${CUR:-none}'. Run: gcloud config set project ${GP}"
fi
