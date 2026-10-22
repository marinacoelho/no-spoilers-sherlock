import { describe, it } from 'node:test';
import assert from 'node:assert';
import { greeting } from '../src/index.js';

describe('App Tests', () => {
  it('returns valid greeting', () => {
    assert.ok(greeting().includes('Hello'));
  });
});
