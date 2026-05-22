# flutter_audit examples

Two tiny Flutter-style projects used to demonstrate the auditor on both ends
of the spectrum.

> **Note:** these are **scan targets**, not runnable Flutter apps. They have
> no platform folders and don't depend on the Flutter SDK — `flutter run` will
> not work here. They exist only so `flutter_audit` has Dart source to analyze.

## clean_project — passes the audit (0 issues)

Every widget that can be `const` already is, no secrets, no leaks, no
hardcoded URLs, no inline styles.

```sh
dart run bin/flutter_audit.dart scan example/clean_project
```

Expected:

```
✓ Found 0 issues
Architecture Score : 100 / 100  EXCELLENT
Performance Score  : 100 / 100  EXCELLENT
Memory Safety      : 100 / 100  EXCELLENT
UI Quality         : 100 / 100  EXCELLENT
API Hygiene        : 100 / 100  EXCELLENT
Security Score     : 100 / 100  EXCELLENT
Code Quality       : 100 / 100  EXCELLENT
OVERALL            : 100 / 100  EXCELLENT
```

## issues_project — fails the audit (~100 issues across all 7 categories)

Intentionally exercises every rule: hardcoded secrets, plaintext
SharedPreferences for tokens, plain-HTTP URLs, undisposed controllers, an
unclosed StreamController, missing-const widgets everywhere, a 200-line
build method, deep nesting, `print` in production, `forEach` with closures,
inline `TextStyle`s, TODOs, an empty catch block, etc.

```sh
dart run bin/flutter_audit.dart scan example/issues_project
```

Expected (numbers may shift slightly as rules tune up):

```
✓ Found ~100 issues
Architecture Score : 91 / 100  EXCELLENT
Performance Score  :  0 / 100  POOR
Memory Safety      : 75 / 100  FAIR
UI Quality         : 87 / 100  GOOD
API Hygiene        : 94 / 100  EXCELLENT
Security Score     : 68 / 100  NEEDS WORK
Code Quality       : 94 / 100  EXCELLENT
OVERALL            : 70 / 100  FAIR
```

Top finding is a **CRITICAL** `hardcoded_secret` from
`lib/services/auth_service.dart`.

## Output formats

```sh
# Pretty terminal (default)
dart run bin/flutter_audit.dart scan example/issues_project

# JSON for CI/scripts
dart run bin/flutter_audit.dart scan example/issues_project \
    --output=json --report-file=audit.json

# Self-contained HTML dashboard
dart run bin/flutter_audit.dart scan example/issues_project \
    --output=html --report-file=example/issues_project_report.html
open example/issues_project_report.html
```

Pre-generated HTML reports live next to this README:
- [clean_project_report.html](clean_project_report.html) — passes everything
- [issues_project_report.html](issues_project_report.html) — fails 6 categories

Run both back-to-back to see the auditor produce a clean report and a
dirty one from the same tool.
