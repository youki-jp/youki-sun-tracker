# Local SQLite auth storage

Status: Implemented locally; DigitalOcean deployment pending.
Updated: 2026-09-28

## Quick read

### What changed

Youki's account, session, entitlement, challenge, and forecast-quota storage now uses a local SQLite file. Drizzle defines the schema and applies versioned migrations. A backup command creates and verifies consistent snapshots.

### Why it matters

The auth server can run without a separately billed PostgreSQL service while targeting one persistent server instance.

### Current state

Implemented and tested against real local SQLite files. The iOS and HTTP auth contracts are unchanged. No live Apple sign-in or hosted deployment was exercised.

### Next step

Move the server to a Droplet with a persistent `SQLITE_PATH`, HTTPS, scheduled off-machine backups, and a new CI/CD target before switching the iOS release URL.

## Changed surface

| Area | Status | Details |
| --- | --- | --- |
| Schema and migrations | Implemented | [Drizzle schema](../../server/src/infrastructure/auth/sqlite-schema.ts), [migration](../../server/drizzle/0000_lumpy_maestro.sql), [runner](../../server/scripts/migrate.ts) |
| Account persistence and quotas | Implemented | [SQLite store](../../server/src/infrastructure/auth/sqlite-auth-store.ts), [connection setup](../../server/src/infrastructure/auth/sqlite-database.ts) |
| Backup and recovery | Implemented locally | [Backup command](../../server/scripts/backup.ts), [backup/restore test](../../server/src/infrastructure/auth/sqlite-auth-store.test.ts) |
| Runtime and usage | Implemented locally | [Server entry point](../../server/src/index.ts), [package scripts](../../server/package.json), [setup guide](../auth-implementation.md) |

## Engineer details

### Design and decisions

- Bun's SQLite driver handles the live store; Drizzle owns the schema and migration files. The `AuthStore` contract and iOS API shapes did not change.
- The connection enables WAL, full synchronous commits, foreign keys, and a five-second busy timeout. Production requires an absolute `SQLITE_PATH`; startup fails if the schema file is missing.
- Minute and UTC-day counters update inside an immediate transaction. A denied minute request returns its day increment, preserving the daily budget.
- The backup command uses SQLite `VACUUM INTO`, runs `integrity_check`, and refuses to overwrite an existing file. The restore test copies a backup and reads its account and session records.

### Contracts and flow

Sign in with Apple leads to Youki-issued session hashes in the SQLite store. Authenticated forecast routes load the account tier and consume the matching SQLite quota. The server still requires Apple credentials at startup. See the [account guide](../auth-implementation.md).

### Delegated-agent outcomes

None.

### Verification

| Check | Result | Evidence |
| --- | --- | --- |
| `bun test` | Passed | 22 tests, including five real SQLite tests. |
| `bun run typecheck` | Passed | Production TypeScript checks. |
| `bun build src/index.ts --target bun` | Passed | Server bundle built. |
| `bun run migration:generate` | Passed | No schema drift after the initial migration. |
| `bun run migrate` | Passed | Created local SQLite schema; rerun is safe. |
| `bun run backup -- ...` | Passed | Snapshot integrity check returned `ok`; restore test recovered account and session records. |
| Local HTTP smoke check | Passed | Readiness 200 and unauthenticated `/api/v1/me` 401 using temporary test credentials. |

### Risks and limitations

- DigitalOcean App Platform cannot persist the SQLite file between deployments. The current release iOS URL still points there. The SQLite build must not be deployed to App Platform.
- This is a single-instance design. Multiple app replicas cannot share this file or its account quotas.
- The local backup command does not schedule or upload backups. Hosted retention and restore drills remain to be implemented.
- The earlier local PostgreSQL development container was stopped; its volume was retained. No PostgreSQL data migration was needed for the empty local auth database.

### Follow-ups

- Build and test the Droplet deployment and backup schedule, then cut over the iOS release URL.
- Verify real Apple sign-in, revocation, account deletion, and authenticated forecast requests on a device.

### Not implemented or unverified

- DigitalOcean cutover, remote backup storage, live Apple credentials, and StoreKit payment verification.
