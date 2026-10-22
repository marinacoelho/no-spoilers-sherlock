---
id: firebase-data-connect
name: Firebase Data Connect (SQL Connect) PostgreSQL
author: Firebase / Google
platform: universal
repository: firebase/skills
path: skills/firebase-data-connect-basics
default: true
description: Relational database architecture using Cloud SQL for PostgreSQL with GraphQL schema, queries, mutations, and generated type-safe SDKs.
---

# Firebase Data Connect (SQL Connect) PostgreSQL

Architecture and development patterns for building relational data backends with Firebase Data Connect and Cloud SQL for PostgreSQL.

## Key Principles

1. **Schema Definition**: Define data models in `dataconnect/schema/schema.gql` using GraphQL types annotated with `@table` directives and foreign key relations.
2. **Operations & Queries**: Author authorized queries and mutations in `.gql` files under `dataconnect/connector/` rather than exposing arbitrary client-side SQL statements.
3. **Type-Safe SDK Generation**: Configure `connector.yaml` to generate strongly-typed client SDKs for web, Swift (iOS), Kotlin (Android), and Flutter.
4. **Local Emulation**: Emulate PostgreSQL and the Data Connect service locally using the Firebase CLI emulator suite with Docker integration.
5. **Authorization Directives**: Secure every operation with `@auth(level: ...)` directives ensuring users can only read or mutate authorized entity records.
