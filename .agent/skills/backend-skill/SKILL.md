---
name: backend-skill
description: Builds the FastAPI backend router (campaign_router.py) for the AuraTech Fitbit Employee Marketing Campaign (AT-2026) using the latest Vertex AI Nano Banana 2 model (gemini-3.1-flash-image) via non-blocking async client.aio, in-memory RAM state for 300 concurrent attendees, binary PNG streaming, and strict 1-vote-per-employee enforcement.
---

# AuraTech Backend Skill (`backend-skill`)

Use this skill whenever implementing the backend for the **Fitbit Employee Marketing Campaign** (Jira ticket `AT-2026`).

## Architectural Invariants for 300 Concurrent Attendees
1. **Modular Router File (`campaign_router.py`)**:
   - Create `campaign_router.py` in the repository root. Do NOT rewrite `main.py` — `main.py` automatically imports and mounts `campaign_router.router`!
2. **Latest Nano Banana Model (`gemini-3.1-flash-image`) via Non-Blocking Async (`client.aio`)**:
   - Always use **`gemini-3.1-flash-image`** (Nano Banana 2 GA) at `location="global"` via Vertex AI native IAM (`vertexai=True`, no API key needed).
   - **CRITICAL FOR 300 ATTENDEES**: Call `await client.aio.models.generate_content(...)` asynchronously inside an `asyncio.Semaphore(15)` concurrency guard so concurrent 8-second image generations NEVER block the FastAPI event loop for the other 299 attendees voting in real time.
   - Include automatic DSQ burst failover to `gemini-2.5-flash-image` and a fast Pillow PNG fallback so image generation never fails on stage.
3. **Zero External Database (100% In-Memory RAM State)**:
   - Store submissions and votes in memory (`CAMPAIGN_SUBMISSIONS` and `CAMPAIGN_VOTES` dictionaries) on a single 4-vCPU / 4Gi Cloud Run instance (`--max-instances=1 --concurrency=1000`).
4. **Binary Image Endpoint (`GET /api/campaign/images/{image_id}.png`)**:
   - NEVER embed `base64` image strings inside `GET /api/campaign/state`. Serve PNG bytes from `IMAGE_BLOBS[image_id]` with `Cache-Control: public, max-age=86400` so `/api/campaign/state` stays under 2 KB even with 300 attendees polling.
5. **Strict 1-Vote-Per-Employee Enforcement**:
   - Track each voter by `voterId` (sent by the browser from `localStorage`) or the `pf_voter_id` cookie. One ACTIVE vote per voter: voting another card moves the vote; re-voting the same card returns 400.
6. **No Self-Voting (creator cannot vote for their own image)**:
   - `POST /api/campaign/generate` MUST read `voterId` from the JSON body (fallback cookie) and store it on the submission as `creatorId`.
   - `POST /api/campaign/vote` MUST return `400 {"error": "You can't vote for your own campaign image — ask your colleagues to vote for it!", "ownSubmission": true}` when `submission["creatorId"] == voter_id`.
   - `GET /api/campaign/state` exposes a boolean `isMine` per submission (computed server-side) and NEVER exposes `creatorId` (strip it from the public payload).

## Exact Implementation (`campaign_router.py`)
Write the following complete file to `campaign_router.py` in a single `write_to_file` call:

```python
import asyncio
import io
import os
import secrets
import time
from typing import Any, Dict, List

from fastapi import APIRouter, HTTPException, Request, Response
from fastapi.responses import HTMLResponse, JSONResponse
from fastapi.templating import Jinja2Templates
from PIL import Image, ImageDraw

router = APIRouter()
templates = Jinja2Templates(directory="templates")

PROJECT_ID = os.environ.get("GOOGLE_CLOUD_PROJECT", "")

# In-memory RAM store for 300 concurrent attendees (--max-instances=1 --concurrency=1000)
CAMPAIGN_SUBMISSIONS: List[Dict[str, Any]] = []
CAMPAIGN_VOTES: Dict[str, str] = {}  # voter_id -> submission_id (one active vote per voter)
IMAGE_BLOBS: Dict[str, bytes] = {}   # submission_id -> PNG bytes

# Concurrency guard so image generation bursts never starve real-time voting
GEN_SEMAPHORE = asyncio.Semaphore(15)


def _get_voter_id(request: Request) -> str:
    return (
        request.cookies.get("pf_voter_id")
        or getattr(request.state, "voter_id", None)
        or ("v_" + secrets.token_hex(8))
    )


def _generate_fallback_png(prompt: str, author: str) -> bytes:
    """Fast studio-style fallback PNG if Vertex AI quota or network is unavailable."""
    img = Image.new("RGB", (800, 600), color=(244, 243, 247))
    draw = ImageDraw.Draw(img)
    draw.rounded_rectangle([(40, 40), (760, 560)], radius=24, fill=(255, 255, 255), outline=(0, 91, 191), width=4)
    draw.ellipse([(290, 140), (510, 360)], fill=(216, 226, 255), outline=(0, 91, 191), width=8)
    draw.text((345, 235), "FITBIT AI", fill=(0, 26, 65))
    draw.text((80, 420), f"Campaign: {prompt[:55]}", fill=(26, 27, 30))
    draw.text((80, 460), f"Created by: {author}", fill=(65, 71, 84))
    buf = io.BytesIO()
    img.save(buf, format="PNG")
    return buf.getvalue()


# Official Google Store photo of Google Fitbit Air, sent as reference image on EVERY generation
REFERENCE_IMAGE_PATH = os.path.join("static", "images", "fitbit-air.png")
try:
    with open(REFERENCE_IMAGE_PATH, "rb") as _f:
        REFERENCE_IMAGE_BYTES = _f.read()
except OSError:
    REFERENCE_IMAGE_BYTES = b""

FIDELITY_INSTRUCTION = (
    "The attached image is the OFFICIAL Google Store product photo of Google Fitbit Air. "
    "Whenever Google Fitbit Air appears in the generated image it MUST look exactly like the product in the "
    "reference image: a screenless woven fabric band with the same shape, texture, clasp and buckle. "
    "NEVER add a screen, display, watch face, digits or buttons to it and never invent a different Fitbit device. "
    "Other products may appear if the user explicitly asks for them."
)


async def _generate_fitbit_image_bytes(prompt: str, author: str) -> bytes:
    enhanced_prompt = (
        "Commercial marketing photography for the AuraTech Google Fitbit Air Challenge "
        "(AuraTech is an official Google hardware partner). "
        f"Campaign scene: {prompt}. Photorealistic, clean editorial lighting, 4:3 composition. "
        + FIDELITY_INSTRUCTION
    )
    async with GEN_SEMAPHORE:
        try:
            from google import genai
            from google.genai import types

            client = genai.Client(vertexai=True, project=PROJECT_ID, location="global")
            contents: List[Any] = []
            if REFERENCE_IMAGE_BYTES:
                contents.append(types.Part.from_bytes(data=REFERENCE_IMAGE_BYTES, mime_type="image/png"))
            contents.append(enhanced_prompt)
            # Primary: Latest Nano Banana 2 (gemini-3.1-flash-image), DSQ failover: gemini-2.5-flash-image
            for model_id in ("gemini-3.1-flash-image", "gemini-2.5-flash-image"):
                try:
                    response = await client.aio.models.generate_content(
                        model=model_id,
                        contents=contents,
                        config=types.GenerateContentConfig(
                            response_modalities=["IMAGE"],
                        ),
                    )
                    for part in response.candidates[0].content.parts:
                        if part.inline_data and part.inline_data.data:
                            return part.inline_data.data
                except Exception as model_exc:
                    print(f"[Fitbit Campaign] {model_id} error, trying next: {model_exc}")
        except Exception as exc:
            print(f"[Fitbit Campaign] Vertex AI fallback triggered: {exc}")
    return await asyncio.to_thread(_generate_fallback_png, prompt, author)


def _build_campaign_state(voter_id: str) -> Dict[str, Any]:
    counts: Dict[str, int] = {item["id"]: 0 for item in CAMPAIGN_SUBMISSIONS}
    for _, sub_id in CAMPAIGN_VOTES.items():
        if sub_id in counts:
            counts[sub_id] += 1

    total_votes = sum(counts.values())
    my_vote = CAMPAIGN_VOTES.get(voter_id)

    enriched = []
    for item in CAMPAIGN_SUBMISSIONS:
        v = counts.get(item["id"], 0)
        pct = round((v / total_votes) * 100, 1) if total_votes > 0 else 0.0
        public_item = {k: val for k, val in item.items() if k != "creatorId"}  # never leak creator ids
        enriched.append(
            {
                **public_item,
                "votes": v,
                "percentage": pct,
                "isMyVote": (my_vote == item["id"]),
                "isMine": (item.get("creatorId") == voter_id),
            }
        )

    enriched.sort(key=lambda x: (-x["votes"], -x["createdAt"]))
    leader = enriched[0] if (enriched and enriched[0]["votes"] > 0) else None

    return {
        "totalVotes": total_votes,
        "totalSubmissions": len(enriched),
        "myVote": my_vote,
        "leader": leader,
        "submissions": enriched,
    }


@router.get("/campaign", response_class=HTMLResponse)
async def campaign_page(request: Request):
    return templates.TemplateResponse(request=request, name="campaign.html", context={})


@router.get("/api/campaign/state", response_class=JSONResponse)
async def api_campaign_state(request: Request):
    voter_id = _get_voter_id(request)
    return JSONResponse(
        _build_campaign_state(voter_id),
        headers={"Cache-Control": "no-store, no-cache, must-revalidate, max-age=0"},
    )


@router.get("/api/campaign/images/{image_id}.png")
async def api_campaign_image(image_id: str):
    png_bytes = IMAGE_BLOBS.get(image_id)
    if not png_bytes:
        raise HTTPException(status_code=404, detail="Image not found")
    return Response(
        content=png_bytes,
        media_type="image/png",
        headers={"Cache-Control": "public, max-age=86400"},
    )


@router.post("/api/campaign/generate", response_class=JSONResponse)
async def api_campaign_generate(request: Request):
    body = await request.json()
    prompt = (body.get("prompt") or "").strip()
    name = (body.get("name") or "").strip()[:40]
    company = (body.get("company") or "").strip()[:40]
    raw_author = (body.get("author") or "").strip()[:80]
    if name and company:
        author = f"{name} ({company})"
    elif name or company:
        author = name or company
    else:
        author = raw_author or "Partner Attendee"
    if not prompt:
        return JSONResponse({"error": "Prompt is required"}, status_code=400)

    voter_id = body.get("voterId") or _get_voter_id(request)  # same browser id used for voting
    sub_id = "fitbit_" + secrets.token_hex(5)
    png_bytes = await _generate_fitbit_image_bytes(prompt, author)
    IMAGE_BLOBS[sub_id] = png_bytes

    submission = {
        "id": sub_id,
        "prompt": prompt[:160],
        "name": name,
        "company": company,
        "author": author,
        "creatorId": voter_id,  # internal only: enforces the no-self-vote rule
        "model": "gemini-3.1-flash-image",
        "imageUrl": f"/api/campaign/images/{sub_id}.png",
        "createdAt": int(time.time() * 1000),
    }
    CAMPAIGN_SUBMISSIONS.append(submission)

    return {
        "success": True,
        "submission": submission,
        "state": _build_campaign_state(voter_id),
    }


@router.post("/api/campaign/vote", response_class=JSONResponse)
async def api_campaign_vote(request: Request):
    body = await request.json()
    sub_id = body.get("submissionId")
    voter_id = body.get("voterId") or _get_voter_id(request)

    submission = next((s for s in CAMPAIGN_SUBMISSIONS if s["id"] == sub_id), None)
    if submission is None:
        return JSONResponse({"error": "Campaign image not found"}, status_code=404)

    # No self-voting: the creator of an image cannot vote for it
    if submission.get("creatorId") == voter_id:
        return JSONResponse(
            {
                "error": "You can't vote for your own campaign image — ask your colleagues to vote for it!",
                "ownSubmission": True,
                "state": _build_campaign_state(voter_id),
            },
            status_code=400,
        )

    # Strict 1-vote-per-user rule: cannot vote multiple times on the same image
    if CAMPAIGN_VOTES.get(voter_id) == sub_id:
        return JSONResponse(
            {
                "error": "You have already voted for this Fitbit campaign image (1 vote limit per employee).",
                "alreadyVoted": True,
                "state": _build_campaign_state(voter_id),
            },
            status_code=400,
        )

    CAMPAIGN_VOTES[voter_id] = sub_id
    return {
        "success": True,
        "myVote": sub_id,
        "state": _build_campaign_state(voter_id),
    }


@router.post("/api/campaign/reset", response_class=JSONResponse)
async def api_campaign_reset(request: Request):
    CAMPAIGN_SUBMISSIONS.clear()
    CAMPAIGN_VOTES.clear()
    IMAGE_BLOBS.clear()
    voter_id = _get_voter_id(request)
    return {"success": True, "state": _build_campaign_state(voter_id)}
```
