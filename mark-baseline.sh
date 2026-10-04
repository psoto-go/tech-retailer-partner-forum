#!/usr/bin/env bash
# Copyright 2026 Google LLC
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     https://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

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

# Default = the revision currently serving 100% of traffic (not the first traffic entry, which may be a 0% tag).
REVISION="${1:-$(gcloud run services describe "${SERVICE_NAME}" --project "${PROJECT_ID}" --region "${REGION}" \
  --format=json | python3 -c "import json,sys; t=json.load(sys.stdin)['status'].get('traffic',[]); print(next((x['revisionName'] for x in t if x.get('percent')==100 and x.get('revisionName')),''))")}"

echo "🏷️  Tagging ${REVISION} as 'baseline' on ${SERVICE_NAME} (${PROJECT_ID})..."
gcloud run services update-traffic "${SERVICE_NAME}" --set-tags "baseline=${REVISION}" \
  --project "${PROJECT_ID}" --region "${REGION}" --quiet
echo "✅ Baseline = ${REVISION}. Restore it any time with ./rollback.sh"
