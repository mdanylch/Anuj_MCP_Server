# Anuj MCP Server (order details)

Python **FastMCP** server matching the pattern used in [store_address_2000](https://github.com/mdanylch/store_address_2000): `pip install -t deps` at build, **Uvicorn** at run, optional `MCP_REQUEST_HEADERS` auth.

Use **FastMCP 3.x** (`fastmcp>=3.0` in `requirements.txt`) so the tool **input schema** matches the working server: required `order_id` (string), `additionalProperties: false`, and an **object** output schema. If your client still shows `orderid` or **Output N/A**, the client is likely hitting an **old deployment** (Node) or a **cached** tool list — redeploy from latest `main` and refresh the MCP connection.

## Tool

- **`check_order_status`** — Fetches **full order details** from MockAPI:  
  `https://69ee77ae9163f839f892c3d6.mockapi.io/api/cars?orderid=<id>`  
  Input: `order_id` (digits only, e.g. `41`).  
  Success: `{"success": true, "order": { ... }}` with all fields from the API. If multiple rows match, `orders` is a list.

## Endpoints

- `GET /`, `GET /health` — `ok`
- `POST` (and MCP traffic) on `/mcp`

## Local run

```bash
pip install -r requirements.txt
uvicorn server:app --host 0.0.0.0 --port 8080
```

## AWS App Runner (same as store_address_2000)

- **Runtime:** Python 3.11  
- **Build:** `sh start.sh`  
- **Start:** `sh run.sh`  
- **Port:** `8080`
