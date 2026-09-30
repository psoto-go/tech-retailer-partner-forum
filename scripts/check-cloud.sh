#!/usr/bin/env bash
# README Step 4 — verifies that this machine (and Antigravity's terminal) can reach YOUR
# Google Cloud project for Cloud Run and Vertex AI Nano Banana. Prints ✅ / ❌ with fixes.
# Usage: ./scripts/check-cloud.sh        (or GOOGLE_CLOUD_PROJECT=<id> ./scripts/check-cloud.sh)
set -uo pipefail

DEFAULT_PROJECT="<YOUR_GCP_PROJECT_ID>"
if [[ -n "${GOOGLE_CLOUD_PROJECT:-}" ]]; then PROJECT_ID="${GOOGLE_CLOUD_PROJECT}"
elif [[ "${DEFAULT_PROJECT}" != "<YOUR_GCP_PROJECT_ID>" ]]; then PROJECT_ID="${DEFAULT_PROJECT}"
else PROJECT_ID="$(gcloud config get-value project 2>/dev/null)"; fi
REGION="${CLOUD_RUN_REGION:-europe-west1}"
FAIL=0
ok()   { echo "✅ $1"; }
bad()  { echo "❌ $1"; echo "   ↳ Fix: $2"; FAIL=1; }

command -v gcloud >/dev/null 2>&1 && ok "gcloud CLI installed" || { bad "gcloud CLI not found" "Install it: https://cloud.google.com/sdk/docs/install"; exit 1; }

ACCOUNT="$(gcloud config get-value account 2>/dev/null)"
[[ -n "${ACCOUNT}" ]] && ok "gcloud account: ${ACCOUNT}" || bad "No gcloud account" "gcloud auth login"

[[ -n "${PROJECT_ID}" ]] && ok "Project: ${PROJECT_ID} (region ${REGION})" || { bad "No project selected" "gcloud config set project <YOUR_GCP_PROJECT_ID>"; exit 1; }

if gcloud auth application-default print-access-token >/dev/null 2>&1; then ok "Application Default Credentials (ADC) available"
else bad "No Application Default Credentials" "gcloud auth application-default login"; fi

BILLING="$(gcloud billing projects describe "${PROJECT_ID}" --format='value(billingEnabled)' 2>/dev/null)"
[[ "${BILLING}" == "True" ]] && ok "Billing enabled" || bad "Billing not enabled or not visible (${BILLING:-unknown})" "Link a billing account: https://cloud.google.com/billing/docs/how-to/modify-project"

ENABLED="$(gcloud services list --enabled --project "${PROJECT_ID}" --format='value(config.name)' 2>/dev/null)"
for API in run.googleapis.com cloudbuild.googleapis.com artifactregistry.googleapis.com aiplatform.googleapis.com; do
  grep -qx "${API}" <<<"${ENABLED}" && ok "API enabled: ${API}" || bad "API disabled: ${API}" "./setup.sh (or: gcloud services enable ${API} --project ${PROJECT_ID})"
done

if gcloud run services list --project "${PROJECT_ID}" --region "${REGION}" >/dev/null 2>&1; then ok "Cloud Run access in ${REGION}"
else bad "Cannot list Cloud Run services" "Ask for roles/run.admin on ${PROJECT_ID}"; fi

echo "… Testing Nano Banana (gemini-3.1-flash-image, 1 small image)…"
TOKEN="$(gcloud auth print-access-token 2>/dev/null)"
RESP="$(curl -s -X POST \
  -H "Authorization: Bearer ${TOKEN}" -H "Content-Type: application/json" -H "x-goog-user-project: ${PROJECT_ID}" \
  "https://aiplatform.googleapis.com/v1/projects/${PROJECT_ID}/locations/global/publishers/google/models/gemini-3.1-flash-image:generateContent" \
  -d '{"contents":[{"role":"user","parts":[{"text":"A small blue circle on a white background"}]}],"generationConfig":{"responseModalities":["IMAGE"]}}')"
RESULT="$(python3 -c 'import json,sys
try:
    d=json.loads(sys.stdin.read())
except Exception:
    print("ERR invalid response"); sys.exit()
if "error" in d:
    print("ERR "+str(d["error"].get("status"))+": "+str(d["error"].get("message"))[:160]); sys.exit()
parts=d.get("candidates",[{}])[0].get("content",{}).get("parts",[])
print("OK" if any("inlineData" in p for p in parts) else "ERR no image returned")' <<<"${RESP}")"
if [[ "${RESULT}" == "OK" ]]; then ok "Nano Banana image generation works"
else bad "Nano Banana test failed (${RESULT})" "Enable aiplatform.googleapis.com, check the model is available for your project and that your account has roles/aiplatform.user"; fi

echo
if [[ "${FAIL}" == "0" ]]; then echo "🎉 All checks passed — ready for Cloud Run and Nano Banana."; else echo "⚠️  Fix the ❌ items above, then re-run ./scripts/check-cloud.sh"; exit 1; fi
