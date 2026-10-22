import util from 'node:util';
import path from 'node:path';
import { McpServer } from '@modelcontextprotocol/sdk/server/mcp.js';
import { StdioServerTransport } from '@modelcontextprotocol/sdk/server/stdio.js';
import { z } from 'zod';

/**
 * Diagnostic logger writing exclusively to process.stderr to preserve stdout for JSON-RPC framing.
 */
export const logger = {
  info: (format: string, ...args: unknown[]) => {
    process.stderr.write(`[INFO] ${util.format(format, ...args)}\n`);
  },
  warn: (format: string, ...args: unknown[]) => {
    process.stderr.write(`[WARN] ${util.format(format, ...args)}\n`);
  },
  error: (format: string, ...args: unknown[]) => {
    process.stderr.write(`[ERROR] ${util.format(format, ...args)}\n`);
  },
  debug: (format: string, ...args: unknown[]) => {
    if (process.env.DEBUG) {
      process.stderr.write(`[DEBUG] ${util.format(format, ...args)}\n`);
    }
  },
};

/**
 * Guards console methods to redirect any unintentional stdout writes to process.stderr.
 * Returns a teardown function that restores the original methods.
 */
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

/**
 * Sets up stdin close/end listeners to immediately terminate with exit code 0
 * when the parent agent host closes its stream or terminates.
 */
export function setupStdinLifecycle(): void {
  process.stdin.on('close', () => {
    process.exit(0);
  });
  process.stdin.on('end', () => {
    process.exit(0);
  });
  process.stdin.on('error', () => {
    process.exit(0);
  });
}

/**
 * Path jailing helper: guarantees that user-provided relative paths
 * resolve strictly inside baseDir, preventing directory traversal attacks.
 */
export function resolveSafePath(baseDir: string, userPath: string): string {
  const resolvedBase = path.resolve(baseDir);
  const resolvedTarget = path.resolve(resolvedBase, userPath);
  const rel = path.relative(resolvedBase, resolvedTarget);

  if (rel === '..' || rel.startsWith('..' + path.sep) || path.isAbsolute(rel)) {
    throw new Error(`Path traversal violation: "${userPath}" is outside allowed directory "${baseDir}"`);
  }

  return resolvedTarget;
}

/**
 * Builds host configuration snippets for OpenCode, Cursor, and Claude Desktop.
 */
export function generateHostConfig(serverName: string, executablePath: string) {
  const absPath = path.resolve(executablePath);
  const isJs = absPath.endsWith('.js') || absPath.endsWith('.mjs') || absPath.endsWith('.ts');
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

/**
 * Creates and registers tools on the McpServer instance.
 */
export function createMcpServer(): McpServer {
  const server = new McpServer({
    name: 'no-spoilers-sherlock',
    version: '0.1.0',
  });

  server.tool(
    'echo',
    'Echoes back a string payload to verify connection',
    {
      message: z.string().describe('Message string to echo back'),
    },
    async ({ message }) => {
      return {
        content: [{ type: 'text', text: `Echo: ${message}` }],
      };
    }
  );

  server.tool(
    'system_info',
    'Returns runtime system platform and Node architecture',
    {},
    async () => {
      return {
        content: [
          {
            type: 'text',
            text: JSON.stringify({
              platform: process.platform,
              arch: process.arch,
              nodeVersion: process.version,
            }, null, 2),
          },
        ],
      };
    }
  );

  return server;
}

/**
 * Launches the MCP server over stdio with full stream isolation.
 */
export async function startMcpServer(): Promise<void> {
  enforceStdioPurity();
  setupStdinLifecycle();

  logger.info('Starting no-spoilers-sherlock MCP server over stdio');

  const server = createMcpServer();
  const transport = new StdioServerTransport();
  await server.connect(transport);
}
