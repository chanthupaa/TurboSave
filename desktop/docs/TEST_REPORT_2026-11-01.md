# TurboSave Desktop test report — 2026-11-01

Target: local Windows x64 **0.8.0-beta.5** source, unpacked production package and portable executable. No GitHub uploads or publication were performed.

## Automated results

| Check | Result |
| --- | --- |
| Full Node suite | **112 passed, 0 failed, 0 skipped** on the final run |
| Packaged beta workflows | 15 passed |
| Packaged YouTube session handling | 6 passed with synthetic credentials |
| Packaged media details | 6 passed |
| Packaged appearance/onboarding/history | 9 passed |
| Packaged reliability, resume, tray, notifications | 8 passed |
| Packaged renderer/preload IPC | 3 passed |
| Packaged tamper protection and production fuses | 5 passed |
| Actual portable duplicate/media cleanup scenarios | 11 passed |
| Real Windows engine ZIP install, persistence and rollback | 4 passed |
| High-confidence source secret scan | Passed |
| Source/package identity | 38 protected files and all 4 bundled engines match |
| Cached engine verification | 4 full hashes across 26 toolchain checks; approximately 2.71 ms per cached check on this run |

The final source suite covers YouTube cookie encryption adapters, domain isolation, startup cleanup, Disconnect, a real read-only Firefox SQLite fixture, actual yt-dlp cookie-file parsing offline, bounded automatic cookie refresh and playlist suspension. Packaged tests additionally exercise actual Windows safeStorage encryption and the real renderer/preload bridge. No personal browser cookies or account credentials were read.

The first broad run exposed two test-fixture problems, corrected before rerunning the entire suite: the lifecycle fixture included the first full executable hash in a five-second child-spawn deadline, and the synthetic browser generated a different expiration timestamp on each read. The maintenance script also still used a relative PowerShell command; it now uses the same pinned absolute Windows system path as the app. Application security restrictions were retained. Runtime code was not changed during this test pass.

## Findings and live checks

- **Dependency audit: 15 moderate, 0 high, 0 critical advisories.** The reported dependency chain belongs to electron-builder, including minimatch/glob and packaging utilities. This is not a clean dependency audit. No forced dependency downgrade/update was applied. Inspect `artifacts/all-npm-audit-20261101.json` before changing the build toolchain; npm's proposed electron-builder change is a major-version downgrade.
- **Live YouTube playlist enumeration passed:** the public Blender sample returned 17 entries.
- **Live public MP4 inspection/download did not pass:** the sample endpoint could not be reached. A separate Windows curl probe reported `CRYPT_E_REVOCATION_OFFLINE`, indicating that its certificate-revocation service was unavailable. That probe does not establish the precise cause of the app's network failure. Certificate verification was not disabled.
- **Portable live-download smoke: inconclusive/timeout.** The original runner produced no report. A separate standalone launch with captured output also produced no smoke report, process exit or diagnostic output within 125 seconds. No successful public YouTube video/audio/thumbnail transfer is claimed. Offline portable duplicate/media scenarios passed independently. Investigate the live smoke startup/timeout and network conditions before release.

## Limits

The installed application was still **0.8.0-beta.4** when inspected. Results above refer to the matching beta.5 build in `release/`; an upgrade/install validation was not part of this test pass. A fresh Windows device/VM, a real authorized YouTube account, native consent interaction with personal cookies, and universal source availability are not proven by synthetic tests. The binaries remain unsigned, and public release/dependency-source gates still apply.

## Evidence

Final source output: `artifacts/all-source-tests-final-20261101.log`. Packaged reports: `artifacts/packaged-{beta,youtube,details,experience,reliability,ipc,security,duplicates}.json`. Maintenance report: `artifacts/maintenance-verification.json`. Live sample report: `artifacts/live-beta.json`. Audit: `artifacts/all-npm-audit-20261101.json`. These local artifacts are excluded from source publication and may contain test-profile paths.
