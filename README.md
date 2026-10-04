# AuraTech — Antigravity Partner Kit (Jira → Stitch → Cloud Run → Nano Banana)

Brownfield demo for **Google Antigravity**. You start from an existing web app: **AuraTech**, a fictional official Google hardware partner storefront with a Live Role Poll. Antigravity picks up a **Jira ticket**, designs the new feature in **Google Stitch**, waits for your approval, implements it and deploys it to **Cloud Run**. The feature is the *Google Fitbit Air Challenge*, where attendees generate campaign images with **Vertex AI Nano Banana** and vote live.

## Architecture

![AuraTech × Antigravity demo architecture](docs/architecture.png)

1. **Developer → Antigravity**: the 4 demo prompts drive the whole session.
2. **Antigravity → Jira Cloud** (Atlassian Rovo MCP): finds your *Google Fitbit Air Challenge* ticket and moves it **To Do → In Progress → Done**.
3. **Antigravity → Google Stitch** (Stitch MCP): generates the campaign screen from the AuraTech design system in **your** Stitch project and waits for your approval.
4. **`./deploy.sh` → Cloud Build → Cloud Run**: `gcloud run deploy --source` on the pre-cached base image from Artifact Registry; a new revision serves the Storefront `/`, the Live Role Poll `/poll` and the new `/campaign` (baseline tag + `./rollback.sh`).
5. **Fitbit Air Challenge → Vertex AI Nano Banana** (`gemini-3.1-flash-image`): generates each attendee's campaign image from the Fitbit Air reference render, authenticated with the Cloud Run service identity.
6. **Audience phones → Cloud Run** over HTTPS after scanning the QR on the stage screen: generate, vote, live leaderboard.

📎 Session takeaways: [Partner Forum Platform Takeaways](https://docs.google.com/presentation/d/1N0hGiLZYCsasegMNkfARWSR2T4soOZ_k/edit)

> [!IMPORTANT]
> This repo contains **no credentials and no personal identifiers**. Every value that belongs to you is a placeholder:
>
> | Placeholder | What it is | Where you get it |
> |---|---|---|
> | `<YOUR_GCP_PROJECT_ID>` | Your Google Cloud project ID | [Cloud console](https://console.cloud.google.com/) → project picker |
> | `<YOUR_STITCH_PROJECT_ID>` | Your own Stitch project | [stitch.withgoogle.com](https://stitch.withgoogle.com/) → **New project** → the digits in the URL `…/projects/<ID>` (Step 2) |
> | `<YOUR_STITCH_DESIGN_SYSTEM_ID>` | The AuraTech design system inside that project | **Leave empty**: Antigravity creates it from `DESIGN.md` on the first run and saves it (`assets/…`) |
>
> **One command:** `./configure.sh` asks for your GCP project ID and Stitch project ID, stores them **outside the repo** in `~/.auratech/<repo>.env` and fills the placeholders. Re-run it any time; after a `git reset` it refills without questions.
>
> **Jira needs no configuration**: Antigravity finds your ticket through your Jira MCP. **Stitch** is your own project (Step 2); nobody shares anything with you.
>
> Antigravity is instructed to **ask you** for any placeholder that is still empty. It never stores tokens or API keys in the repo.

> **Demo code, not a product.** AuraTech is a fictional retailer. This is example code for a live demo: in-memory state, a public Cloud Run service, and **unauthenticated reset endpoints** (`POST /api/campaign/reset`, `POST /api/admin/reset-votes`) — anyone with the URL can wipe the boards. Do not use it in production.

## Prerequisites
- [Google Antigravity](https://antigravity.google/) installed.
- A Google Cloud project with billing enabled, where you can administer Cloud Run, Cloud Build, Artifact Registry, Vertex AI and IAM.
- [gcloud CLI](https://cloud.google.com/sdk/docs/install), `git`, `python3`, and Node.js (for `npx`, used by the Jira MCP).
- A Jira Cloud site where you can create issues.
- A [Google Stitch](https://stitch.withgoogle.com/) account.

```bash
git clone <THIS_REPO_URL> auratech && cd auratech
./configure.sh   # enter your GCP project ID
```

---

## Step 1: Jira MCP (Atlassian Rovo MCP server, OAuth)
Antigravity connects to Jira through the **official Atlassian Rovo MCP server**. You log in with OAuth in your browser, so no API token is stored anywhere.

1. In Antigravity, open **MCP Servers → Manage MCP Servers → View raw config**. This opens `mcp_config.json`.
2. Add this entry inside `mcpServers`:
   ```json
   "atlassian": {
     "command": "npx",
     "args": ["-y", "mcp-remote", "https://mcp.atlassian.com/v2/mcp"]
   }
   ```
3. Save the file and refresh the MCP servers. A browser window opens: sign in to Atlassian, approve the consent screen and select **your** Jira site.
4. If your org restricts AI connectors, ask your Atlassian admin to allow it under **Atlassian Administration → Rovo → Rovo MCP server**.
5. Test it in Antigravity: *"List my Jira projects."*
6. Create the demo ticket. Ask Antigravity:
   > *"Create the Jira ticket described in `docs/JIRA_TICKET.md` in my Jira project and assign it to me."*

   You can also create the ticket manually by copy-pasting [`docs/JIRA_TICKET.md`](docs/JIRA_TICKET.md), and assign it to yourself. No key to configure: Antigravity discovers it.

Official guide: [Get started with the Atlassian Rovo MCP server](https://support.atlassian.com/atlassian-ai-gateway/docs/get-started-with-the-atlassian-remote-mcp-server/).

## Step 2: Stitch MCP
1. Open [stitch.withgoogle.com](https://stitch.withgoogle.com/) → **Settings → API key → Create API key**. Keep the key private.
2. In the same `mcp_config.json`, add:
   ```json
   "stitch": {
     "serverUrl": "https://stitch.googleapis.com/mcp",
     "headers": { "X-Goog-Api-Key": "<YOUR_STITCH_API_KEY>" }
   }
   ```
   Replace `<YOUR_STITCH_API_KEY>` **only in your local `mcp_config.json`**. Never put it in this repo.
3. Still in Stitch, create a project for this demo (**New project**, any name, e.g. *AuraTech*) and copy the digits from its URL `https://stitch.withgoogle.com/projects/<ID>` → `./configure.sh` (or `./configure.sh --set STITCH_PROJECT_ID=<ID>`). Leave the design system empty: Antigravity creates it from `DESIGN.md` on the first run.
4. Refresh the MCP servers and test: *"List my Stitch projects."* Your new project must be in the list (the API key and the project must belong to the same Google account).

Official guide: [Stitch MCP setup](https://stitch.withgoogle.com/docs/mcp/setup).

## Step 3: Load the repo skills into your workspace
The skills and rules live in the repo and load automatically when the repo folder is your Antigravity workspace:

| Path | Purpose |
|---|---|
| `.agent/rules/auratech-architecture.md` | Workspace rules: Jira lifecycle, Stitch, placeholders, credentials policy |
| `.agent/skills/frontend-skill/` | Stitch design proposal + `campaign.html` implementation |
| `.agent/skills/backend-skill/` | `campaign_router.py` with Nano Banana, voting, in-memory state |
| `.agent/skills/deploy-skill/` | Fast Cloud Run deploy + sign-off + Jira close |

1. In Antigravity: **File → Open Folder** → select the cloned repo.
2. Check it: *"Which skills and rules do you have for this workspace?"* It should list `frontend-skill`, `backend-skill`, `deploy-skill` and `auratech-architecture`.
3. If they don't show up, restart the agent (skills are scanned at startup).

## Step 4: Connect Antigravity to your Google Cloud project (Cloud Run + Nano Banana)
Antigravity runs `gcloud` in its terminal with **your** credentials.

```bash
gcloud auth login
gcloud auth application-default login
gcloud config set project <YOUR_GCP_PROJECT_ID>
./setup.sh                  # one-time: APIs, Artifact Registry, Vertex AI access, pre-cached base image
./scripts/check-cloud.sh    # ✅/❌ checks: account, project, billing, APIs, Cloud Run, real Nano Banana test image
```
If you skipped it at clone time, run `./configure.sh` and enter your GCP project ID (it fills `deploy.sh`, `rollback.sh`, `mark-baseline.sh`, `scripts/check-cloud.sh` and the `Dockerfile`).

Do not continue until `check-cloud.sh` prints **🎉 All checks passed**.

Useful docs: [Cloud Run deploy from source](https://cloud.google.com/run/docs/deploying-source-code) · [Public access / invoker IAM check](https://cloud.google.com/run/docs/securing/managing-access#invoker_check) · [Vertex AI image generation](https://cloud.google.com/vertex-ai/generative-ai/docs/image/overview).

## Step 5: Deploy the existing webpage to Cloud Run (baseline)
Optional but recommended once: *"Bootstrap my Stitch project"* — Antigravity uploads `DESIGN.md`, creates the AuraTech design system in your Stitch project, saves its id with `./configure.sh --set STITCH_DESIGN_SYSTEM_ID=…`, and generates the two baseline context screens (storefront, Live Role Poll). If you skip it, it happens automatically at the start of the ticket run. Then ask Antigravity:
> *"Deploy the existing web with `./deploy.sh` and mark it as the baseline with `./mark-baseline.sh`."*

Check the live URL printed by `deploy.sh`:
- `/` shows the storefront with Google Fitbit Air.
- `/poll` shows the Live Role Poll.
- `/campaign` returns **404**. That's expected: the feature doesn't exist yet.

Your GCP project ID lives in `~/.auratech/<repo>.env`, so you never need to commit it. Check it with `./configure.sh --show`.

## Step 6: Generate the new feature from the Jira ticket
In Antigravity:
> *"Do I have any tickets assigned to me?"*

Antigravity finds your "Google Fitbit Air Challenge" ticket, summarises it and asks whether to start. Say yes. It follows the 3-phase lifecycle in `.agent/rules/`:
1. Moves the ticket to **In Progress**, generates the *Google Fitbit Air Challenge* screen in Stitch and **stops for your approval** (Step 7).
2. After approval: builds `campaign_router.py` (Nano Banana with the Fitbit Air reference render) and `templates/campaign.html`, deploys with `./deploy.sh`, and asks whether you're happy and want to close the ticket.
3. On your confirmation: comments the live URL on the ticket and moves it to **Done**.

## Step 7: Approve the Stitch UI
In Phase 1, Antigravity shows the Stitch render (`stitch_design_proposal.md`) and **waits**. Check:
- The header and nav are identical to the existing web, plus `Fitbit Campaign`.
- The form has blank **Name** and **Company** inputs and a blank **Your campaign scene** textarea (no placeholder text, **no suggestion chips or example prompts** — attendees bring their own idea), a QR code card and the live leaderboard. Voting: one active vote per browser and **no self-voting** (own cards show a *Your campaign* badge with the button disabled; the backend rejects it anyway).

Reply *"approved"*, or ask for changes and it will iterate in Stitch before writing any code.

## Step 8: Personal information & credentials policy
- This repo ships **without** personal information: no Jira tokens, no Stitch API keys or personal project IDs, no personal Google Cloud / demo-environment accounts, project IDs or URLs.
- Credentials live **only** on your machine: in the Antigravity `mcp_config.json` (Stitch API key; the Jira OAuth session is managed by `mcp-remote`) and in `gcloud` (your Google account and ADC).
- Whenever a step needs one of these connections, Antigravity **stops and asks you** to provide your own value, pointing to the matching step above. It never invents IDs and never writes secrets into the repo.
- Before sharing your copy, run a quick check:
  ```bash
  git grep -nE "AIza|AQ\.|ATATT|api[_-]?key\s*[:=]|@[a-z0-9-]+\.(com|net)" || echo "clean"
  ```

---

## Between sessions / rehearse again (≈ 2 minutes)
Two sessions 15 minutes apart? One command puts everything back to the clean brownfield baseline:
```bash
./reset-demo.sh
```
It does, in order: Cloud Run `partner-forum-2026` → `baseline` revision (`/campaign` disappears) · `git reset --hard origin/main && git clean -fd` (removes `campaign_router.py`, `templates/campaign.html`, `stitch_design_proposal.md`) · `./configure.sh` refill · Live Role Poll votes → 0 · verification (`/campaign` 404, `/poll` 200, 0 votes).

Then two manual steps (~20 s):
1. **Jira**: move the *Google Fitbit Air Challenge* ticket back to **To Do** and delete the live-URL comment Antigravity left in Phase 3.
2. **Antigravity**: start a **new chat** (same workspace). Stage screen tab: `<SERVICE_URL>/poll`.

Optional: the Stitch screen generated in the previous session stays in your project; it does no harm (Antigravity generates a fresh one each run), delete it from the Stitch UI only if you want a tidy project.

**Resetting the live boards only (presenter, no buttons in the UI on purpose):**
```bash
SERVICE_URL=$(gcloud run services describe partner-forum-2026 --region europe-west1 --format='value(status.url)')
curl -s -X POST "$SERVICE_URL/api/admin/reset-votes"    # Live Role Poll back to 0 votes
curl -s -X POST "$SERVICE_URL/api/campaign/reset"       # Fitbit Air Challenge back to 0 images / 0 votes
```

## Troubleshooting: Stitch pre-flight fails / screen generated in another project
Symptom: Antigravity stops with *permission denied / not found* on `get_project`, or the proposal shows `projects/<something else>/screens/...`.
Cause: `STITCH_PROJECT_ID` is empty, wrong, or belongs to a different Google account than the Stitch API key in `mcp_config.json`.
Fix, then start a **new chat**:
1. `./configure.sh --show` → `STITCH_PROJECT_ID` must be the digits of your project URL; fix with `./configure.sh --set STITCH_PROJECT_ID=<ID>`.
2. In Antigravity ask: *"List my Stitch projects."* → your project must be in the list. If not, regenerate the API key in the Stitch UI **with the account that owns the project** and paste it into `mcp_config.json`.
3. The repo rules hard-stop instead of falling back: Antigravity will refuse to `create_project` or use another `projectId`.

## Repository map
| File | Purpose |
|---|---|
| `main.py` | FastAPI: storefront `/`, Live Role Poll `/poll` `/vote` `/admin`, QR `/api/qr`; auto-mounts `campaign_router.py` if present |
| `templates/`, `static/` | Existing UI (`static/images/fitbit-air.png` = generated product render, also the Nano Banana reference) |
| `DESIGN.md` | AuraTech design system — the source Antigravity uploads to **your** Stitch project to create the design system |
| `docs/JIRA_TICKET.md` | The ticket Antigravity implements |
| `setup.sh`, `Dockerfile.base`, `cloudbuild.base.yaml` | One-time GCP project setup + pre-cached base image (deploys in ~15–20 s) |
| `deploy.sh`, `mark-baseline.sh`, `rollback.sh`, `reset-demo.sh` | Deploy, tag the clean baseline, restore it, full between-sessions reset |
| `scripts/check-cloud.sh` | Step 4 connectivity checks |
| `.agent/` | Antigravity rules and skills |

## Local development (optional)
```bash
pip install -r requirements.txt
uvicorn main:app --reload --port 8080
```

## License and disclaimer
Licensed under the [Apache License 2.0](LICENSE). Contributions: see [CONTRIBUTING.md](CONTRIBUTING.md).

This is not an officially supported Google product. AuraTech is a fictional retailer created for a demo; product names are trademarks of their respective owners.
