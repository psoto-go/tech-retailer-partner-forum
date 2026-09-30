FROM europe-west1-docker.pkg.dev/<YOUR_GCP_PROJECT_ID>/cloud-run-source-deploy/auratech-base:latest

WORKDIR /app

ENV PYTHONDONTWRITEBYTECODE=1 \
    PYTHONUNBUFFERED=1 \
    PORT=8080

COPY . .

EXPOSE 8080

CMD ["uvicorn", "main:app", "--host", "0.0.0.0", "--port", "8080"]
