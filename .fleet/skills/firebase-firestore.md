---
id: firebase-firestore
name: Cloud Firestore Database & Queries
author: Firebase / Google
platform: universal
repository: firebase/skills
path: skills/firebase-firestore
default: true
description: Firestore database setup, data modeling, compound indexes, real-time listeners, and cross-platform SDK queries.
---

# Cloud Firestore Database & Queries

Authoritative standards for schema design, real-time synchronization, and high-performance querying in Cloud Firestore.

## Key Principles

1. **Data Modeling & Hierarchy**: Structure documents into subcollections for hierarchical ownership or root collections with reference fields for broad querying across tenants.
2. **Index Optimization**: Design composite indexes for compound queries (`where` + `orderBy`) and monitor index creation through CLI logs or `firestore.indexes.json`.
3. **Real-time Synchronization**: Use snapshot listeners (`onSnapshot` / `addSnapshotListener`) for collaborative UI surfaces, and unsubscribe when views unmount.
4. **Offline Persistence**: Enable offline caching in mobile and web clients to ensure seamless application functionality in degraded network conditions.
5. **Batch & Transaction Safety**: Use atomic transactions for concurrent balance or counter updates, and batched writes for non-dependent multi-document mutations.
