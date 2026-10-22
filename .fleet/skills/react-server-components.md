---
id: react-server-components
name: React Server Components Standards
author: Vercel
repository: vercel/next.js
path: packages/next/skills/rsc
description: Modern React Server Components architecture and client/server boundaries
---

# React Server Components Standards

- Default components to Server Components unless client interactivity (hooks, event listeners) is required.
- Push `'use client'` boundaries down to the leaves of the component tree.
- Keep data fetching on the server; pass serializable props down to client components.
