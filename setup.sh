#!/usr/bin/env bash
# One-time setup of a NEW Google Cloud project for the AuraTech demo.
# Usage: GOOGLE_CLOUD_PROJECT=<your-project-id> ./setup.sh
set -euo pipefail

DEFAULT_PROJECT="<YOUR_GCP_PROJECT_ID>"
if [[ -n "${GOOGLE_CLOUD_PROJECT:-}" ]]; then PROJECT_ID="${GOOGLE_CLOUD_PROJECT}"
elif [[ "${DEFAULT_PROJECT}" != "<YOUR_GCP_PROJECT_ID>" ]]; then PROJECT_ID="${DEFAULT_PROJECT}"
else PROJECT_ID="$(gcloud config get-value project 2>/dev/null)"; fi
REGION="${CLOUD_RUN_REGION:-europe-west1}"
AR_REPO="cloud-run-source-deploy"
BASE_IMAGE="${REGION}-docker.pkg.dev/${PROJECT_ID}/${AR_REPO}/auratech-base:latest"

if [[ -z "${PROJECT_ID}" ]]; then
  echo "❌ Set GOOGLE_CLOUD_PROJECT=<your-project-id> (or run: gcloud config set project <id>)"; exit 1
fi
echo "🔧 Setting up project ${PROJECT_ID} (${REGION})..."

echo "1/5 Enabling APIs (Cloud Run, Cloud Build, Artifact Registry, Vertex AI)..."
gcloud services enable run.googleapis.com cloudbuild.googleapis.com \
  artifactregistry.googleapis.com aiplatform.googleapis.com --project "${PROJECT_ID}"

echo "2/5 Creating Artifact Registry repo '${AR_REPO}' (if missing)..."
gcloud artifacts repositories describe "${AR_REPO}" --location "${REGION}" --project "${PROJECT_ID}" >/dev/null 2>&1 || \
  gcloud artifacts repositories create "${AR_REPO}" --repository-format=docker \
    --location "${REGION}" --project "${PROJECT_ID}"

echo "3/5 Granting the Cloud Run runtime service account access to Vertex AI (Gemini / Nano Banana)..."
PROJECT_NUMBER="$(gcloud projects describe "${PROJECT_ID}" --format='value(projectNumber)')"
RUNTIME_SA="${PROJECT_NUMBER}-compute@developer.gserviceaccount.com"
gcloud projects add-iam-policy-binding "${PROJECT_ID}" \
  --member "serviceAccount:${RUNTIME_SA}" --role roles/aiplatform.user --condition=None >/dev/null
# Needed in newer projects where Cloud Build builds with the default compute service account.
gcloud projects add-iam-policy-binding "${PROJECT_ID}" \
  --member "serviceAccount:${RUNTIME_SA}" --role roles/run.builder --condition=None >/dev/null

echo "4/5 Building the pre-cached base image ${BASE_IMAGE} ..."
gcloud builds submit --project "${PROJECT_ID}" --region "${REGION}" \
  --config cloudbuild.base.yaml --substitutions "_BASE_IMAGE=${BASE_IMAGE}" .

echo "5/5 Pointing Dockerfile at your base image..."
sed -i.bak "1s|^FROM .*|FROM ${BASE_IMAGE}|" Dockerfile && rm -f Dockerfile.bak

echo "✅ Setup complete. Next: ./deploy.sh  then  ./mark-baseline.sh"
