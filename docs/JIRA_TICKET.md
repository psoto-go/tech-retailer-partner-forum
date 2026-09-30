# Jira ticket — Google Fitbit Air Challenge

Antigravity creates this ticket in **your** Jira project during README Step 1 (or copy/paste it manually). The resulting key (e.g. `ABC-12`) replaces `<YOUR_JIRA_TICKET_KEY>` in `.agent/rules/` and `.agent/skills/`.

- **Issue type:** Story (or Task)
- **Assignee:** you
- **Status:** To Do

## Summary
Launch the Google Fitbit Air Challenge — Campaign Studio & Real-Time Voting Leaderboard

## Description
### Context & Business Goal
AuraTech (Official Google Hardware Partner) is launching the **Google Fitbit Air Challenge** for a live event with up to 300 concurrent attendees. Attendees scan a live QR code on the main stage screen, generate a campaign visual for Google Fitbit Air using Vertex AI Nano Banana (`gemini-3.1-flash-image`), and vote in real time. **The most-voted image wins a Google Fitbit Air.**

### Product Fidelity (Google Fitbit Air)
- Page title "Google Fitbit Air Challenge"; subtitle "Create the next campaign visual for Google Fitbit Air. The most-voted image wins a Google Fitbit Air."
- Scene chips: **Morning Run**, **Deep Sleep**, **Office to Gym** (no device selector — the product is always Google Fitbit Air).
- Every Nano Banana generation MUST receive the official Google Store photo `static/images/fitbit-air.png` as input reference image: if Fitbit Air appears it must be exactly that product (screenless woven fabric band, same shape and buckle; never a screen or watch face). Do not block user prompts.
- Only official Google Store facts: "Lighter gets mightier", 24/7 tracking, up to a week of battery, Google Health Coach built with Gemini, "From $99.99".

### Mandatory 3-Phase Execution Workflow (.agent/skills/)
Follow `.agent/rules/auratech-architecture.md` and `.agent/skills/` in strict order:

1. **Phase 1 — Move this ticket to `In Progress`, Google Stitch design proposal & visual approval (`frontend-skill` Phase 1)**
   - Preserve the exact AuraTech header (`AuraTech` wordmark; nav `Store | Fitbit | Wearables | Accessories | Live Role Poll | Fitbit Campaign | Support`). No top announcement bar.
   - Generate the **AuraTech - Google Fitbit Air Challenge** screen in Google Stitch with the repository's design system; the form has two separate blank inputs **Name** and **Company** (no placeholder text).
   - Present the Stitch render and **pause for user approval** before writing code.
2. **Phase 2 — Backend, Stitch HTML integration, Cloud Run deploy & sign-off (after approval)**
   - `backend-skill`: `campaign_router.py` with `gemini-3.1-flash-image` (async `client.aio`, `Semaphore(15)`, failover `gemini-2.5-flash-image`, Pillow fallback), reference image on every generation, in-memory state starting at 0, binary PNG endpoint, 1 vote per attendee.
   - `frontend-skill`: `templates/campaign.html` = Stitch `<main>` + exact `<head>/<header>/<footer>` of `templates/poll.html`; add the `Fitbit Campaign` nav link and the hero CTA "Join the Fitbit Air Challenge" (→ `/campaign`).
   - `deploy-skill`: `python3 -m py_compile main.py campaign_router.py` then `./deploy.sh`.
   - Keep this ticket **In Progress** and ask: *"Are you happy with the live implementation, and would you like me to close this Jira ticket?"*
3. **Phase 3 — Close the ticket after user confirmation**
   - Comment with the live `/campaign` URL and Stitch screen ID, then transition to **Done**.
