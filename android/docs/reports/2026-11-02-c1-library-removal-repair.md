# C1 — Library removal storage failure repair

Only C1 from the full recheck is addressed here. Other repairs already present in the working tree are preserved.

## Behavior

Library removal now returns an awaited result. The record remains visible until its Library write succeeds. A rejected or throwing write retains the record, logs the error and shows a retry message through the Library screen's mounted State context. No downloaded file is deleted.

Removal joins the same save queue as other record writes. Ordinary saves now capture their data when their queued operation executes, so a later save cannot restore a successfully removed entry from an earlier snapshot. Native ownership reconciliation happens only after a successful Library write.

## Files

- `lib/providers/download_provider.dart`: durable removal, caught/logged failures and ordered save snapshots.
- `lib/screens/library_screen.dart`: display the failure message after the awaited result.
- `test/library_removal_failure_test.dart`: new tests for successful, rejected and throwing writes, retry, retained records while a write is pending, later saves, and the visible error message.

Existing tests were neither edited nor removed. No packages were added. The original isolated C1 reproduction is unchanged.

## Evidence

Logs: `_recovery/c1-repair-2026-11-02/`.

- The original audit reproduction previously failed its rejected-write case; after the repair, both original cases pass (`original-repro.log`).
- Focused removal, ownership-reconciliation and enqueue-recovery checks: 17 passed (`focused.log`).
- Four new provider/screen regressions passed (`widget-final.log`). The screen test waits for asynchronous menu selection and persistence before asserting the error message; its assertions were retained throughout debugging.
- Final full Restricted Flutter suite: **170 passed**, exit 0 (`full-final.log`).
- Final whole-folder Flutter analysis: **No issues found**, exit 0 (`analysis-final.log`).

No native code or Python changed for C1. No fresh APK, physical-device storage-full test, installation or GitHub push was performed. The earlier live JVM probe's DNS failure is not claimed resolved by this repair.
