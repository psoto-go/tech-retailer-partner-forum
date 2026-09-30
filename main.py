import asyncio
import base64
import io
import json
import os
import random
import secrets
import time
import uuid
from datetime import datetime, timezone
from pathlib import Path
from typing import Any, Dict, List, Optional, Set

import qrcode
import qrcode.image.svg
from fastapi import FastAPI, HTTPException, Request, Response
from fastapi.responses import HTMLResponse, JSONResponse, PlainTextResponse, StreamingResponse
from fastapi.staticfiles import StaticFiles
from fastapi.templating import Jinja2Templates

app = FastAPI(
    title="AuraTech - Official Google Hardware Partner",
    description="Minimalist Google Hardware Storefront & Live Audience Role Poll",
    version="1.3.0",
)

BASE_DIR = Path(__file__).resolve().parent
DATA_FILE = BASE_DIR / "data" / "store.json"
DATA_FILE.parent.mkdir(parents=True, exist_ok=True)

app.mount("/static", StaticFiles(directory=str(BASE_DIR / "static")), name="static")
templates = Jinja2Templates(directory=str(BASE_DIR / "templates"))

PROJECT_ID = os.environ.get("GOOGLE_CLOUD_PROJECT", "")
REGION = os.environ.get("CLOUD_RUN_REGION", "europe-west1")
SERVICE_NAME = os.environ.get("K_SERVICE", "partner-forum-2026")
REVISION = os.environ.get("K_REVISION", "auratech-v1.3")

DEFAULT_STORE: Dict[str, Any] = {
    "settings": {
        "eventName": "Partner Forum 2026",
        "question": "What best describes your role today?",
        "adminPin": os.environ.get("ADMIN_PIN", "partner2026"),
        "votingOpen": True,
        "allowVoteChanges": True,
        "showLiveResultsToAudience": True,
    },
    "options": [
        {
            "id": "opt_devs",
            "title": "Developers & Engineers",
            "subtitle": "Software Engineers, Fullstack, AI/ML & DevOps",
            "category": "Engineering",
            "icon": "code",
            "color": "emerald",
            "order": 1,
        },
        {
            "id": "opt_tech_arch",
            "title": "Technical & Architects",
            "subtitle": "Cloud Architects, Solutions Architects, Tech Leads",
            "category": "Engineering",
            "icon": "cpu",
            "color": "cyan",
            "order": 2,
        },
        {
            "id": "opt_consultants",
            "title": "Consultants & SI Partners",
            "subtitle": "System Integrators, Solution Providers & Advisory Partners",
            "category": "Business",
            "trackTag": "Partner Ecosystem Track",
            "icon": "clipboard",
            "color": "orange",
            "order": 3,
        },
        {
            "id": "opt_marketing",
            "title": "Marketing & Growth",
            "subtitle": "CMO, Product Marketing, Brand & Demand Gen",
            "category": "Business",
            "icon": "flask",
            "color": "rose",
            "order": 4,
        },
        {
            "id": "opt_clevel",
            "title": "C-Level & Founders",
            "subtitle": "CEO, CTO, CIO, VP, Managing Director",
            "category": "Leadership",
            "icon": "star",
            "color": "blue",
            "order": 5,
        },
        {
            "id": "opt_sales_bd",
            "title": "Sales & Partnerships",
            "subtitle": "Alliance Managers, BD Directors, Account Execs",
            "category": "Business",
            "icon": "briefcase",
            "color": "purple",
            "order": 6,
        },
        {
            "id": "opt_product_ops",
            "title": "Product & Operations",
            "subtitle": "Product Managers, Delivery Leads, Agile Coaches",
            "category": "Leadership",
            "icon": "box",
            "color": "amber",
            "order": 7,
        },
    ],
    "votes": {},
    "history": [],
}

store: Dict[str, Any] = json.loads(json.dumps(DEFAULT_STORE))
sse_queues: Set[asyncio.Queue] = set()


def load_store() -> None:
    global store
    try:
        if DATA_FILE.exists():
            parsed = json.loads(DATA_FILE.read_text(encoding="utf-8"))
            if isinstance(parsed.get("options"), list):
                store.update(parsed)
                # Strip any legacy pre-seeded sim_ votes on startup if not explicitly created in this runtime
                votes = store.get("votes", {})
                if all(k.startswith("sim_") or k == "v_12e93b8530c79c391c4c90f3" for k in votes.keys()):
                    store["votes"] = {}
                    save_store()
        else:
            save_store()
    except Exception as exc:
        print(f"Error loading store.json: {exc}")


def save_store() -> None:
    try:
        tmp_file = DATA_FILE.with_suffix(f".tmp.{int(time.time() * 1000)}")
        tmp_file.write_text(json.dumps(store, indent=2), encoding="utf-8")
        tmp_file.replace(DATA_FILE)
    except Exception as exc:
        print(f"Error saving store.json: {exc}")


load_store()


def get_voter_id(request: Request) -> str:
    voter_id = request.cookies.get("pf_voter_id")
    if not voter_id or len(voter_id) < 8:
        voter_id = getattr(request.state, "voter_id", None) or ("v_" + secrets.token_hex(12))
    return voter_id


@app.middleware("http")
async def voter_cookie_middleware(request: Request, call_next):
    voter_id = request.cookies.get("pf_voter_id")
    new_cookie = False
    if not voter_id or len(voter_id) < 8:
        voter_id = "v_" + secrets.token_hex(12)
        new_cookie = True
    request.state.voter_id = voter_id
    response: Response = await call_next(request)
    response.headers["X-Content-Type-Options"] = "nosniff"
    response.headers["X-Frame-Options"] = "SAMEORIGIN"
    response.headers["Referrer-Policy"] = "strict-origin-when-cross-origin"
    if new_cookie:
        is_secure = request.url.scheme == "https" or request.headers.get("x-forwarded-proto") == "https"
        response.set_cookie(
            key="pf_voter_id",
            value=voter_id,
            max_age=30 * 24 * 60 * 60,
            httponly=False,
            samesite="lax",
            secure=is_secure,
        )
    return response


def get_category(opt: Dict[str, Any]) -> str:
    if opt.get("category"):
        return opt["category"]
    oid = opt.get("id", "")
    if oid in ("opt_devs", "opt_tech_arch", "dev", "tech"):
        return "Engineering"
    if oid in ("opt_clevel", "opt_product_ops", "exec", "prod"):
        return "Leadership"
    return "Business"


def get_public_stats(voter_id: Optional[str] = None) -> Dict[str, Any]:
    counts: Dict[str, int] = {opt["id"]: 0 for opt in store["options"]}
    votes_map: Dict[str, str] = store.get("votes", {})
    total_votes = len(votes_map)

    for _, opt_id in votes_map.items():
        if opt_id in counts:
            counts[opt_id] += 1

    options_with_stats = []
    for opt in store["options"]:
        c = counts.get(opt["id"], 0)
        pct = round((c / total_votes) * 100, 1) if total_votes > 0 else 0.0
        title = opt.get("title") or opt.get("label") or ""
        options_with_stats.append(
            {
                **opt,
                "title": title,
                "label": title,
                "category": get_category(opt),
                "count": c,
                "votes": c,
                "percentage": pct,
            }
        )

    if total_votes > 0:
        options_with_stats.sort(key=lambda x: (-x["count"], x.get("order", 0)))
    else:
        options_with_stats.sort(key=lambda x: x.get("order", 0))

    leader = None
    max_count = 0
    for opt in options_with_stats:
        if opt["count"] > max_count:
            max_count = opt["count"]
            leader = opt["id"]

    user_vote = votes_map.get(voter_id) if voter_id else None
    event_name = store["settings"].get("eventName", "Partner Forum 2026")
    question = store["settings"].get("question", "What best describes your role today?")
    voting_open = store["settings"].get("votingOpen", True)

    return {
        "eventName": event_name,
        "question": question,
        "votingOpen": voting_open,
        "settings": {
            "eventName": event_name,
            "question": question,
            "votingOpen": voting_open,
            "allowVoteChanges": store["settings"].get("allowVoteChanges", True),
            "showLiveResultsToAudience": store["settings"].get("showLiveResultsToAudience", True),
        },
        "totalVotes": total_votes,
        "leader": leader,
        "options": options_with_stats,
        "recentActivity": store.get("history", [])[-8:],
        "userVote": user_vote,
        "myVote": user_vote,
    }


def broadcast_state() -> None:
    payload = json.dumps(get_public_stats())
    msg = f"data: {payload}\n\n"
    for q in list(sse_queues):
        try:
            q.put_nowait(msg)
        except Exception:
            sse_queues.discard(q)


# --- FRONTEND PAGES ---

@app.get("/", response_class=HTMLResponse)
async def storefront(request: Request):
    """Renders the exact Google Stitch AuraTech Storefront."""
    return templates.TemplateResponse(
        request=request,
        name="index.html",
        context={
            "project_id": PROJECT_ID,
            "region": REGION,
            "service_name": SERVICE_NAME,
            "revision": REVISION,
        },
    )


@app.get("/poll", response_class=HTMLResponse)
async def role_poll_stage(request: Request):
    """Renders the exact Google Stitch AuraTech Live Audience Role Poll screen."""
    return templates.TemplateResponse(
        request=request,
        name="poll.html",
        context={
            "project_id": PROJECT_ID,
            "region": REGION,
            "service_name": SERVICE_NAME,
            "revision": REVISION,
        },
    )


@app.get("/vote", response_class=HTMLResponse)
async def role_poll_mobile_vote(request: Request):
    """Renders the mobile role selection page opened via QR code."""
    return templates.TemplateResponse(
        request=request,
        name="vote.html",
        context={
            "project_id": PROJECT_ID,
            "region": REGION,
        },
    )


@app.get("/admin", response_class=HTMLResponse)
async def role_poll_admin(request: Request):
    """Renders the Admin Control Panel for managing roles and votes."""
    return templates.TemplateResponse(
        request=request,
        name="admin.html",
        context={
            "project_id": PROJECT_ID,
            "region": REGION,
        },
    )


# --- API ENDPOINTS ---

@app.get("/healthz", response_class=PlainTextResponse)
async def healthz():
    return "OK"


@app.get("/api/health", response_class=JSONResponse)
async def health():
    return {
        "status": "ok",
        "store": "AuraTech - Official Google Hardware Partner",
        "service": SERVICE_NAME,
        "revision": REVISION,
        "total_votes": len(store.get("votes", {})),
        "timestamp": datetime.now(timezone.utc).isoformat(),
    }


@app.get("/api/state", response_class=JSONResponse)
async def api_state(request: Request):
    voter_id = get_voter_id(request)
    return JSONResponse(
        get_public_stats(voter_id),
        headers={"Cache-Control": "no-store, no-cache, must-revalidate, max-age=0"},
    )


@app.get("/api/stream")
async def api_stream(request: Request):
    voter_id = get_voter_id(request)
    q: asyncio.Queue = asyncio.Queue()
    sse_queues.add(q)

    async def event_generator():
        try:
            initial = json.dumps(get_public_stats(voter_id))
            yield f"data: {initial}\n\n"
            while True:
                if await request.is_disconnected():
                    break
                try:
                    msg = await asyncio.wait_for(q.get(), timeout=10.0)
                    yield msg
                except asyncio.TimeoutError:
                    yield ": ping\n\n"
        finally:
            sse_queues.discard(q)

    return StreamingResponse(
        event_generator(),
        media_type="text/event-stream",
        headers={
            "Cache-Control": "no-cache, no-transform",
            "Connection": "keep-alive",
            "X-Accel-Buffering": "no",
        },
    )


# Map short aliases if clicked from static cards
OPTION_ALIASES = {
    "dev": "opt_devs",
    "tech": "opt_tech_arch",
    "partner": "opt_consultants",
    "mktg": "opt_marketing",
    "exec": "opt_clevel",
    "sales": "opt_sales_bd",
    "prod": "opt_product_ops",
}


@app.post("/api/vote", response_class=JSONResponse)
async def api_submit_vote(request: Request):
    body = await request.json()
    raw_option_id = body.get("optionId")
    option_id = OPTION_ALIASES.get(raw_option_id, raw_option_id)
    voter_id = get_voter_id(request)

    if not store["settings"].get("votingOpen", True):
        return JSONResponse({"error": "Voting is currently paused"}, status_code=403)

    if not option_id or not isinstance(option_id, str):
        return JSONResponse({"error": "Missing or invalid optionId"}, status_code=400)

    option = next((o for o in store["options"] if o["id"] == option_id), None)
    if not option:
        return JSONResponse({"error": "Option not found"}, status_code=404)

    existing_vote = store["votes"].get(voter_id)
    if existing_vote and not store["settings"].get("allowVoteChanges", True) and existing_vote != option_id:
        return JSONResponse({"error": "Changing votes is disabled by administrator"}, status_code=403)

    is_change = bool(existing_vote and existing_vote != option_id)
    store["votes"][voter_id] = option_id

    activity_item = {
        "id": str(uuid.uuid4()),
        "title": option["title"],
        "icon": option.get("icon", "star"),
        "color": option.get("color", "blue"),
        "isChange": is_change,
        "timestamp": int(time.time() * 1000),
    }
    store.setdefault("history", []).append(activity_item)
    if len(store["history"]) > 30:
        store["history"] = store["history"][-30:]

    save_store()
    broadcast_state()

    updated_state = get_public_stats(voter_id)
    return {
        "success": True,
        "userVote": option_id,
        "myVote": option_id,
        "state": updated_state,
        "stats": updated_state,
    }


@app.get("/api/qr")
async def api_qr(request: Request, url: Optional[str] = None, format: str = "png"):
    host = request.headers.get("x-forwarded-host") or request.headers.get("host", "localhost:8080")
    proto = "https" if (request.url.scheme == "https" or request.headers.get("x-forwarded-proto") == "https" or "run.app" in host) else "http"
    vote_url = url or f"{proto}://{host}/vote"

    qr = qrcode.QRCode(
        version=None,
        error_correction=qrcode.constants.ERROR_CORRECT_M,
        box_size=10,
        border=2,
    )
    qr.add_data(vote_url)
    qr.make(fit=True)

    img = qr.make_image(fill_color="#001a41", back_color="#ffffff")
    buf = io.BytesIO()
    img.save(buf, format="PNG")
    png_bytes = buf.getvalue()

    if format == "png":
        return Response(
            content=png_bytes,
            media_type="image/png",
            headers={"Cache-Control": "no-cache"},
        )
    else:
        b64 = base64.b64encode(png_bytes).decode("utf-8")
        return {
            "dataUrl": f"data:image/png;base64,{b64}",
            "url": vote_url,
        }


# --- ADMIN ROUTES ---

@app.put("/api/admin/settings", response_class=JSONResponse)
@app.post("/api/admin/settings", response_class=JSONResponse)
async def admin_update_settings(request: Request):
    body = await request.json()
    if body.get("eventName"):
        store["settings"]["eventName"] = str(body["eventName"]).strip()[:100]
    if body.get("question"):
        store["settings"]["question"] = str(body["question"]).strip()[:180]
    if isinstance(body.get("votingOpen"), bool):
        store["settings"]["votingOpen"] = body["votingOpen"]
    if isinstance(body.get("allowVoteChanges"), bool):
        store["settings"]["allowVoteChanges"] = body["allowVoteChanges"]
    if isinstance(body.get("showLiveResultsToAudience"), bool):
        store["settings"]["showLiveResultsToAudience"] = body["showLiveResultsToAudience"]

    save_store()
    broadcast_state()
    return {"success": True, "settings": store["settings"], "state": get_public_stats()}


@app.post("/api/admin/reset-votes", response_class=JSONResponse)
async def admin_reset_votes(request: Request):
    store["votes"] = {}
    store["history"] = []
    save_store()
    broadcast_state()
    return {"success": True, "message": "All votes have been reset", "state": get_public_stats()}


@app.post("/api/admin/simulate", response_class=JSONResponse)
async def admin_simulate_votes(request: Request):
    try:
        body = await request.json()
    except Exception:
        body = {}

    count = min(max(int(body.get("count", 5)), 1), 100)
    for i in range(count):
        random_voter_id = "sim_" + secrets.token_hex(8)
        random_opt = random.choice(store["options"])
        store["votes"][random_voter_id] = random_opt["id"]
        store.setdefault("history", []).append(
            {
                "id": str(uuid.uuid4()),
                "title": random_opt["title"],
                "icon": random_opt.get("icon", "star"),
                "color": random_opt.get("color", "blue"),
                "isChange": False,
                "timestamp": int(time.time() * 1000) - (count - i) * 1500,
            }
        )

    if len(store["history"]) > 30:
        store["history"] = store["history"][-30:]

    save_store()
    broadcast_state()
    return {"success": True, "count": count, "totalVotes": len(store["votes"]), "state": get_public_stats()}


@app.get("/api/admin/export")
async def admin_export_csv(request: Request):
    stats = get_public_stats()
    lines = ["Option ID,Title,Votes,Percentage"]
    for opt in stats["options"]:
        safe_title = opt["title"].replace('"', '""')
        lines.append(f'"{opt["id"]}","{safe_title}",{opt["count"]},{opt["percentage"]}%')
    lines.append("")
    lines.append(f'Total Votes,{stats["totalVotes"]}')
    lines.append(f"Exported At,{datetime.now(timezone.utc).isoformat()}")
    csv_content = "\n".join(lines) + "\n"

    return Response(
        content=csv_content,
        media_type="text/csv",
        headers={
            "Content-Disposition": f'attachment; filename="auratech-role-poll-{int(time.time())}.csv"'
        },
    )


# Auto-mount Fitbit Campaign router when created by Antigravity (AT-2026)
try:
    from campaign_router import router as campaign_router

    app.include_router(campaign_router)
except ImportError:
    pass

