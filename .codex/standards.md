# Engineering Standards

## General

- Inspect the relevant source and current Git state before editing.
- Keep changes focused. Do not rewrite unrelated user work or application history.
- Prefer small, named abstractions over large one-shot files.
- Use ASCII for new source and documentation unless a file already requires another character set.
- Add comments only when they explain a non-obvious decision or constraint.
- Do not commit secrets, generated output, `.DS_Store`, Xcode user state, `node_modules`, or derived build directories.

## TypeScript Backend

- Keep domain types independent of Hono, `fetch`, and Open-Meteo response shapes.
- Keep external API parsing and normalization inside `server/src/infrastructure/`.
- Keep orchestration in application services and expose dependencies through ports.
- Validate request payloads at the HTTP boundary with `ValidationError`.
- Preserve nullable values from external APIs. Missing data should reduce confidence rather than be silently converted into a strong prediction.
- Use the existing `AppError` path for expected client and external-service failures.
- Keep endpoint behavior stable unless a contract change is intentional and documented.
- Do not add a new provider implementation without a clear test or runtime use case.

## SwiftUI Frontend

- Keep `ContentView` focused on screen state and composition.
- Keep reusable visual sections in focused files or components.
- Keep sample data and preview-only state separate from future API models.
- Do not perform network calls directly in a view body.
- Preserve the current contained layout and safe-area behavior when refactoring.
- When adding a Swift file, update the Xcode project file and verify a real build.
- Keep theme-dependent colors derived from `AppTheme`; do not hard-code light-mode text colors in individual sheets.

## Documentation

- Label implemented behavior, prototype behavior, and future proposals separately.
- Treat `docs/sky-color-prediction.md` as the architecture and research proposal.
- Treat `docs/current-state.md` as the implementation snapshot.
- Update `CLAUDE.md` or `.codex/` only when project boundaries, commands, or known risks change.
- Prefer links to canonical source files over copying large implementation details into documentation.

## Verification

For backend changes:

```bash
cd server
bun build src/index.ts --target bun --outdir /tmp/youki-server-build
```

When possible, run the server briefly and smoke test:

```bash
curl http://localhost:3000/api/v1/health
curl -X POST http://localhost:3000/api/v1/sky-color/predictions \
  -H 'content-type: application/json' \
  -d '{"location":{"latitude":35.6762,"longitude":139.6503},"requestedEvents":["sunrise"]}'
```

For iOS changes, build the `YoukiApp` scheme for the iOS Simulator. If the change affects layout, launch the app and inspect a simulator screenshot as well.

Before committing:

```bash
git diff --check
git status --short --branch
```

## Git

- Use a descriptive branch for a coherent task.
- Commit related changes together with a concise imperative message.
- Never use destructive reset or checkout commands to discard work without explicit approval.
- Push the finished branch when the user asks for the work to be pushed.
- Do not create or rewrite a pull request unless requested.
