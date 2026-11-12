# Contributing to TurboSave Android

Start with `RECOVERY.md`, `PIPELINE_AUDIT.md` and `RELEASE_READINESS.md`. Preserve an untouched recovery baseline. Explain reconstructed changes explicitly rather than presenting them as original recovered source.

Run Flutter analysis and tests. Existing pipeline regression failures are recorded and must not be hidden by deleting tests. Android build, storage, method channels and real-device behaviour require the separate native reconstruction milestone. Keep signing keys, original backup APKs and private configuration out of public commits.
