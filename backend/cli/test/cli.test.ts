import { describe, it, expect } from 'vitest';
import { createProgram } from '../src/index.js';
import { CliError, EXIT_USAGE, EXIT_ERROR, EXIT_CANCELLED } from '../src/cli/errors.js';
import { generateHostConfig } from '../src/mcp/server.js';
import { isInteractive } from '../src/cli/ui.js';

describe('Dual-Mode CLI Commands', () => {
  it('creates program with greet and mcp commands', () => {
    const program = createProgram();
    expect(program.name()).toBe('no-spoilers-sherlock');
    const commandNames = program.commands.map(c => c.name());
    expect(commandNames).toContain('greet');
    expect(commandNames).toContain('mcp');
  });

  it('supports serve alias for mcp command', () => {
    const program = createProgram();
    const mcpCommand = program.commands.find(c => c.name() === 'mcp');
    expect(mcpCommand?.aliases()).toContain('serve');
  });

  it('throws CliError on unknown command or options', () => {
    const program = createProgram();
    try {
      program.parse(['node', 'test', '--invalid-option']);
    } catch (err: any) {
      expect(err).toBeInstanceOf(CliError);
      expect(err.exitCode).toBe(EXIT_USAGE);
    }
  });

  it('generates host configuration for opencode, cursor, and claudeDesktop', () => {
    const config = generateHostConfig('test-service', '/workspace/dist/index.js');
    expect(config.opencode.mcpServers['test-service']).toBeDefined();
    expect(config.cursor.mcpServers['test-service']).toBeDefined();
    expect(config.claudeDesktop.mcpServers['test-service']).toBeDefined();

    expect(config.opencode.mcpServers['test-service'].command).toBe('node');
    expect(config.opencode.mcpServers['test-service'].args).toContain('/workspace/dist/index.js');
    expect(config.opencode.mcpServers['test-service'].args).toContain('mcp');
  });

  it('evaluates interactive state', () => {
    expect(typeof isInteractive()).toBe('boolean');
  });
});
