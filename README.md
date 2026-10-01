# AuraTech — Antigravity Partner Kit (Jira → Stitch → Cloud Run → Nano Banana)

Brownfield demo for **Google Antigravity**. You start from an existing web app: **AuraTech**, a fictional official Google hardware partner storefront with a Live Role Poll. Antigravity picks up a **Jira ticket**, designs the new feature in **Google Stitch**, waits for your approval, implements it and deploys it to **Cloud Run**. The feature is the *Google Fitbit Air Challenge*, where attendees generate campaign images with **Vertex AI Nano Banana** and vote live.

> [!IMPORTANT]
> This repo contains **no credentials and no personal identifiers**. Every value that belongs to you is a placeholder:
>
> | Placeholder | What it is | Where you get it |
> |---|---|---|
> | `<YOUR_GCP_PROJECT_ID>` | Your Google Cloud project ID | [Cloud console](https://console.cloud.google.com/) → project picker |
> | `<YOUR_STITCH_PROJECT_ID>` | Your Stitch project (numbers only, no `projects/`) | Created in Step 5 |
> | `<YOUR_STITCH_DESIGN_SYSTEM_ID>` | Your Stitch design system (`assets/…`) | Created in Step 5 |
> | `<YOUR_JIRA_PROJECT_KEY>` | Your Jira project key (e.g. `ABC`) | Your Jira site |
> | `<YOUR_JIRA_TICKET_KEY>` | The ticket Antigravity implements (e.g. `ABC-12`) | Created in Step 1 |
>
> **Set your values with one command:** `./configure.sh` asks for each value (leave blank the ones you don't have yet), stores them **outside the repo** in `~/.auratech/<repo>.env` and fills the placeholders. Re-run it any time; after a `git reset` it refills everything without questions. Antigravity uses `./configure.sh --set KEY=VALUE` when it creates the Jira ticket or the Stitch project for you.
>
> Antigravity is instructed to **ask you** for any placeholder that is still empty. It never stores tokens or API keys in the repo.

## Prerequisites
- [Google Antigravity](https://antigravity.google/) installed.
- A Google Cloud project with billing enabled, where you can administer Cloud Run, Cloud Build, Artifact Registry, Vertex AI and IAM.
- [gcloud CLI](https://cloud.google.com/sdk/docs/install), `git`, `python3`, and Node.js (for `npx`, used by the Jira MCP).
- A Jira Cloud site where you can create issues.
- A [Google Stitch](https://stitch.withgoogle.com/) account.

```bash
git clone <THIS_REPO_URL> auratech && cd auratech
./configure.sh   # enter your GCP project ID and Jira project key now; the rest comes in Steps 1 and 5
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
   > *"Create the Jira ticket described in `docs/JIRA_TICKET.md` in my Jira project `<YOUR_JIRA_PROJECT_KEY>`, assign it to me, and save the new key with `./configure.sh --set JIRA_TICKET_KEY=<key>`."*

   You can also create the ticket manually by copy-pasting [`docs/JIRA_TICKET.md`](docs/JIRA_TICKET.md), then run `./configure.sh` and enter the ticket key.

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
3. Refresh the MCP servers and test: *"List my Stitch projects."*

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

## Step 5: Create the existing webpage in Stitch and deploy it to Cloud Run
The code in `templates/` is the source of truth for the existing web. Stitch gets the same design system, so the new feature matches it. Ask Antigravity:
> *"Set up Stitch for this repo: create a Stitch project called 'AuraTech Storefront', upload `DESIGN.md` and create the design system from it, generate a reference 'AuraTech Storefront' screen, then save both IDs with `./configure.sh --set STITCH_PROJECT_ID=<id> STITCH_DESIGN_SYSTEM_ID=assets/<id>`. Then deploy the existing web with `./deploy.sh` and mark it as the baseline with `./mark-baseline.sh`."*

This uses the Stitch MCP tools `create_project` → `upload_design_md` → `create_design_system_from_design_md` → `generate_screen_from_text`.

Check the live URL printed by `deploy.sh`:
- `/` shows the storefront with Google Fitbit Air.
- `/poll` shows the Live Role Poll.
- `/campaign` returns **404**. That's expected: the feature doesn't exist yet.

Your values live in `~/.auratech/<repo>.env`, so you never need to commit them. Check them with `./configure.sh --show`.

## Step 6: Generate the new feature from the Jira ticket
In Antigravity:
> *"Do I have any tickets assigned to me?"*

Antigravity finds `<YOUR_JIRA_TICKET_KEY>`, summarises it and asks whether to start. Say yes. It follows the 3-phase lifecycle in `.agent/rules/`:
1. Moves the ticket to **In Progress**, generates the *Google Fitbit Air Challenge* screen in Stitch and **stops for your approval** (Step 7).
2. After approval: builds `campaign_router.py` (Nano Banana with the official Fitbit Air reference image) and `templates/campaign.html`, deploys with `./deploy.sh`, and asks whether you're happy and want to close the ticket.
3. On your confirmation: comments the live URL on the ticket and moves it to **Done**.

## Step 7: Approve the Stitch UI
In Phase 1, Antigravity shows the Stitch render (`stitch_design_proposal.md`) and **waits**. Check:
- The header and nav are identical to the existing web, plus `Fitbit Campaign`.
- The form has blank **Name** and **Company** inputs (no placeholder text), scene chips **Morning Run / Deep Sleep / Office to Gym**, a QR code card and the live leaderboard.

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

## Rehearse again (reset to the clean baseline)
```bash
./rollback.sh                                                      # Cloud Run back to the 'baseline' revision (seconds)
git fetch origin && git reset --hard origin/main && git clean -fd  # remove the generated feature files locally
./configure.sh                                                     # refill your values (no questions asked)
```
Then move the Jira ticket back to **To Do**.

## Repository map
| File | Purpose |
|---|---|
| `main.py` | FastAPI: storefront `/`, Live Role Poll `/poll` `/vote` `/admin`, QR `/api/qr`; auto-mounts `campaign_router.py` if present |
| `templates/`, `static/` | Existing UI (`static/images/fitbit-air.png` = official Google Store photo, also the Nano Banana reference) |
| `DESIGN.md` | AuraTech design system for Stitch |
| `docs/JIRA_TICKET.md` | The ticket Antigravity implements |
| `setup.sh`, `Dockerfile.base`, `cloudbuild.base.yaml` | One-time GCP project setup + pre-cached base image (deploys in ~15–20 s) |
| `deploy.sh`, `mark-baseline.sh`, `rollback.sh` | Deploy, tag the clean baseline, restore it |
| `scripts/check-cloud.sh` | Step 4 connectivity checks |
| `.agent/` | Antigravity rules and skills |

## Local development (optional)
```bash
pip install -r requirements.txt
uvicorn main:app --reload --port 8080
```
