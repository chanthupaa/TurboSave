# A5: preserve the Home link draft across tabs

1 November 2026. Scope: A5 only.

## Change

Home is deliberately unmounted when the user selects another tab. Its text controller was therefore disposed, and returning Home created a blank controller or restored an older shared URL.

The navigation screen now owns the draft string. Home reports controller changes through a callback and restores that draft when remounted. The listener covers typing, clearing, clipboard paste, recent links, sample shortcuts and incoming shares. A new share updates the navigation-owned draft, including when its URL matches an earlier share. Empty drafts remain empty instead of falling back to stale shared text.

Only the draft string survives tab changes. Hidden screens still unmount, Home still disposes its controller/focus node, and typing does not rebuild the parent. The draft is not written to preferences or a database and is not retained after the navigation screen/app is destroyed. Existing optional standalone `DownloaderScreen` callers continue to work.

## Verification

```text
Existing A5 reproduction before the repair:
0 passed, 1 failed (the original link was replaced with empty text)

New tests against the old source:
1 passed, 7 failed

New tests after the repair:
8 passed, 0 failed

flutter test --no-pub --reporter expanded
111 passed, 4 failed

flutter analyze --no-pub lib test
No issues found!
```

The eight new tests cover all tab round-trips at phone and wide-navigation sizes, exact text preservation, edited/cleared shared links, a new share while Home is hidden, sharing the same URL again after editing, clipboard paste and the sample shortcut. They also check that Home is unmounted while hidden, dismissed details do not reopen on return, no file is enqueued automatically, and history remains disabled.

The original A5 audit test now passes unchanged. The existing second-fast-share, cold-share and dismissed-sheet checks remain passing. The four full-suite failures exactly match the A7 baseline after removing A5: A6 acknowledgement retry, A8 literal URL punctuation, A9 accessible fetch action and A10 theme toggle. A13 whole-folder archive analysis is still a separate finding; the analysis above covers maintained `lib`/`test` only.

SHA-256 comparison of 81 pre-existing maintained source/test/configuration files found only the two UI files below changed. No existing test, provider, native/Python code, source policy or dependency file was changed. No package was added.

## Files and evidence

- [main_navigation_screen.dart](<C:/Users/HP OFFICIAL/Desktop/app/TurboSave/MOBILE APP/lib/screens/main_navigation_screen.dart>) — owns the draft and updates it on incoming shares.
- [downloader_screen.dart](<C:/Users/HP OFFICIAL/Desktop/app/TurboSave/MOBILE APP/lib/screens/downloader_screen.dart>) — restores/reports draft text while preserving controller disposal and existing share presentation.
- Added [home_draft_test.dart](<C:/Users/HP OFFICIAL/Desktop/app/TurboSave/MOBILE APP/test/home_draft_test.dart>) — eight regression cases.
- Updated the [roadmap](<C:/Users/HP OFFICIAL/Desktop/app/TurboSave/MOBILE APP/docs/plans/2026-10-30-mobile-bug-fixing-roadmap.md>) and added this report.
- [Recovery evidence](<C:/Users/HP OFFICIAL/Desktop/app/TurboSave/MOBILE APP/_recovery/a5-draft>) — original/new failing-before logs, focused/full Flutter results, analysis, before-files, hash comparison and a three-file repair patch validated with `git apply --reverse --check`.

Local branch: `fix/a5-home-draft`. The repository still has no initial commit, so no partial initial commit or broad staging was made. Before-files and the validated patch preserve this finding separately. Nothing was pushed or deployed.

## Not verified

No APK build/installation, physical-phone navigation, Android keyboard/share sheet or process-restart testing was performed. Automated widget tests use mocked native/clipboard channels. Native JVM/Python suites were not rerun for this Dart UI-only change; their source remains unchanged. The live-network TLS timeout recorded during A7 remains unverified and is not counted as passing here.

Five findings remain: A6, A8, A9, A10 and A13. Stop here; A6 share acknowledgement retry is next, only after the user's confirmation.
