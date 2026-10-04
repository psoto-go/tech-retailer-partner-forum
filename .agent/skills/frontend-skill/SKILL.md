---
name: frontend-skill
description: Designs the AuraTech Fitbit Employee Marketing Campaign UI live in Google Stitch MCP, presents the Stitch visual proposal for approval, and implements templates/campaign.html by combining Stitch's generated <main> layout with the exact <head>, <header>, and <footer> shell from templates/poll.html.
---

# AuraTech Frontend & Google Stitch Skill (`frontend-skill`)

Use this skill whenever designing and building the frontend for the **Fitbit Employee Marketing Campaign** (the "Google Fitbit Air Challenge" Jira ticket `{TICKET_KEY}`, discovered at runtime via the Jira MCP).

> **CRITICAL RULE — NO HARDCODED UI, 100% STITCH-GENERATED `<main>` + EXACT `poll.html` SHELL**:
> 1. You must generate the UI dynamically in **Google Stitch MCP** (`generate_screen_from_text`) following the existing context of `templates/index.html` and `templates/poll.html`.
> 2. Never invent a different top navigation bar (forbidden: `"Catalog"`, `"Community Poll"`, `"Live Results"`, dark `bg-slate-900` top announcement bars, or blue `"A"` box logos). The navigation menu across the entire site is strictly:
>    `Store` (`/`) | `Fitbit` (`/`) | `Wearables` (`/`) | `Accessories` (`/`) | `Live Role Poll` (`/poll`) | `Fitbit Campaign` (`/campaign`) | `Support` (`/admin`).

---

## Phase 1: Read Existing Context, Generate Screen in Google Stitch & Pause for Approval

### Step 1.1: Inspect `templates/poll.html` and `templates/index.html`
Read `templates/poll.html` (lines 1–165 and 275–295) and `templates/index.html` (lines 115–150) so you have the exact AuraTech `<head>` Tailwind configuration, `<header>` TopNavBar structure, and `<footer>`.

### Step 1.2: Pre-flight — verify access to the shared Stitch project
Call `get_project` with `name: "projects/11024850840388252926"`. The response must succeed and list the design system `assets/e0fecde15a2549a9b793168efec1fa4f`.
If it fails (*permission denied*, *not found*): **STOP**. Tell the user to `git pull` (stale project ID) and to verify that the Google account that generated the Stitch API key in `mcp_config.json` can open the shared project (README → Troubleshooting). Do NOT call `create_project`, do NOT pick another project via `list_projects`, do NOT generate anywhere other than `11024850840388252926`.

### Step 1.3: Call Google Stitch MCP (`generate_screen_from_text`)
Call `generate_screen_from_text` using the Stitch project for this repository:

- **`projectId`**: `"11024850840388252926"`
- **`designSystem`**: `"assets/e0fecde15a2549a9b793168efec1fa4f"` (AuraTech Minimal Hardware)
- **`deviceType`**: `"DESKTOP"`
- **`modelId`**: `"GEMINI_3_8_FLASH"`
- **`prompt`**:
  ```text
  AuraTech - Fitbit Marketing Campaign Studio and Live Voting Leaderboard.

  PLATFORM: Web, Desktop-first 12-column responsive layout (max-w-[1440px]) matching the existing AuraTech Storefront and Live Audience Role Poll screens in this project.

  STRICT TOP NAVIGATION BAR (NO TOP ANNOUNCEMENT BANNER ABOVE HEADER):
  - Sticky top header (h-20, bg-surface/90, border-b border-outline-variant) with the clean text wordmark "AuraTech" on the left (no icon box, no 4-color dots badge).
  - Navigation links in exact order: Store, Fitbit, Wearables, Accessories, Live Role Poll, Fitbit Campaign (active tab with bottom primary blue underline), Support.
  - Right side of header: LIVE SYNC green pulse badge, TOTAL VOTES counter pill, and Bag (0) icon.

  MAIN CONTENT STRUCTURE (<main>):
  1. Page Header Banner: Eyebrow label "PARTNER FORUM 2026 • GOOGLE FITBIT AIR GIVEAWAY", main headline "Google Fitbit Air Challenge", subtitle "Create the next campaign visual for Google Fitbit Air. The most-voted image wins a Google Fitbit Air.", and emerald status pill "1 Vote Per Employee • Live Leaderboard".
  2. 12-Column Split Content Grid:
     - Left Column (4 cols):
       a) Scan to Participate QR Code Card: Eyebrow pill "SCAN TO GENERATE & VOTE", title "Join from Your Phone", centered square QR code image frame, and copyable /campaign URL bar with Copy button.
       b) Vertex AI • Nano Banana (gemini-3.1-flash-image) Prompt Studio Card: Two separate clean text inputs for "Name" and "Company" (both completely blank with NO placeholder text inside the inputs), a small "Official product reference" thumbnail of the Google Fitbit Air (screenless woven fabric band), a "Your campaign scene" textarea (also blank with NO placeholder text), NO suggestion chips, NO example prompts or sample scenes, and NO device selector pills (the product is always Google Fitbit Air), and primary button "Generate Fitbit Air Campaign Image".
     - Right Column (8 cols):
       Live Campaign Leaderboard header bar with total submissions counter, followed by a 2-column responsive grid of generated Google Fitbit Air campaign cards ranked by votes (#1 LEADING badge, 4:3 campaign visual, prompt caption, creator Name & Company, vote count + percentage progress bar, and 1-click "Vote for Campaign" button).
  3. Footer: Minimalist AuraTech footer matching Live Role Poll with Storefront and Live Role Poll links only. **No reset, clear or delete controls anywhere on the page**: attendees open this URL on their phones and must never be able to wipe the campaign.
  ```

### Step 1.4: Present `stitch_design_proposal.md` Artifact & Ask for Approval
1. From the `generate_screen_from_text` response (or `get_screen`), extract `screenshot.downloadUrl` and `htmlCode.downloadUrl`.
2. Download the screenshot image into the artifact directory (or workspace root) using `curl -sL "<screenshot.downloadUrl>" -o <path>/stitch_campaign_preview.png`.
3. Create the artifact `stitch_design_proposal.md` embedding the downloaded screenshot (`![AuraTech Fitbit Campaign Studio](/absolute/path/to/stitch_campaign_preview.png)`) and summarizing the Stitch screen resource ID and layout components.
4. **Ask the user for approval** before proceeding to Phase 2.

---

## Phase 2: Implement `templates/campaign.html` from Stitch HTML + Exact `poll.html` Shell (After Approval)

### Step 2.1: Download the Stitch-Generated HTML
Download the HTML generated by Stitch from `htmlCode.downloadUrl`:
```bash
curl -sL "<htmlCode.downloadUrl>" -o /tmp/stitch_campaign.html
```

### Step 2.2: Build `templates/campaign.html` Preserving the Exact `poll.html` Shell
Construct `templates/campaign.html` by combining:
1. **Verbatim `<head>` and `<header>` from `templates/poll.html` (lines 1–153)**:
   - Keep the exact Tailwind config (`surface`, `primary`, `outline-variant`, `Plus Jakarta Sans`, `Inter`) and the exact `<header>` from `templates/poll.html`.
   - In `<nav>`, keep the exact links (`Store`, `Fitbit`, `Wearables`, `Accessories`, `Live Role Poll`, `Fitbit Campaign`, `Support`), moving the active blue underline (`<span class="absolute bottom-0 left-0 w-full h-[2px] bg-[#005bbf]"></span>`) to `Fitbit Campaign`:
     ```html
     <a class="text-on-surface-variant hover:text-primary transition-colors text-label-md font-label-md" href="/">Store</a>
     <a class="text-on-surface-variant hover:text-primary transition-colors text-label-md font-label-md" href="/">Fitbit</a>
     <a class="text-on-surface-variant hover:text-primary transition-colors text-label-md font-label-md" href="/">Wearables</a>
     <a class="text-on-surface-variant hover:text-primary transition-colors text-label-md font-label-md" href="/">Accessories</a>
     <a class="text-on-surface-variant hover:text-primary transition-colors text-label-md font-label-md" href="/poll">Live Role Poll</a>
     <a class="text-primary font-bold text-label-md font-label-md relative py-2" href="/campaign">
       Fitbit Campaign
       <span class="absolute bottom-0 left-0 w-full h-[2px] bg-[#005bbf]"></span>
     </a>
     <a class="text-on-surface-variant hover:text-primary transition-colors text-label-md font-label-md" href="/admin">Support</a>
     ```
2. **Stitch-Generated `<main>` Content from `/tmp/stitch_campaign.html` Wired to Real Backend Endpoints**:
   - Adapt the `<main>` section from `/tmp/stitch_campaign.html` so every interactive element is 100% functional against `campaign_router.py`:
     - **Real Scannable QR Code**: Set the QR `<img>` source dynamically on page load to `'/api/qr?format=png&url=' + encodeURIComponent(window.location.origin + '/campaign')`. Never leave a static placeholder QR graphic.
     - **Real-Time Zero-Seeded Leaderboard (`GET /api/campaign/state`)**: Poll `/api/campaign/state` on load and every 2 seconds (`setInterval(refreshCampaign, 2000)`). **Remove any static/sample poster cards generated by Stitch in the HTML** so the leaderboard starts cleanly at `0` votes and `0` submissions until an attendee generates the first poster, and renders each submission card dynamically (`item.imageUrl`, `item.prompt`, `item.author` / `item.name` + `item.company`, `item.votes`, `item.percentage`).
     - **Form Inputs for `Name` and `Company` (STRICTLY NO PLACEHOLDERS)**: Ensure the image generation form has two separate text inputs: **Name** (`id="author-name"`) and **Company** (`id="author-company"`). **Remove any `placeholder` or pre-filled `value` attributes** from the `Name`, `Company`, and `Prompt` inputs so the fields appear completely clean and blank. **No idea-seeding anywhere**: no suggestion chips, no example prompts, no sample scenes, no placeholder text and no helper examples in the prompt studio (Name, Company and the campaign-scene textarea are completely blank). Attendees must come up with their own idea. The only image on the form is the official Fitbit Air product reference thumbnail. Leaderboard cards DO keep each submission's prompt caption.
     - **Nano Banana Image Generation (`POST /api/campaign/generate`)**: Wire the `Name` input, `Company` input, `Prompt` textarea and Generate button (there are NO scene chips: if Stitch rendered any chips, example prompts or sample scenes, delete them) to send `POST /api/campaign/generate` with `{ prompt, name, company, voterId, author: company ? (name + ' (' + company + ')') : name }` (the same `voterId` from `localStorage` used for voting — the backend stores it as the creator), disabling the button with a `"Generating with Nano Banana..."` spinner while awaiting the response, then calling `renderCampaignState(data.state)`.
     - **Strict 1-Vote-Per-Employee Voting (`POST /api/campaign/vote`)**: Wire each card's vote button to send `POST /api/campaign/vote` with `{ submissionId, voterId }` (where `voterId` is persisted in `localStorage.getItem('auratech_campaign_voter_id')` + `pf_voter_id` cookie). If the employee clicks vote again on the same card (`HTTP 400`), display the error banner (`data.error`).
     - **No Self-Voting UI**: when `item.isMine` is `true`, render a small `Your campaign` badge on the card and render the vote button **disabled** (`disabled`, `aria-disabled="true"`, muted style, label `Your campaign`) — the creator still sees their image, votes and rank. On `HTTP 400` with `data.ownSubmission`, show `data.error` in the banner. Never read or display any creator id.
3. **Verbatim `<footer>` from `templates/poll.html` (lines 278–294)**:
   - **NEVER render a "Reset Campaign" button, link or any UI call to `POST /api/campaign/reset`.** Resets are presenter-only, done from a terminal (`curl -X POST <SERVICE_URL>/api/campaign/reset`, see README).

### Step 2.3: Add Single `"Fitbit Campaign"` Link to `templates/index.html` and `templates/poll.html`
Use `replace_file_content` to insert ONLY the single `"Fitbit Campaign"` link right after the `Live Role Poll` link inside `<nav>` in both `templates/index.html` and `templates/poll.html`:
- In `templates/index.html` (right after `<a ... href="/poll">Live Role Poll</a>`):
  ```html
  <a class="text-label-md font-label-md text-on-surface-variant dark:text-surface-variant hover:text-primary transition-colors" href="/campaign">Fitbit Campaign</a>
  ```
- In `templates/poll.html` (right after the `<a ... href="/poll">...</a>` block):
  ```html
  <a class="text-on-surface-variant hover:text-primary transition-colors text-label-md font-label-md" href="/campaign">Fitbit Campaign</a>
  ```
- In `templates/index.html` ALSO add the hero CTA right after the hero `Add to Bag` button (inside the same `<div class="flex items-center gap-6 pt-2">`):
  ```html
  <a class="border border-primary text-primary hover:bg-primary hover:text-on-primary font-label-lg px-8 py-3 rounded-full transition-all duration-200" href="/campaign">Join the Fitbit Air Challenge</a>
  ```
- **Product fidelity**: The official product image is `static/images/fitbit-air.png` (real Google Store photo). Use it for the "Official product reference" thumbnail in `campaign.html`. Never replace it with a generated image and never invent Fitbit Air specs, colours or prices (only: "Lighter gets mightier", 24/7 tracking, up to a week of battery, Google Health Coach built with Gemini, "From $99.99").
- **STRICT BAN**: Do NOT change any other lines in `templates/index.html` or `templates/poll.html`!
