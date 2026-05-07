# Anuj MCP Server (Order Status)

This is an MCP server intended for deployment (for example on AWS App Runner) using **Streamable HTTP**.

## Tool

- **`check_order_status`**
  - **Input**: `orderid` (string)
  - **Behavior**: Calls the MockAPI endpoint:
    - `https://69ee77ae9163f839f892c3d6.mockapi.io/api/cars?orderid=ID`

## Run locally

```bash
npm install
npm run build
npm start
```

Server listens on `PORT` (default `3000`).

## Endpoints

- `POST /mcp` (MCP Streamable HTTP)
- `GET /health` (simple health check)

