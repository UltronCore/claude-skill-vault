# Changelog — Public Release Review

## v1 — 2026-03-26

Initial release.

- Full public release quality gate with six review phases: safety, README quality, version visibility, changelog quality, public update notes, and download readiness
- Auto-triggered via vault-push-guardian Phase 2F on any `public_safe: true` skill in the pre-push diff
- Parallel agent support for full-vault scans (safety / docs / changelog passes)
- Release significance logic for deciding update note depth (patch/minor/major)
- Silent operation — output only when issues found or update notes generated
