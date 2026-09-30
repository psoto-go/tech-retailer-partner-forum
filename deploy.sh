#!/usr/bin/env bash
set -euo pipefail

DEFAULT_PROJECT="<YOUR_GCP_PROJECT_ID>"
if [[ -n "${GOOGLE_CLOUD_PROJECT:-}" ]]; then PROJECT_ID="${GOOGLE_CLOUD_PROJECT}"
elif [[ "${DEFAULT_PROJECT}" != "<YOUR_GCP_PROJECT_ID>" ]]; then PROJECT_ID="${DEFAULT_PROJECT}"
else PROJECT_ID="$(gcloud config get-value project 2>/dev/null)"; fi
REGION="${CLOUD_RUN_REGION:-europe-west1}"
SERVICE_NAME="${SERVICE_NAME:-partner-forum-2026}"

if [[ -z "${PROJECT_ID}" ]]; then
  echo "❌ Set GOOGLE_CLOUD_PROJECT=<your-project-id> (or run: gcloud config set project <id>)"; exit 1
fi

echo "🚀 Fast-Deploying AuraTech Storefront to Cloud Run (${SERVICE_NAME} in ${PROJECT_ID} / ${REGION})..."
gcloud run deploy "${SERVICE_NAME}" \
  --source . \
  --project "${PROJECT_ID}" \
  --region "${REGION}" \
  --no-invoker-iam-check \
  --cpu=4 \
  --memory=4Gi \
  --min-instances=1 \
  --max-instances=1 \
  --concurrency=1000 \
  --set-env-vars="GOOGLE_CLOUD_PROJECT=${PROJECT_ID},CLOUD_RUN_REGION=${REGION},GOOGLE_GENAI_USE_VERTEXAI=TRUE" \
  --quiet

# After a ./rollback.sh the traffic is pinned to the baseline revision; always serve the new one.
gcloud run services update-traffic "${SERVICE_NAME}" --to-latest \
  --project "${PROJECT_ID}" --region "${REGION}" --quiet
