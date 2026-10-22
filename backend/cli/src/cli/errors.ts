export const EXIT_SUCCESS = 0;
export const EXIT_ERROR = 1;
export const EXIT_USAGE = 2;
export const EXIT_CANCELLED = 130;
export const EXIT_TERMINATED = 143;

export class CliError extends Error {
  constructor(
    message: string,
    public readonly exitCode: number = EXIT_ERROR
  ) {
    super(message);
    this.name = 'CliError';
  }
}

export function handleFatalError(error: unknown): never {
  if (error && typeof error === 'object' && 'code' in error) {
    const err = error as { code: string; exitCode?: number };
    if (err.code === 'commander.helpDisplayed' || err.code === 'commander.version') {
      process.exit(err.exitCode ?? 0);
    }
  }

  if (error instanceof CliError) {
    process.stderr.write(`Error: ${error.message}\n`);
    process.exit(error.exitCode);
  }

  const message = error instanceof Error ? (error.stack || error.message) : String(error);
  process.stderr.write(`Unexpected error: ${message}\n`);
  process.exit(EXIT_ERROR);
}
