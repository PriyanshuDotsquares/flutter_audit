/// Public API for `flutter_audit`.
///
/// Most users run this tool via the `flutter_audit` CLI executable. This
/// library exists so the same engine can be embedded in IDE plugins, custom
/// scripts, or CI tooling.
library;

export 'core/parser.dart';
export 'core/rules_engine.dart';
export 'core/scanner.dart';
export 'core/score_calculator.dart';
export 'models/audit_score.dart';
export 'models/issue.dart';
export 'models/report.dart';
export 'models/severity.dart';
export 'rules/base_rule.dart';
