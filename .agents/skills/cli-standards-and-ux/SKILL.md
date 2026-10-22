---
name: CLI Standards and Terminal UX
description: Authoritative standards for TypeScript CLI architecture: Commander 13 command routing, Clack prompts, TTY degradation, POSIX exit codes, and signal handling.
---

# CLI Standards and Terminal UX

This document defines the engineering standards and best practices for building robust, user-friendly TypeScript command-line interfaces.

## 1. Command Routing with Commander 13

- Use `commander` (^13.x) for declarative argument and option parsing.
- Always configure `program.exitOverride()` so parsing errors can be caught and handled rather than calling `process.exit` abruptly:
  ```ts
  import { Command } from 'commander';

  export const program = new Command();
  program
    .name('my-cli')
    .description('Command-line tool description')
    .version('0.1.0')
    .exitOverride((err) => {
      if (
        err.code === 'commander.unknownOption' ||
        err.code === 'commander.missingArgument' ||
        err.code === 'commander.unknownCommand' ||
        err.code === 'commander.invalidArgument'
      ) {
        throw new CliError(err.message, 2);
      }
      throw err;
    });
  ```
- Subcommands should be modularized in dedicated modules under `src/commands/` or `src/cli/`.

## 2. Interactive Prompts & Terminal Aesthetics

- Use `@clack/prompts` (^0.10.x) for terminal UX (spinners, text prompts, selections, confirms).
- Always check for user cancellation using `p.isCancel()` on every prompt return value:
  ```ts
  import * as p from '@clack/prompts';

  const value = await p.text({ message: 'Enter project name:' });
  if (p.isCancel(value)) {
    p.cancel('Operation cancelled.');
    process.exit(130);
  }
  ```
- Use `picocolors` (^1.x) for ANSI terminal styling. `picocolors` automatically respects `NO_COLOR` and terminal TTY capabilities.

## 3. TTY Awareness & Pipeline Degradation

- Terminal tools must operate cleanly in Unix pipes (`my-cli status | jq`) and CI/CD pipelines.
- Check terminal interactive capability:
  ```ts
  export function isInteractive(): boolean {
    return Boolean(process.stdout.isTTY && process.stdin.isTTY);
  }
  ```
- When `!process.stdout.isTTY`:
  - Suppress animated loaders and spinners.
  - Omit ANSI color escape codes.
  - Do not prompt for interactive input. If a required argument is not supplied via flags, write a clear error to `process.stderr` and exit with code `2`.
  - Emit clean, machine-readable output (such as JSON or plain text) to `process.stdout`.

## 4. Canonical POSIX Exit Codes

CLI applications must follow standard Unix exit codes:
- **`0`**: Successful execution.
- **`1`**: Unhandled runtime exception or general operational failure.
- **`2`**: Invalid command usage, unknown flag, missing required argument, or interactive prompt in non-TTY mode.
- **`130`**: Interrupted by user cancellation (`SIGINT`, Ctrl+C, prompt abort).
- **`143`**: Terminated by operating system signal (`SIGTERM`).

Encapsulate errors with a dedicated `CliError` class:
```ts
export class CliError extends Error {
  constructor(
    message: string,
    public readonly exitCode: number = 1
  ) {
    super(message);
    this.name = 'CliError';
  }
}
```

## 5. Signal Handling

Attach top-level signal handlers to cleanly terminate running tasks:
```ts
process.on('SIGINT', () => {
  process.stderr.write('\nOperation aborted by user.\n');
  process.exit(130);
});

process.on('SIGTERM', () => {
  process.stderr.write('\nProcess terminated.\n');
  process.exit(143);
});
```
