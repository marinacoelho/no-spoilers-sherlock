---
name: WCAG 2.2 Web Accessibility Standards
description: WCAG 2.2 AAA accessibility audit, semantic HTML, ARIA roles, focus management, keyboard navigation.
---

# WCAG 2.2 Web Accessibility Standards

Comprehensive guidelines for engineering accessible web experiences adhering to WCAG 2.2 AA and AAA criteria.

## Key Principles

1. **Semantic HTML First**: Always prefer native interactive elements (`<button>`, `<a>`, `<dialog>`, `<input>`) before resorting to `<div>` or `<span>` with custom click handlers.
2. **Keyboard Traversal & Focus Rings**: Ensure every interactive element is reachable via standard `Tab` / `Shift+Tab` navigation and displays an unambiguous, high-contrast `:focus-visible` indicator. Never remove outlines with `outline: none` without providing an accessible alternative.
3. **ARIA Roles & Accessible Names**: Every interactive widget must have a computable accessible name (`aria-label`, `aria-labelledby`, or text content). Use ARIA roles to augment, not replace, native semantic markup.
4. **Focus Trapping & Dismissal**: Modal dialogs and overlay menus must trap focus while open, release focus upon closing back to the triggering element, and support dismissal via the `Escape` key.
5. **Color Contrast & Motion Preferences**: Maintain a minimum contrast ratio of 4.5:1 for normal text (7:1 for AAA) and honor `prefers-reduced-motion` media queries by disabling non-essential transitions and animations.
