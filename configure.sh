#!/usr/bin/env bash
# AuraTech Partner Kit — set YOUR values for the <YOUR_...> placeholders.
#
#   ./configure.sh                         # interactive: asks for each value (Enter keeps the current one)
#   ./configure.sh --set KEY=VALUE [...]   # non-interactive (used by Antigravity), e.g. --set JIRA_TICKET_KEY=ABC-12
#   ./configure.sh --show                  # print your stored values
#
# KEYS: GCP_PROJECT_ID  JIRA_PROJECT_KEY  JIRA_TICKET_KEY  STITCH_PROJECT_ID  STITCH_DESIGN_SYSTEM_ID
#
# Values are stored OUTSIDE the repo in ~/.auratech/<repo>.env (never committed) and written into
# .agent/rules, .agent/skills, Dockerfile and the scripts. Empty values keep their placeholder.
# After every reset (git reset --hard / git clean), just run ./configure.sh again: no questions asked.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "${ROOT}"
REMOTE="$(git remote get-url origin 2>/dev/null || true)"
NAME="$(basename "${REMOTE:-${ROOT}}" .git)"
CFG_DIR="${HOME}/.auratech"
CFG="${CFG_DIR}/${NAME}.env"

KEYS=(GCP_PROJECT_ID JIRA_PROJECT_KEY JIRA_TICKET_KEY STITCH_PROJECT_ID STITCH_DESIGN_SYSTEM_ID)
declare -A HELP=(
  [GCP_PROJECT_ID]="Google Cloud project ID (e.g. my-project-123)                      [README Step 4]"
  [JIRA_PROJECT_KEY]="Jira project key (e.g. ABC)                                        [README Step 1]"
  [JIRA_TICKET_KEY]="Jira ticket Antigravity implements (e.g. ABC-12; empty if not created yet)"
  [STITCH_PROJECT_ID]="Stitch project ID, numbers only (empty until README Step 5)"
  [STITCH_DESIGN_SYSTEM_ID]="Stitch design system, e.g. assets/abc123 (empty until README Step 5)"
)

mkdir -p "${CFG_DIR}" && chmod 700 "${CFG_DIR}"
declare -A OLD NEW
for k in "${KEYS[@]}"; do OLD[$k]=""; done
if [[ -f "${CFG}" ]]; then
  # shellcheck disable=SC1090
  source "${CFG}"
  for k in "${KEYS[@]}"; do OLD[$k]="${!k:-}"; done
fi
for k in "${KEYS[@]}"; do NEW[$k]="${OLD[$k]}"; done

valid_key() { [[ " ${KEYS[*]} " == *" $1 "* ]]; }

MODE="interactive"
if [[ "${1:-}" == "--show" ]]; then
  echo "Values for ${NAME} (${CFG}):"
  for k in "${KEYS[@]}"; do printf '  %-24s %s\n' "${k}" "${OLD[$k]:-<empty>}"; done
  exit 0
elif [[ "${1:-}" == "--set" ]]; then
  MODE="set"; shift
  [[ $# -gt 0 ]] || { echo "Usage: ./configure.sh --set KEY=VALUE [...]"; exit 1; }
  for kv in "$@"; do
    k="${kv%%=*}"; v="${kv#*=}"
    valid_key "${k}" || { echo "❌ Unknown key '${k}'. Valid: ${KEYS[*]}"; exit 1; }
    NEW[$k]="${v}"
  done
elif [[ -n "${1:-}" ]]; then
  sed -n '2,12p' "$0"; exit 1
fi

if [[ "${MODE}" == "interactive" ]]; then
  echo "🔧 AuraTech configuration for ${NAME}  (stored in ${CFG})"
  echo "   Press Enter to keep the value in [brackets]. Type '-' to clear a value."
  if [[ -t 0 && -z "${OLD[GCP_PROJECT_ID]}" ]] && command -v gcloud >/dev/null 2>&1; then
    NEW[GCP_PROJECT_ID]="$(gcloud config get-value project 2>/dev/null || true)"
  fi
  for k in "${KEYS[@]}"; do
    read -r -p "  ${HELP[$k]}"$'\n'"    ${k} [${NEW[$k]}]: " val || true
    if [[ "${val}" == "-" ]]; then NEW[$k]=""; elif [[ -n "${val}" ]]; then NEW[$k]="${val}"; fi
  done
fi

# Basic validation (warn only).
[[ -z "${NEW[STITCH_PROJECT_ID]}" || "${NEW[STITCH_PROJECT_ID]}" =~ ^[0-9]+$ ]] || echo "⚠️  STITCH_PROJECT_ID should be numbers only (no 'projects/')."
[[ -z "${NEW[STITCH_DESIGN_SYSTEM_ID]}" || "${NEW[STITCH_DESIGN_SYSTEM_ID]}" == assets/* ]] || echo "⚠️  STITCH_DESIGN_SYSTEM_ID usually looks like 'assets/<id>'."
[[ -z "${NEW[JIRA_TICKET_KEY]}" || -z "${NEW[JIRA_PROJECT_KEY]}" || "${NEW[JIRA_TICKET_KEY]}" == "${NEW[JIRA_PROJECT_KEY]}"-* ]] || echo "⚠️  JIRA_TICKET_KEY usually starts with '${NEW[JIRA_PROJECT_KEY]}-'."

: > "${CFG}"
for k in "${KEYS[@]}"; do printf '%s=%q\n' "${k}" "${NEW[$k]}" >> "${CFG}"; done
chmod 600 "${CFG}"

for k in "${KEYS[@]}"; do export "OLD_${k}=${OLD[$k]}" "NEW_${k}=${NEW[$k]}"; done
python3 - <<'PY'
import os, re
keys = ["GCP_PROJECT_ID", "JIRA_PROJECT_KEY", "JIRA_TICKET_KEY", "STITCH_PROJECT_ID", "STITCH_DESIGN_SYSTEM_ID"]
old = {k: os.environ.get(f"OLD_{k}", "") for k in keys}
new = {k: os.environ.get(f"NEW_{k}", "") for k in keys}

files = ["Dockerfile", "deploy.sh", "rollback.sh", "mark-baseline.sh", "setup.sh", "scripts/check-cloud.sh"]
for d in (".agent/rules", ".agent/skills"):
    for dp, _, fns in os.walk(d):
        files += [os.path.join(dp, f) for f in fns if f.endswith(".md")]

# 1) Values that changed since the last run: swap old -> new (longest first, whole tokens only).
changes = sorted(((old[k], new[k] or f"<YOUR_{k}>") for k in keys if old[k] and old[k] != new[k]),
                 key=lambda p: -len(p[0]))
changed_files, left = set(), set()
for f in files:
    if not os.path.isfile(f):
        continue
    s = n = open(f).read()
    for o, v in changes:
        n = re.sub(r"(?<![\w-])" + re.escape(o) + r"(?![\w-])", lambda _: v, n)
    # 2) Fill placeholders with the current values.
    for k in keys:
        ph = f"<YOUR_{k}>"
        if new[k]:
            n = n.replace(ph, new[k])
        elif ph in n:
            left.add(k)
    if n != s:
        open(f, "w").write(n)
        changed_files.add(f)

print(f"✅ Updated {len(changed_files)} file(s). These are local changes: do NOT commit them to the shared repo.")
if left:
    print("⚠️  Still empty: " + ", ".join(sorted(left)) + "  → run ./configure.sh again once you have them.")
else:
    print("🎉 All placeholders filled.")
PY

if [[ -n "${NEW[GCP_PROJECT_ID]}" ]] && command -v gcloud >/dev/null 2>&1; then
  CUR="$(gcloud config get-value project 2>/dev/null || true)"
  [[ "${CUR}" == "${NEW[GCP_PROJECT_ID]}" ]] || echo "ℹ️  gcloud points to '${CUR:-none}'. Run: gcloud config set project ${NEW[GCP_PROJECT_ID]}"
fi
