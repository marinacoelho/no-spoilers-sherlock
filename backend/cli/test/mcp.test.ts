import { describe, it, expect, vi } from 'vitest';
import path from 'node:path';
import {
  resolveSafePath,
  enforceStdioPurity,
  createMcpServer,
  setupStdinLifecycle,
  logger,
} from '../src/mcp/server.js';

describe('MCP Server Implementation & Guardrails', () => {
  describe('Path Jailing (resolveSafePath)', () => {
    const baseDir = '/safe/base/path';

    it('resolves valid relative paths inside the base directory, including dotfiles', () => {
      const resolved = resolveSafePath(baseDir, 'data/file.txt');
      expect(resolved).toBe(path.resolve(baseDir, 'data/file.txt'));

      const dotfile = resolveSafePath(baseDir, '.env');
      expect(dotfile).toBe(path.resolve(baseDir, '.env'));

      const dotDotPrefixFile = resolveSafePath(baseDir, '..secret.txt');
      expect(dotDotPrefixFile).toBe(path.resolve(baseDir, '..secret.txt'));
    });

    it('throws security error when attempting traversal outside base directory', () => {
      expect(() => {
        resolveSafePath(baseDir, '../outside.txt');
      }).toThrowError(/outside allowed directory/);

      expect(() => {
        resolveSafePath(baseDir, '../../etc/passwd');
      }).toThrowError(/outside allowed directory/);
    });
  });

  describe('Stdio Protocol Purity & Console Redirection', () => {
    it('redirects console methods to process.stderr and restores on teardown', () => {
      const stderrSpy = vi.spyOn(process.stderr, 'write').mockImplementation(() => true);
      const stdoutSpy = vi.spyOn(process.stdout, 'write').mockImplementation(() => true);

      const restore = enforceStdioPurity();

      console.log('test log message');
      console.info('test info message');
      console.warn('test warn message');
      console.error('test error message');

      // stdout must have zero writes
      expect(stdoutSpy).not.toHaveBeenCalled();

      // stderr must have intercepted the calls
      expect(stderrSpy).toHaveBeenCalled();
      const output = stderrSpy.mock.calls.map(c => String(c[0])).join('');
      expect(output).toContain('test log message');
      expect(output).toContain('test info message');
      expect(output).toContain('test warn message');

      restore();
      stderrSpy.mockRestore();
      stdoutSpy.mockRestore();
    });

    it('writes diagnostic logger calls exclusively to stderr', () => {
      const stderrSpy = vi.spyOn(process.stderr, 'write').mockImplementation(() => true);
      const stdoutSpy = vi.spyOn(process.stdout, 'write').mockImplementation(() => true);

      logger.info('diagnostic message: %s', 'ready');
      expect(stdoutSpy).not.toHaveBeenCalled();
      expect(stderrSpy).toHaveBeenCalled();

      const output = stderrSpy.mock.calls.map(c => String(c[0])).join('');
      expect(output).toContain('[INFO] diagnostic message: ready');

      stderrSpy.mockRestore();
      stdoutSpy.mockRestore();
    });
  });

  describe('Server Tools Initialization', () => {
    it('initializes McpServer with registered tools', () => {
      const server = createMcpServer();
      expect(server).toBeDefined();
    });
  });

  describe('Stdin Lifecycle Guardrails', () => {
    it('registers close, end, and error listeners on process.stdin', () => {
      const stdinOnSpy = vi.spyOn(process.stdin, 'on');
      setupStdinLifecycle();

      const registeredEvents = stdinOnSpy.mock.calls.map(c => c[0]);
      expect(registeredEvents).toContain('close');
      expect(registeredEvents).toContain('end');
      expect(registeredEvents).toContain('error');

      stdinOnSpy.mockRestore();
    });
  });
});
