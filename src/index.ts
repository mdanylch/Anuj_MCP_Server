import { createMcpExpressApp } from '@modelcontextprotocol/express';
import { NodeStreamableHTTPServerTransport } from '@modelcontextprotocol/node';
import { McpServer } from '@modelcontextprotocol/server';
import type { Request, Response } from 'express';
import * as z from 'zod/v4';

const ORDER_ID_REGEX = /^[A-Za-z0-9_-]{1,64}$/;

function getServer() {
  const server = new McpServer(
    { name: 'anuj-order-status-mcp', version: '1.0.0' },
    { capabilities: { tools: {}, logging: {} } }
  );

  server.registerTool(
    'check_order_status',
    {
      title: 'Check order status',
      description:
        'Fetch order status from the MockAPI endpoint by order id. Provide the order id only (no URL).',
      inputSchema: z.object({
        orderid: z
          .string()
          .min(1)
          .max(64)
          .describe('Order ID to look up (letters, numbers, underscore, hyphen).')
      })
    },
    async ({ orderid }) => {
      if (!ORDER_ID_REGEX.test(orderid)) {
        return {
          content: [
            {
              type: 'text',
              text: JSON.stringify({
                ok: false,
                error: 'Invalid orderid format. Use only letters, numbers, underscore, hyphen.'
              })
            }
          ],
          structuredContent: {
            ok: false,
            error: 'Invalid orderid format. Use only letters, numbers, underscore, hyphen.'
          }
        };
      }

      const url = `https://69ee77ae9163f839f892c3d6.mockapi.io/api/cars?orderid=${encodeURIComponent(
        orderid
      )}`;

      try {
        const resp = await fetch(url, {
          method: 'GET',
          headers: { accept: 'application/json' }
        });

        const bodyText = await resp.text();
        let json: unknown = bodyText;
        try {
          json = bodyText ? JSON.parse(bodyText) : null;
        } catch {
          // leave as text
        }

        if (!resp.ok) {
          const output = {
            ok: false,
            status: resp.status,
            statusText: resp.statusText,
            url,
            response: json
          };
          return {
            content: [{ type: 'text', text: JSON.stringify(output) }],
            structuredContent: output
          };
        }

        const output = { ok: true, url, data: json };
        return {
          content: [{ type: 'text', text: JSON.stringify(output) }],
          structuredContent: output
        };
      } catch (err) {
        const output = {
          ok: false,
          url,
          error: err instanceof Error ? err.message : 'Unknown error'
        };
        return {
          content: [{ type: 'text', text: JSON.stringify(output) }],
          structuredContent: output
        };
      }
    }
  );

  return server;
}

// Bind publicly for App Runner. Don't restrict Host header here because
// App Runner will use a service URL hostname (not localhost).
const app = createMcpExpressApp({ host: '0.0.0.0' });

app.post('/mcp', async (req: Request, res: Response) => {
  const server = getServer();
  try {
    const transport = new NodeStreamableHTTPServerTransport({
      sessionIdGenerator: undefined
    });
    await server.connect(transport);

    await transport.handleRequest(req, res, req.body);

    res.on('close', () => {
      transport.close();
      server.close();
    });
  } catch (error) {
    // eslint-disable-next-line no-console
    console.error('Error handling MCP request:', error);
    if (!res.headersSent) {
      res.status(500).json({
        jsonrpc: '2.0',
        error: { code: -32603, message: 'Internal server error' },
        id: null
      });
    }
  }
});

app.get('/health', (_req: Request, res: Response) => {
  res.status(200).json({ ok: true });
});

const PORT = Number(process.env.PORT ?? '3000');
app.listen(PORT, error => {
  if (error) {
    // eslint-disable-next-line no-console
    console.error('Failed to start server:', error);
    // eslint-disable-next-line unicorn/no-process-exit
    process.exit(1);
  }
  // eslint-disable-next-line no-console
  console.log(`MCP server listening on port ${PORT}`);
});

