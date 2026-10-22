#!/usr/bin/env node

import { Command } from 'commander';
import { CliError, EXIT_USAGE, handleFatalError } from './cli/errors.js';
import { safePrompt, isInteractive, pc, p } from './cli/ui.js';
import { startMcpServer, generateHostConfig } from './mcp/server.js';

process.on('SIGINT', () => {
  process.stderr.write('\nOperation aborted by user.\n');
  process.exit(130);
});

process.on('SIGTERM', () => {
  process.stderr.write('\nProcess terminated.\n');
  process.exit(143);
});

export function createProgram(): Command {
  const program = new Command();

  program
    .name('no-spoilers-sherlock')
    .description('no-spoilers-sherlock dual-mode CLI and Model Context Protocol (MCP) server')
    .version('0.1.0')
    .exitOverride((err) => {
      if (err.code === 'commander.helpDisplayed' || err.code === 'commander.version') {
        throw err;
      }
      if (
        err.code === 'commander.unknownOption' ||
        err.code === 'commander.missingArgument' ||
        err.code === 'commander.unknownCommand' ||
        err.code === 'commander.invalidArgument'
      ) {
        throw new CliError(err.message, EXIT_USAGE);
      }
      throw err;
    });

  program
    .command('greet')
    .description('Greet a user interactively or by name')
    .option('-n, --name <name>', 'Name of the person to greet')
    .action(async (options: { name?: string }) => {
      let name = options.name;
      if (!name) {
        if (isInteractive()) {
          p.intro(pc.cyan('no-spoilers-sherlock'));
          name = await safePrompt(() =>
            p.text({
              message: 'What is your name?',
              placeholder: 'Developer',
              defaultValue: 'Developer',
            })
          );
          p.outro(pc.green(`Hello, ${name}!`));
        } else {
          name = 'World';
          console.log(`Hello, ${name}!`);
        }
      } else {
        console.log(`Hello, ${name}!`);
      }
    });

  program
    .command('mcp')
    .alias('serve')
    .description('Run as a headless Model Context Protocol (MCP) server over stdio')
    .option('--print-config', 'Print host configuration JSON snippets and exit')
    .action(async (options: { printConfig?: boolean }) => {
      if (options.printConfig) {
        const config = generateHostConfig('no-spoilers-sherlock', process.argv[1] || 'dist/index.js');
        console.log(JSON.stringify(config, null, 2));
        return;
      }

      await startMcpServer();
    });

  return program;
}

export const program = createProgram();

const isDirectExecution = process.argv[1] && (
  process.argv[1].endsWith('index.ts') ||
  process.argv[1].endsWith('index.js') ||
  process.argv[1].endsWith('no-spoilers-sherlock')
);

if (isDirectExecution) {
  try {
    await program.parseAsync(process.argv);
  } catch (error) {
    handleFatalError(error);
  }
}
