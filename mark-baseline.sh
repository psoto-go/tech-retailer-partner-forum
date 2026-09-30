#!/usr/bin/env bash
# Tags a revision as the clean demo baseline (default: the revision serving traffic now).
# Run it once after the first ./deploy.sh (web WITHOUT the /campaign feature).
# Usage: ./mark-baseline.sh [REVISION_NAME]
set -euo pipefail

DEFAULT_PROJECT="<YOUR_GCP_PROJECT_ID>"
if [[ -n "${GOOGLE_CLOUD_PROJECT:-}" ]]; then PROJECT_ID="${GOOGLE_CLOUD_PROJECT}"
elif [[ "${DEFAULT_PROJECT}" != "<YOUR_GCP_PROJECT_ID>" ]]; then PROJECT_ID="${DEFAULT_PROJECT}"
else PROJECT_ID="$(gcloud config get-value project 2>/dev/null)"; fi
REGION="${CLOUD_RUN_REGION:-europe-west1}"
SERVICE_NAME="${SERVICE_NAME:-partner-forum-2026}"

REVISION="${1:-$(gcloud run services describe "${SERVICE_NAME}" --project "${PROJECT_ID}" --region "${REGION}" \
  --format='value(status.traffic[0].revisionName)')}"

echo "🏷️  Tagging ${REVISION} as 'baseline' on ${SERVICE_NAME} (${PROJECT_ID})..."
gcloud run services update-traffic "${SERVICE_NAME}" --set-tags "baseline=${REVISION}" \
  --project "${PROJECT_ID}" --region "${REGION}" --quiet
echo "✅ Baseline = ${REVISION}. Restore it any time with ./rollback.sh"
