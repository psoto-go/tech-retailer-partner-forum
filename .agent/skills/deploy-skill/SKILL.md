---
name: deploy-skill
description: Verifies the AuraTech FastAPI endpoints locally in <2 seconds without creating a .venv, deploys directly to Google Cloud Run in ~15-20 seconds using the pre-cached Artifact Registry base image (--max-instances=1 --cpu=4 --memory=4Gi --concurrency=1000), and asks the user for implementation sign-off before closing the Jira ticket.
---

# AuraTech Fast Cloud Run Deploy & Jira Sign-Off Skill (`deploy-skill`)

Use this skill to verify and deploy the AuraTech application directly to Google Cloud Run in minimal time, and then ask the user for final sign-off before closing the Jira ticket.

> **SPEED INVARIANT — NEVER CREATE A `.venv` OR RUN `pip install`**:
> Do NOT create a virtual environment (`python -m venv .venv`) or run `pip install -r requirements.txt` locally. Verify syntax with `py_compile` and run `./deploy.sh` directly because the Cloud Run container already has all dependencies pre-cached in the `auratech-base:latest` image referenced by the `FROM` line of `Dockerfile` (built once per GCP project by `./setup.sh`)!

## Step 1: Fast Local Syntax Check (<2 seconds)
Verify Python syntax without installing any packages:

```bash
python3 -m py_compile main.py campaign_router.py
```

## Step 2: Direct Cloud Run Deployment (`./deploy.sh`)
Execute `./deploy.sh` directly from the workspace root:

```bash
./deploy.sh
```

### Why `./deploy.sh` Handles 300 Attendees & Deploys in ~15–20 Seconds
1. **Pre-Cached Base Image**: `Dockerfile` uses the pre-cached `auratech-base:latest` image in the project's own Artifact Registry (built once by `./setup.sh` from `Dockerfile.base`), which already has `fastapi`, `uvicorn`, `google-genai`, `qrcode`, and `pillow` pre-installed (`0` seconds spent on `pip install`).
2. **300-Attendee High-Concurrency Single Instance**: Deploys with `--max-instances=1 --min-instances=1 --cpu=4 --memory=4Gi --concurrency=1000` so all 300 phones scanning the QR code share the exact same in-memory state with zero queueing and sub-millisecond vote latency.

## Step 3: Post-Deploy Live URL Verification & Mandatory User Sign-Off Prompt
1. After `./deploy.sh` finishes, run a quick `curl` check against the deployed Cloud Run URL (`/`, `/poll`, `/campaign`, `/api/campaign/state`, `/api/qr?format=png`) to confirm `HTTP 200`.
2. **DO NOT CLOSE OR TRANSITION THE JIRA TICKET (`{TICKET_KEY}`) YET!** Keep `{TICKET_KEY}` in **`In Progress`**.
3. Present the live Cloud Run `/campaign` URL to the user and **explicitly ask**:
   > *"Are you happy with the live implementation, and would you like me to close Jira ticket {TICKET_KEY}?"*

## Step 4: Phase 3 — Close Jira Ticket (`{TICKET_KEY}` -> `Done`) Upon User Confirmation
Once the user replies confirming they are happy and want to close the ticket:
1. Call the Atlassian / Jira MCP (`addCommentToJiraIssue`) on `{TICKET_KEY}` with a concise summary including the live Cloud Run `/campaign` URL, the Google Stitch Screen resource ID, and the verified endpoints.
2. Call `getTransitionsForJiraIssue` and `transitionJiraIssue` to move `{TICKET_KEY}` to **`Done`**.
