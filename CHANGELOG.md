# Changelog

## 1.0.1

- Added MIT `LICENSE` file required by pub.dev.
- Added `.pubignore` so generated reports, build cache, and dev artifacts no
  longer ship with the published archive (drops package size from ~6 MB to
  ~40 KB).
- Fixed terminal reporter category labels to match the actual rule IDs
  (`dispose_controllers`, `cancel_subscriptions`, etc.) instead of stale
  placeholder names.
- Trimmed unused `glob`, `yaml`, and `meta` dependencies from `pubspec.yaml`.
- Updated `repository` and `issue_tracker` metadata in `pubspec.yaml`.
- Removed dead `test/fixtures/sample_project/` directory.
- Documented `dart pub global activate` as the recommended install in
  `README.md`.

## 1.0.0

- Initial release: 21 audit rules across performance, memory, security, API,
  architecture, UI, and code quality.
- Terminal, JSON, and self-contained HTML output formats.
- `--fail-on-error` flag for CI integration.
