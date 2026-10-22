import * as p from '@clack/prompts';
import pc from 'picocolors';
import { CliError, EXIT_USAGE, EXIT_CANCELLED } from './errors.js';

export function isInteractive(): boolean {
  return Boolean(process.stdout.isTTY && process.stdin.isTTY);
}

export async function safePrompt<T>(promptFn: () => Promise<T | symbol> | T | symbol): Promise<T> {
  if (!isInteractive()) {
    throw new CliError('Interactive prompt requested in non-interactive environment. Please provide all required options via command line flags.', EXIT_USAGE);
  }

  const result = await promptFn();
  if (p.isCancel(result)) {
    p.cancel('Operation cancelled.');
    process.exit(EXIT_CANCELLED);
  }

  return result as T;
}

export { pc, p };
