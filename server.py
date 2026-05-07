"""
Anuj Order Details MCP — FastMCP over HTTP (Uvicorn / AWS App Runner).

Endpoints
---------
- ``GET /`` and ``GET /health`` — return ``ok`` (health checks).
- ``/mcp`` — MCP streamable HTTP. Clients use ``https://<host>/mcp``.

Optional auth (env ``MCP_REQUEST_HEADERS``)
-------------------------------------------
Same behavior as store_address_2000: if set, require matching headers except on ``/`` and ``/health``.

Run locally: ``uvicorn server:app --host 0.0.0.0 --port 8080`` — MCP URL ``http://localhost:8080/mcp``.
"""

from __future__ import annotations

import asyncio
import json
import logging
import os
import re
from urllib.parse import urlencode
from urllib.request import urlopen

from fastmcp import server
from starlette.applications import Starlette
from starlette.middleware import Middleware
from starlette.middleware.base import BaseHTTPMiddleware
from starlette.requests import Request
from starlette.responses import PlainTextResponse
from starlette.routing import Mount, Route

logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)

# MockAPI cars resource; query: ?orderid=<id>
CARS_ORDER_API = "https://69ee77ae9163f839f892c3d6.mockapi.io/api/cars"

# Allow-list order ids for safe query strings (MockAPI uses numeric ids like 41).
_ORDER_ID_RE = re.compile(r"^[0-9]{1,32}$")


def _load_custom_header_rules() -> dict[str, str] | None:
    """Return required header name -> value from env, or None if auth is disabled."""
    raw = os.environ.get("MCP_REQUEST_HEADERS", "").strip()
    if not raw:
        return None
    if raw.startswith("{"):
        try:
            data = json.loads(raw)
        except json.JSONDecodeError as e:
            raise ValueError(f"MCP_REQUEST_HEADERS JSON is invalid: {e}") from e
        if not isinstance(data, dict):
            raise ValueError("MCP_REQUEST_HEADERS JSON must be an object")
        out = {str(k).strip(): str(v).strip() for k, v in data.items()}
        return out if out else None
    return {"MCP_REQUEST_HEADERS": raw}


class CustomHeaderAuthMiddleware(BaseHTTPMiddleware):
    """If rules are set, require matching headers on all routes except GET / and GET /health."""

    def __init__(self, app, required: dict[str, str] | None):
        super().__init__(app)
        self.required = required

    async def dispatch(self, request: Request, call_next):
        if self.required is None:
            return await call_next(request)

        path = request.url.path
        if request.method == "OPTIONS":
            return await call_next(request)
        if request.method == "GET" and path in ("/", "/health"):
            return await call_next(request)

        for name, expected in self.required.items():
            if request.headers.get(name) != expected:
                logger.warning("auth failed: %s %s", request.method, path)
                return PlainTextResponse("Unauthorized", status_code=401)

        return await call_next(request)


_HEADER_RULES = _load_custom_header_rules()

mcp = server.FastMCP("Anuj Order Details MCP")

# Explicit object output schema so MCP clients show the same pattern as store_address_2000
# (open object: success, order/orders, error, etc.).
_ORDER_TOOL_OUTPUT_SCHEMA: dict = {"type": "object", "additionalProperties": True}


def _fetch_order_json(order_id: str) -> object:
    """Synchronous GET to MockAPI; used from async via asyncio.to_thread."""
    url = f"{CARS_ORDER_API}?{urlencode({'orderid': order_id})}"
    with urlopen(url, timeout=30) as resp:
        return json.loads(resp.read().decode())


@mcp.tool(output_schema=_ORDER_TOOL_OUTPUT_SCHEMA)
async def check_order_status(order_id: str) -> dict:
    """
    Look up an order by id and return full order details from the cars API.

    Calls ``https://69ee77ae9163f839f892c3d6.mockapi.io/api/cars?orderid=<id>``
    and returns the complete record(s) (model, color, engine, customer, orderid, etc.).
    """
    oid = order_id.strip()
    if not _ORDER_ID_RE.fullmatch(oid):
        return {
            "success": False,
            "error": "order_id must be digits only (e.g. 41).",
        }
    try:
        payload = await asyncio.to_thread(_fetch_order_json, oid)
    except Exception as e:
        logger.warning("check_order_status: request failed order_id=%s err=%s", oid, e)
        return {"success": False, "error": "Could not reach order service.", "order_id": oid}

    if not isinstance(payload, list) or len(payload) == 0:
        return {
            "success": False,
            "error": "No order found for this id.",
            "order_id": oid,
        }

    if len(payload) == 1:
        row = payload[0]
        if not isinstance(row, dict):
            return {"success": False, "error": "Unexpected response shape.", "order_id": oid}
        return {"success": True, "order": row}

    rows = [r for r in payload if isinstance(r, dict)]
    if not rows:
        return {"success": False, "error": "Unexpected response shape.", "order_id": oid}
    return {"success": True, "orders": rows}


_mcp_asgi = mcp.http_app(path="/mcp")


async def _health(_):
    return PlainTextResponse("ok")


app = Starlette(
    routes=[
        Route("/", _health),
        Route("/health", _health),
        Mount("/", _mcp_asgi),
    ],
    middleware=[Middleware(CustomHeaderAuthMiddleware, required=_HEADER_RULES)],
    lifespan=_mcp_asgi.router.lifespan_context,
)
