# Flutter Audit

A static analysis CLI for Flutter projects. Scans your codebase and reports
findings across **7 categories** — performance, memory safety, UI quality,
API hygiene, security, architecture, and code quality — in a single command,
in under a second.

```
$ flutter_audit scan .

OVERALL : 53 / 100  ###########.........  NEEDS WORK
```

---

## Quick start

### 1. Install (one time)

```bash
dart pub global activate flutter_audit
```

This installs `flutter_audit` as a global Dart CLI, isolated from your
project's pubspec — so it won't fight with `flutter_riverpod`, `analyzer`,
or any other dependency in your app.

> If `flutter_audit` isn't on your PATH after activation, add
> `$HOME/.pub-cache/bin` to your shell's PATH, or invoke via
> `dart pub global run flutter_audit scan .`

### 2. Run on any Flutter project

```bash
cd path/to/your/flutter/project
flutter_audit scan .
```

You'll get a colored terminal report with category scores, issue counts,
and the **top 5 issues to fix first**.

### 3. Generate a full HTML report

For a self-contained, shareable dashboard with every issue, category
breakdowns, and a "fix first" section:

```bash
flutter_audit scan . --output=html --report-file=audit-report.html
```

Then open `audit-report.html` in any browser. No JS dependencies, no
external assets — drop it in a CI artifact or email it to a teammate.

---

## All commands

```bash
# Pretty terminal report (default)
flutter_audit scan .

# Scan a specific project path
flutter_audit scan /path/to/flutter/app

# Full HTML dashboard
flutter_audit scan . --output=html --report-file=audit-report.html

# Machine-readable JSON (for CI pipelines, dashboards, custom tooling)
flutter_audit scan . --output=json --report-file=audit.json

# Fail the CI build when any error/critical issue is found
flutter_audit scan . --fail-on-error
```

---

## What it catches

21 built-in rules, organized by category:

| Category         | Rules                                                                  |
| ---------------- | ---------------------------------------------------------------------- |
| **Performance**  | `missing_const`, `avoid_foreach`, `prefer_listview_builder`            |
| **Memory**       | `dispose_controllers`, `cancel_subscriptions`, `close_sinks`           |
| **Security**     | `hardcoded_secret`, `insecure_http`, `unsafe_storage`                  |
| **API hygiene**  | `print_in_production`, `missing_try_catch`, `hardcoded_url`            |
| **Architecture** | `huge_build_method`, `deep_widget_nesting`, `business_logic_in_widget` |
| **UI quality**   | `missing_key_in_list`, `avoid_inline_text_style`, `hardcoded_size`     |
| **Code quality** | `empty_catch`, `todo_comment`, `long_method`                           |

Each finding has one of four severities: **critical** · **error** ·
**warning** · **info**.

---

## How scoring works

Each category starts at **100** and loses points per finding:

| Severity | Penalty |
| -------- | ------- |
| info     | −1      |
| warning  | −2      |
| error    | −5      |
| critical | −10     |

`category_score = max(0, 100 − Σ penalties)` — never goes below zero.

The **overall score** is a weighted average across categories:

| Category     | Weight | Reason                       |
| ------------ | ------ | ---------------------------- |
| memory       | 1.5    | crashes                      |
| security     | 1.5    | breaches                     |
| performance  | 1.2    | user-visible jank            |
| api          | 1.2    | user-visible network         |
| architecture | 1.0    | baseline maintainability     |
| ui           | 0.8    | cosmetic                     |
| quality      | 0.8    | cosmetic                     |

```
overall = round( Σ(score × weight) / Σ(weights) )
```

Grade labels: **EXCELLENT** ≥ 90 · **GOOD** 80–89 · **FAIR** 70–79 ·
**NEEDS WORK** 50–69 · **POOR** < 50.

---

## Output formats

| Format       | Flag                   | Best for                                |
| ------------ | ---------------------- | --------------------------------------- |
| **Terminal** | (default)              | Quick local checks, dev loop            |
| **HTML**     | `--output=html`        | Shareable reports, code reviews, CI     |
| **JSON**     | `--output=json`        | Pipelines, dashboards, custom tooling   |

Both `--output=html` and `--output=json` accept `--report-file=<path>` to
control where the file is written (defaults to stdout).

---

## CI / CD integration

```yaml
# .github/workflows/audit.yml
- run: dart pub global activate flutter_audit
- run: flutter_audit scan . --fail-on-error
- run: flutter_audit scan . --output=html --report-file=audit-report.html
- uses: actions/upload-artifact@v4
  with:
    name: audit-report
    path: audit-report.html
```

---

## Local development

To hack on `flutter_audit` itself:

```bash
git clone https://github.com/yourname/flutter_audit
cd flutter_audit
dart pub get
dart run bin/flutter_audit.dart scan /path/to/any/flutter/project
```

The `example/` directory ships two sample projects you can scan as a
sanity check:

```bash
# Should print OVERALL : 100 / 100  EXCELLENT
dart run bin/flutter_audit.dart scan example/clean_project

# Should print findings in every category
dart run bin/flutter_audit.dart scan example/issues_project
```

---

## Project structure

```
lib/
├── core/        Scanner, Parser, Rules Engine, Score Calculator
├── rules/       21 pluggable audit rules (one per file)
├── models/      Data classes (Issue, Report, Severity, AuditScore)
├── output/      Terminal, JSON, and HTML reporters
└── commands/    CLI subcommands
```

### Adding a new rule

1. Create `lib/rules/your_rule.dart` extending `AuditRule` (see
   `lib/rules/base_rule.dart`).
2. Set `category` to one of: `performance`, `memory`, `security`, `api`,
   `architecture`, `ui`, `quality`.
3. Set `defaultSeverity` (`info` / `warning` / `error` / `critical`).
4. Implement `check(ParsedFile file) → List<Issue>`.
5. Register it in `lib/commands/scan_command.dart`'s `defaultRules()`.

No changes to the score calculator, reporters, or CLI needed — they're
already wired for all 7 categories and 4 severities.

---

## License

MIT
