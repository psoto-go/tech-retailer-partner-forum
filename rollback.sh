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

# Restores the clean demo baseline (revision tagged 'baseline' by ./mark-baseline.sh) in ~2-5 s.
set -euo pipefail

DEFAULT_PROJECT="<YOUR_GCP_PROJECT_ID>"
if [[ -n "${GOOGLE_CLOUD_PROJECT:-}" ]]; then PROJECT_ID="${GOOGLE_CLOUD_PROJECT}"
elif [[ "${DEFAULT_PROJECT}" != "<YOUR_GCP_PROJECT_ID>" ]]; then PROJECT_ID="${DEFAULT_PROJECT}"
else PROJECT_ID="$(gcloud config get-value project 2>/dev/null)"; fi
REGION="${CLOUD_RUN_REGION:-europe-west1}"
SERVICE_NAME="${SERVICE_NAME:-partner-forum-2026}"

REVISION="$(gcloud run services describe "${SERVICE_NAME}" --project "${PROJECT_ID}" --region "${REGION}" \
  --format=json | python3 -c "import json,sys; t=json.load(sys.stdin)['status'].get('traffic',[]); print(next((x['revisionName'] for x in t if x.get('tag')=='baseline'),''))")"

if [[ -z "${REVISION}" ]]; then
  echo "❌ No 'baseline' tag found. Run ./mark-baseline.sh <clean-revision> first."; exit 1
fi

echo "⏪ Rolling back ${SERVICE_NAME} to clean baseline revision (${REVISION})..."
gcloud run services update-traffic "${SERVICE_NAME}" --to-revisions "${REVISION}=100" \
  --project "${PROJECT_ID}" --region "${REGION}" --quiet
URL="$(gcloud run services describe "${SERVICE_NAME}" --project "${PROJECT_ID}" --region "${REGION}" --format='value(status.url)')"
echo "✅ Rollback complete! Live URL: ${URL}"
