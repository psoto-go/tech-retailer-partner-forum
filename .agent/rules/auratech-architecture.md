# AuraTech Workspace Architecture, Jira Lifecycle & Speed Execution Rules

## 0. Placeholders & Credentials Policy (READ FIRST)
- This repository ships WITHOUT personal information. User-specific values are placeholders: `<YOUR_GCP_PROJECT_ID>`, `<YOUR_STITCH_PROJECT_ID>`, `<YOUR_STITCH_DESIGN_SYSTEM_ID>`.
- **Jira needs NO configuration**: the user's Jira MCP is already connected in Antigravity. `{TICKET_KEY}` below is NOT a placeholder to fill; it is the key of the Jira ticket you discover at runtime (Section 2). Never ask the user for a Jira project key or ticket key.
- Before using any of them, check whether it is still an unfilled `<YOUR_...>` placeholder. If it is, STOP and ask the user for their own value, pointing to the matching README step (Stitch → Steps 2 and 5, Google Cloud → Step 4). Never invent IDs. Once the user provides the value (or you create it, e.g. the Stitch project in README Step 5), save it with `./configure.sh --set KEY=VALUE` (keys: `GCP_PROJECT_ID`, `STITCH_PROJECT_ID`, `STITCH_DESIGN_SYSTEM_ID`). This stores the value outside the repo (`~/.auratech/`) and fills `.agent/rules/`, `.agent/skills/`, the `Dockerfile` and the scripts. Do not hand-edit placeholders and never commit the filled values.
- NEVER write credentials into the repository: no Jira/Atlassian tokens, no Stitch API keys, no OAuth tokens, no personal emails or account names. Credentials live only in the user's local Antigravity `mcp_config.json` and in `gcloud`. If a connection fails, give the user the how-to from the README and ask them to fix it with their own account.

### README bootstrap tasks (when the user asks for them)
- **Step 1 — Create the Jira ticket** (only if the user asks): list the user's Jira projects via the Jira MCP; if there is exactly one use it, otherwise ask which one. Create an issue with the Summary and Description of `docs/JIRA_TICKET.md`, assign it to the current user (status To Do). Nothing to save: the ticket is discovered at runtime.
- **Step 5 — Stitch + baseline deploy**: Stitch MCP `create_project` (title "AuraTech Storefront") → `upload_design_md` (base64 of `DESIGN.md`) → `create_design_system_from_design_md` → `generate_screen_from_text` (a reference "AuraTech Storefront" screen matching `templates/index.html`); save the new `projectId` and `designSystem` with `./configure.sh --set STITCH_PROJECT_ID=<id> STITCH_DESIGN_SYSTEM_ID=assets/<id>`; then run `./deploy.sh` and `./mark-baseline.sh` and verify `/` 200, `/poll` 200, `/campaign` 404.

---

## 1. Project & Environment Configuration (Production)
You are working in the **AuraTech — Official Google Hardware Partner** web application repository (`FastAPI` + `Jinja2` + `Tailwind CSS` deployed on Google Cloud Run in the project configured in `gcloud` / `GOOGLE_CLOUD_PROJECT`, region `europe-west1`).

- **Google Cloud project**: `<YOUR_GCP_PROJECT_ID>`
- **Jira**: via the user's Jira MCP (no config). Ticket `{TICKET_KEY}` = the assigned ticket whose summary contains "Google Fitbit Air Challenge" (created from `docs/JIRA_TICKET.md`)
- **Cloud Run Service**: `partner-forum-2026` (deployed via `./deploy.sh`)
- **Google Stitch `projectId` (for this repository)**: `"<YOUR_STITCH_PROJECT_ID>"`
- **Google Stitch `designSystem` (for this repository)**: `"<YOUR_STITCH_DESIGN_SYSTEM_ID>"` (AuraTech Minimal Hardware)
- **Google Stitch `modelId`**: `"GEMINI_3_8_FLASH"`
- **`main.py`**: Core FastAPI server hosting the Storefront (`GET /`) and Live Audience Role Poll (`GET /poll`, `GET /vote`, `GET /admin`, `GET /api/qr`). Automatically mounts `campaign_router.py` if present.
- **`templates/index.html`**: AuraTech Google Hardware Storefront (`Store | Fitbit | Wearables | Accessories | Live Role Poll | Support`).
- **`templates/poll.html`**: Live Audience Role Poll (`PARTNER FORUM 2026`).

---

## 2. Jira Ticket Discovery ("Do I have any tickets assigned to me?")
Whenever the user asks if they have any tickets assigned to them (e.g. *"do i have any tickets assigned to me?"*, *"check my Jira tickets"*, *"what tickets do I have?"*):
1. Immediately query the **Atlassian / Jira MCP** (`searchJiraIssuesUsingJql` with `assignee = currentUser() AND statusCategory != Done ORDER BY updated DESC`, falling back to `summary ~ "Fitbit Air Challenge" ORDER BY updated DESC` if needed) and read the full issue details. The key of the "Google Fitbit Air Challenge" ticket is `{TICKET_KEY}` for the rest of the session.
2. Present a concise summary of the assigned ticket (`{TICKET_KEY}`: Google Fitbit Air Challenge — Campaign Studio & Real-Time Voting Leaderboard) and ask if you should start working on it (**Phase 1: Transition to `In Progress` & generate the Google Stitch UI Design Proposal**).
3. Do not ask the user for Stitch IDs or file paths **once the placeholders are filled** (they are defined above and in `.agent/skills/`). If a `<YOUR_...>` placeholder is still unfilled, follow Section 0.

---

## 3. Mandatory 3-Phase Execution Workflow for `{TICKET_KEY}` / Fitbit Campaign
Whenever the user asks you to work on the assigned Jira ticket (`{TICKET_KEY}` / Fitbit Employee Marketing Campaign), you MUST execute the 3 skills in `.agent/skills/` following this strict 3-phase lifecycle:

### Phase 1: Move Jira to `In Progress`, Design in Google Stitch & Pause for Visual Approval (`frontend-skill` — Phase 1)
1. **Transition Jira Ticket to `In Progress`**: Call the Atlassian / Jira MCP (`getTransitionsForJiraIssue` -> `transitionJiraIssue`) to move `{TICKET_KEY}` to **`In Progress`**.
2. Read `.agent/skills/frontend-skill/SKILL.md` and inspect the `<head>`, `<header>`, and `<footer>` of `templates/poll.html` and `templates/index.html`.
3. Call the **Google Stitch MCP** tool `generate_screen_from_text` using:
   - `projectId`: `"<YOUR_STITCH_PROJECT_ID>"`
   - `designSystem`: `"<YOUR_STITCH_DESIGN_SYSTEM_ID>"`
   - `deviceType`: `"DESKTOP"`
   - `modelId`: `"GEMINI_3_8_FLASH"`
   - Exact prompt from `.agent/skills/frontend-skill/SKILL.md` (preserving the exact AuraTech TopNavBar: `Store | Fitbit | Wearables | Accessories | Live Role Poll | Fitbit Campaign | Support` with NO dark top announcement bar and NO `"Catalog"` or `"Community Poll"` links).
4. Download the generated screen's `screenshot.downloadUrl` and present the visual design proposal in an artifact (`stitch_design_proposal.md`) to the user.
5. **PAUSE and ask the user for visual approval** before writing the backend/frontend code.

### Phase 2: Implement Code from Stitch HTML + Deploy to Cloud Run + Ask Sign-Off (`backend-skill` + `frontend-skill` Phase 2 + `deploy-skill`)
Once the user approves the Stitch design proposal:
1. **`backend-skill`** (`.agent/skills/backend-skill/SKILL.md`):
   - Create `campaign_router.py` in a single `write_to_file` call using the latest **`gemini-3.1-flash-image`** (Nano Banana 2) via non-blocking async `await client.aio.models.generate_content(...)` with an `asyncio.Semaphore(15)` guard.
   - **Official product reference (Fitbit Air fidelity)**: pass `static/images/fitbit-air.png` (official Google Store photo) as `types.Part.from_bytes(..., mime_type="image/png")` together with the text prompt on EVERY generation, plus the fixed fidelity instruction (if Fitbit Air appears it must be exactly the reference: screenless woven fabric band, same shape and buckle, never a screen/watch face). Do NOT block or filter user prompts.
   - **NO external database (no Firestore / no SQL)**: Store all state in Python memory (`CAMPAIGN_SUBMISSIONS`, `CAMPAIGN_VOTES`, `IMAGE_BLOBS`), starting at **0 submissions and 0 votes**, serving PNG bytes via `GET /api/campaign/images/{image_id}.png`.
2. **`frontend-skill` (Phase 2)** (`.agent/skills/frontend-skill/SKILL.md`):
   - Download the HTML code generated by Stitch (`htmlCode.downloadUrl` from the Stitch screen).
   - Build `templates/campaign.html` using **100% of the exact `<head>`, `<header>` (TopNavBar), and `<footer>` copied verbatim from `templates/poll.html`** (with `Fitbit Campaign` active in `<nav>`) combined with the **`<main>` layout generated by Stitch**, wired to the real FastAPI endpoints (`/api/qr?format=png`, `POST /api/campaign/generate`, `GET /api/campaign/state`, `POST /api/campaign/vote`).
   - **Form Fields Rule (`Name` & `Company` — NO Placeholders)**: The image generation form MUST include two separate input fields: **Name** and **Company**, both strictly **WITHOUT placeholder text** (`placeholder` omitted or empty `""`, no pre-filled sample text).
   - **Google Fitbit Air Challenge content**: title "Google Fitbit Air Challenge", subtitle "Create the next campaign visual for Google Fitbit Air. The most-voted image wins a Google Fitbit Air.", scene chips **Morning Run / Deep Sleep / Office to Gym** (NO device selector — the product is always Google Fitbit Air). Only official Google Store facts; never invent specs, colours or prices.
   - Add ONLY the single `<a class="text-on-surface-variant hover:text-primary transition-colors text-label-md font-label-md" href="/campaign">Fitbit Campaign</a>` link inside `<nav>` right after `Live Role Poll` in `templates/index.html` and `templates/poll.html`, plus the hero CTA `Join the Fitbit Air Challenge` (→ `/campaign`) right after the hero `Add to Bag` button in `templates/index.html`. **NEVER alter anything else in `templates/index.html` or `templates/poll.html`.**
3. **`deploy-skill`** (`.agent/skills/deploy-skill/SKILL.md`):
   - **NEVER create a `.venv` or run `pip install`** (all packages are pre-installed).
   - Run `python3 -m py_compile main.py campaign_router.py` and execute `./deploy.sh` to deploy directly to Cloud Run in ~15–20 seconds.
4. **STRICT BAN ON AUTO-CLOSING JIRA IN PHASE 2**:
   - Keep `{TICKET_KEY}` in **`In Progress`** when `./deploy.sh` finishes. Do **NOT** transition `{TICKET_KEY}` to `In Review` or `Done` automatically!
   - Present the live Cloud Run `/campaign` URL to the user and **PAUSE to ask**:
     *"Are you happy with the live implementation, and would you like me to close Jira ticket {TICKET_KEY}?"*

### Phase 3: Close Jira Ticket After User Confirmation
Only after the user confirms they are happy with the implementation and want to close the ticket:
1. Add a comment to `{TICKET_KEY}` via Atlassian / Jira MCP (`addCommentToJiraIssue`) with the live Cloud Run `/campaign` URL, the Google Stitch screen resource name, and a summary of the implemented endpoints.
2. Transition `{TICKET_KEY}` to **`Done`** (`getTransitionsForJiraIssue` -> `transitionJiraIssue`) and confirm completion to the user.
