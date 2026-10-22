---
id: web-playwright-e2e
name: Playwright End-to-End Testing & Automation
author: Microsoft Playwright / FleetKit
platform: web
repository: microsoft/playwright
default: true
description: Playwright testing, resilient locators (getByRole), network intercepting.
---

# Playwright End-to-End Testing & Automation

Guidelines for resilient, deterministic end-to-end integration tests using Playwright.

## Key Principles

1. **User-Centric Locators**: Always locate elements using user-facing semantics via `page.getByRole()`, `page.getByLabel()`, or `page.getByText()`. Avoid brittle XPath or CSS selector paths (`div > span:nth-child(2)`).
2. **Auto-Waiting Assertions**: Use web-first assertions like `await expect(locator).toBeVisible()` or `await expect(locator).toHaveText()` which automatically retry until timeouts, eliminating flaky manual `waitForTimeout` sleeps.
3. **Network Mocking & Route Interception**: Intercept backend network calls using `page.route()` to simulate fast, deterministic responses, server errors, and offline modes without hitting production APIs.
4. **Isolated Browser Contexts**: Run tests across completely isolated browser contexts with independent cookies, local storage, and session state.
5. **Trace & Artifact Recording**: Automatically record traces, videos, and full-page screenshots on test failure for rapid CI triage.
