# Dependencies

How baseX keeps its package dependencies current without breaking the apps
built on it.

## Policy

- **Update for security, not for freshness.** A dependency is bumped only when
  the locked version is inside the affected range of a published security
  advisory.
- **No major bumps.** Security updates stay within the current major version
  (the existing `^` constraint). If the only fixed release is a new major,
  record it under [Open items](#open-items) and plan it as its own breaking
  release of baseX.
- **Raise the floor, don't just re-lock.** baseX is consumed as a package, so
  apps resolve their own versions. When a fix lands, raise the lower bound in
  `pubspec.yaml` (e.g. `dio: ^5.9.1` → `^5.10.0`) so no consuming app can
  resolve the vulnerable version.
- **Apps check their own lock file too.** Transitive packages pulled in by the
  app (not by baseX) are the app's responsibility; run the same audit there.

## Auditing

1. List what is outdated, and how far:

   ```sh
   dart pub outdated --no-dev-dependencies
   ```

   `Upgradable` stays within the current constraints; `Resolvable` may cross a
   major version.

2. Check every hosted package in `pubspec.lock` against pub.dev advisories:

   ```sh
   awk '/^  [a-z_0-9]+:$/{n=$1;sub(":","",n)} /source: hosted/{print n}' pubspec.lock \
     | sort -u \
     | while read p; do
         c=$(curl -s "https://pub.dev/api/packages/$p/advisories" \
           | python3 -c 'import sys,json; print(len(json.load(sys.stdin).get("advisories",[])))')
         [ "$c" != "0" ] && echo "$p $c"
       done
   ```

3. For each package listed, compare the locked version with the advisory's
   `affected[].ranges[].events` (`introduced` / `fixed`):

   ```sh
   curl -s https://pub.dev/api/packages/<name>/advisories
   ```

   Only a locked version inside an affected range needs action.

4. After any bump: `flutter pub get`, `flutter analyze`, then build a consuming
   app (`flutter build ios --simulator --debug`) before tagging a release.

## Audit log

### 2026-10-13 — baseX 1.0.0 (Flutter 3.47.0, Dart 3.13.0)

No action needed: every package with an advisory is locked past its fix.

| Package | Locked | Advisory | Fixed in |
|---|---|---|---|
| dio | 5.11.1 | GHSA-9324-jv53-9cc8 — CRLF injection via HTTP method (GHSA-jwpw-q68h-r678 is a duplicate) | 5.0.0 |
| http | 1.6.0 | GHSA-4rgh-jx4f-qfcq — header injection | 0.13.3 |
| shared_preferences_android | 2.4.28 | GHSA-3hpf-ff72-j67p | 2.3.4 |

Also checked in a consuming app: `archive` 4.0.9 (via `image`) —
GHSA-9v85-q87q-g4vg path traversal and GHSA-r285-q736-9v95 filename spoofing,
both fixed in 3.3.8.

## Open items

Major versions available but deliberately not taken (no advisory against the
current line). Each needs its own breaking-change review:

| Package | Current | Latest |
|---|---|---|
| android_id | 0.5.1 | 0.6.0 |
| cached_network_image | 3.4.1 | 4.0.4 |
| device_info_plus | 12.4.0 | 13.3.0 |
| flutter_local_notifications | 20.1.0 | 22.3.2 |
| flutter_secure_storage | 10.3.1 | 11.2.0 |
| map_launcher | 4.5.0 | 6.0.0 |
| package_info_plus | 9.0.1 | 10.2.2 |
| sign_in_with_apple | 7.0.1 | 8.2.0 |
