---
id: firebase-app-hosting
name: Firebase App Hosting & Next.js SSR
author: Firebase / Google
platform: web
repository: firebase/skills
path: skills/firebase-app-hosting-basics
default: true
description: Full-stack web application deployment (Next.js, Angular) with Server-Side Rendering (SSR) using Firebase App Hosting.
---

# Firebase App Hosting & Next.js SSR

Standards for configuring, building, and deploying modern full-stack web applications with Firebase App Hosting.

## Key Principles

1. **Architecture Model**: Use Firebase App Hosting for full-stack Next.js and Angular applications requiring Server-Side Rendering (SSR), Server Actions, or dynamic routing. For static single-page apps (SPAs), use classic Firebase Hosting.
2. **App Hosting Configuration**: Configure backend compute settings, memory limits, and environment variables inside `apphosting.yaml` at the root of the web project.
3. **Secret Management**: Secure sensitive API tokens and keys with Cloud Secret Manager and reference them via secret bindings in `apphosting.yaml`.
4. **Automated CI/CD**: Connect the GitHub repository directly to Firebase App Hosting for zero-configuration continuous deployments on pull requests and main branch merges.
5. **Billing Prerequisites**: Ensure the target Google Cloud / Firebase project is on the pay-as-you-go Blaze billing plan to allocate serverless backend compute instances.
