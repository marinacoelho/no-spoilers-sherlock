---
name: MCP Server Architecture & Stdio Purity
description: Authoritative standards for Model Context Protocol SDK architecture, absolute stdio stream isolation, Zod schemas, path jailing, stdin EOF teardown, and host discovery.
---

# MCP Server Architecture & Stdio Purity

This document defines the architectural patterns and guardrails for Model Context Protocol (MCP) servers and dual-mode CLI/MCP applications.

## 1. Absolute Stdio Protocol Purity

In stdio-based MCP servers (`StdioServerTransport`), `process.stdout` is strictly reserved for valid JSON-RPC 2.0 messages exchanged between the server and the host agent:
- **Zero non-protocol bytes on stdout**: Any extraneous byte (such as `console.log`, banners, or ANSI escape codes) corrupts host framing and crashes the session.
- **Diagnostic channels on stderr**: All logging, tracing, status messages, and debug outputs must write exclusively to `process.stderr`.
- **Console method redirection**: In MCP server execution mode, patch global console methods (`console.log`, `info`, `warn`, `dir`, `debug`, `table`, `trace`) using `node:util` `format` to redirect to `process.stderr`:

```ts
import util from 'node:util';

export function enforceStdioPurity(): () => void {
  const original = {
    log: console.log,
    info: console.info,
    warn: console.warn,
    dir: console.dir,
    debug: console.debug,
    table: console.table,
    trace: console.trace,
  };

  const redirect = (...args: unknown[]) => {
    process.stderr.write(util.format(...args) + '\n');
  };

  console.log = redirect;
  console.info = redirect;
  console.warn = redirect;
  console.dir = redirect;
  console.debug = redirect;
  console.table = redirect;
  console.trace = redirect;

  return () => {
    console.log = original.log;
    console.info = original.info;
    console.warn = original.warn;
    console.dir = original.dir;
    console.debug = original.debug;
    console.table = original.table;
    console.trace = original.trace;
  };
}
```

## 2. Stdin Lifecycle & Teardown Guardrails

When an AI developer host (OpenCode, Cursor, Claude Desktop) terminates or reloads, the stdin pipe closes. Servers that do not listen to stdin EOF events become lingering orphan / zombie processes consuming CPU and memory.

Always attach lifecycle listeners:
```ts
export function setupStdinLifecycle(): void {
  process.stdin.on('close', () => {
    process.exit(0);
  });
  process.stdin.on('end', () => {
    process.exit(0);
  });
}
```

## 3. Path Jailing & Security Boundaries

Any MCP tool that reads, writes, or checks filesystem paths must prevent directory traversal attacks (such as `../../etc/passwd`):
```ts
import path from 'node:path';

export function resolveSafePath(baseDir: string, userPath: string): string {
  const resolvedBase = path.resolve(baseDir);
  const resolvedTarget = path.resolve(resolvedBase, userPath);
  const rel = path.relative(resolvedBase, resolvedTarget);

  if (rel.startsWith('..') || path.isAbsolute(rel)) {
    throw new Error(`Security violation: Path "${userPath}" escapes allowed workspace "${baseDir}"`);
  }

  return resolvedTarget;
}
```

## 4. Strongly-Typed Tools with Zod Schemas

Define MCP tools using `@modelcontextprotocol/sdk` and `zod`:
- Annotate every property with `.describe('...')` so agent models understand parameter semantics.
- Return structured error content conforming to the MCP protocol rather than letting unhandled rejections crash the server:

```ts
import { McpServer } from '@modelcontextprotocol/sdk/server/mcp.js';
import { z } from 'zod';

export function registerTools(server: McpServer) {
  server.tool(
    'echo',
    'Echoes back a string payload',
    {
      message: z.string().describe('Message string to echo'),
    },
    async ({ message }) => {
      return {
        content: [{ type: 'text', text: `Echo: ${message}` }],
      };
    }
  );
}
```

## 5. Zero-Touch Host Configuration Discovery (`--print-config`)

Support the `--print-config` command option to generate valid configuration blocks for OpenCode, Cursor, and Claude Desktop:
```ts
export function generateHostConfig(serverName: string, executablePath: string) {
  const absPath = path.resolve(executablePath);
  const isJs = absPath.endsWith('.js') || absPath.endsWith('.mjs');
  const command = isJs ? 'node' : absPath;
  const args = isJs ? [absPath, 'mcp'] : ['mcp'];

  return {
    opencode: {
      mcpServers: {
        [serverName]: { command, args },
      },
    },
    cursor: {
      mcpServers: {
        [serverName]: { command, args },
      },
    },
    claudeDesktop: {
      mcpServers: {
        [serverName]: { command, args },
      },
    },
  };
}
```

## 6. Verification with MCP Inspector

Test MCP servers interactively using the official `@modelcontextprotocol/inspector`:
```bash
npx @modelcontextprotocol/inspector tsx src/index.ts mcp
```
The inspector launches a web interface to inspect registered tools, test schema validation, and trace protocol payloads in real time.
