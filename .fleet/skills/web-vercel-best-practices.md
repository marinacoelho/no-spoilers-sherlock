---
id: web-vercel-best-practices
name: Next.js App Router & Vercel Best Practices
author: Vercel Engineering
platform: web
repository: vercel/next.js
path: packages/next/skills/best-practices
default: true
description: Next.js App Router, Server vs Client components, streaming SSR, Server Actions, avoiding water-falling.
---

# Next.js App Router & Vercel Best Practices

Performance, architecture, and ergonomics standards for Next.js and Vercel deployments.

## Key Principles

1. **Server Components by Default**: Treat all components in the App Router as React Server Components (RSC). Add `'use client'` only when attaching event handlers, local state (`useState`), effects (`useEffect`), or browser-only APIs.
2. **Prevent Request Waterfalls**: Fetch data in parallel with `Promise.all` or hoist queries to parent layout boundaries rather than chaining serial `await` calls across subcomponents.
3. **Streaming & Suspense Boundaries**: Wrap data-fetching views in `<Suspense fallback={<Skeleton />}>` to unlock instantaneous TTFB and progressive streaming HTML.
4. **Server Actions & Mutations**: Implement mutations via `'use server'` Server Actions with optimistic UI updates (`useOptimistic`), input validation (Zod), and granular revalidation (`revalidatePath`, `revalidateTag`).
5. **Bundle Optimization**: Keep client bundles lean by importing icons and heavy utility packages individually or dynamically via `next/dynamic`.
