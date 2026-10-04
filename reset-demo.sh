#!/usr/bin/env bash
# One-command reset between two live sessions (~60 s). Run from the repo root in the terminal you deploy from.
#   ./reset-demo.sh
# 1) Cloud Run back to the clean 'baseline' revision (storefront + Live Role Poll, no /campaign)
# 2) Local repo back to origin/main (removes campaign_router.py, templates/campaign.html, stitch_design_proposal.md)
# 3) Refill your GCP project ID (./configure.sh, no questions asked)
# 4) Live Role Poll votes back to 0
# 5) Verify: /campaign must be 404, /poll 200 with 0 votes
# Then (manual, ~20 s): move the Jira ticket back to "To Do" (delete the live-URL comment) and open a NEW Antigravity chat.
set -euo pipefail

main() {
  cd "$(dirname "$0")"
  local NAME CFG PROJECT_ID REGION SERVICE_NAME URL
  NAME="$(basename "$(git remote get-url origin 2>/dev/null || pwd)" .git)"
  CFG="${HOME}/.auratech/${NAME}.env"
  PROJECT_ID="${GOOGLE_CLOUD_PROJECT:-$(sed -n 's/^GCP_PROJECT_ID=//p' "${CFG}" 2>/dev/null | tr -d '"'"'" || true)}"
  PROJECT_ID="${PROJECT_ID:-$(gcloud config get-value project 2>/dev/null || true)}"
  REGION="${CLOUD_RUN_REGION:-europe-west1}"
  SERVICE_NAME="${SERVICE_NAME:-partner-forum-2026}"
  [[ -n "${PROJECT_ID}" ]] || { echo "❌ No GCP project. Run ./configure.sh first."; exit 1; }

  if ! gcloud run services describe "${SERVICE_NAME}" --project "${PROJECT_ID}" --region "${REGION}" >/dev/null 2>&1; then
    echo "❌ Cloud Run service ${SERVICE_NAME} does not exist yet in ${PROJECT_ID}."
    echo "   First-time setup for a new project:  ./setup.sh && ./scripts/check-cloud.sh   (once per project)"
    echo "   then:                                ./deploy.sh && ./mark-baseline.sh        (creates the baseline)"
    echo "   and only after that:                 ./reset-demo.sh"
    exit 1
  fi

  echo "1/5 ⏪ Cloud Run ${SERVICE_NAME} → baseline revision"
  ./rollback.sh | tail -1

  echo "2/5 🧹 Repo → origin/main (generated feature files removed)"
  git fetch -q origin && git reset -q --hard origin/main && git clean -fdq

  echo "3/5 🔧 Refilling project ID (${PROJECT_ID})"
  ./configure.sh </dev/null >/dev/null

  URL="$(gcloud run services describe "${SERVICE_NAME}" --project "${PROJECT_ID}" --region "${REGION}" --format='value(status.url)')"
  echo "4/5 🗳️  Live Role Poll votes → 0"
  curl -s -X POST "${URL}/api/admin/reset-votes" >/dev/null

  echo "5/5 ✅ Verifying ${URL}"
  local camp poll votes
  camp="$(curl -s -o /dev/null -w '%{http_code}' "${URL}/campaign")"
  poll="$(curl -s -o /dev/null -w '%{http_code}' "${URL}/poll")"
  votes="$(curl -s "${URL}/api/state" | python3 -c 'import json,sys; print(json.load(sys.stdin).get("totalVotes", "?"))' 2>/dev/null || echo "?")"
  echo "    /campaign → ${camp} (expected 404)   /poll → ${poll} (expected 200)   poll votes → ${votes} (expected 0)"
  if [[ "${camp}" != "404" || "${poll}" != "200" ]]; then
    echo "❌ Not clean yet. Re-run ./reset-demo.sh in 10 s (baseline instance may still be warming up)."; exit 1
  fi
  echo
  echo "🎬 Ready for the next session. Remaining manual steps:"
  echo "   • Jira: move the 'Google Fitbit Air Challenge' ticket back to To Do and delete the live-URL comment."
  echo "   • Antigravity: open a NEW chat (File → Open Folder → this repo if it lost the workspace)."
  echo "   • Stage screen: ${URL}/poll"
}

main "$@"; exit
