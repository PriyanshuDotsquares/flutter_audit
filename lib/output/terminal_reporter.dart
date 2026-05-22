import 'package:mason_logger/mason_logger.dart';
import 'package:path/path.dart' as p;

import '../models/audit_score.dart';
import '../models/report.dart';
import '../models/severity.dart';

/// Pretty terminal renderer: scores, category breakdown, top issues.
class TerminalReporter {
  final Logger _logger;
  final String _projectRoot;

  TerminalReporter({Logger? logger, required String projectRoot})
    : _logger = logger ?? Logger(),
      _projectRoot = projectRoot;

  void render(Report report) {
    _header();
    _projectInfo(report);
    _scores(report.scores);
    _byCategory(report);
    _topIssues(report);
    _footer();
  }

  void _header() {
    final line = '=' * 60;
    _logger.info('');
    _logger.info(styleBold.wrap(line));
    _logger.info(styleBold.wrap('   FLUTTER AUDIT REPORT'));
    _logger.info(styleBold.wrap(line));
    _logger.info('');
  }

  void _projectInfo(Report report) {
    _logger.info('Project        : ${report.projectName}');
    _logger.info('Files scanned  : ${report.filesScanned}');
    _logger.info('Lines analyzed : ${report.linesAnalyzed}');
    _logger.info('Time elapsed   : ${report.elapsed.inMilliseconds}ms');
    _logger.info('');
  }

  void _scores(AuditScore scores) {
    _logger.info('-' * 60);
    _logger.info('SCORES');
    _logger.info('-' * 60);
    _scoreLine('Architecture Score', scores.architecture);
    _scoreLine('Performance Score ', scores.performance);
    _scoreLine('Memory Safety     ', scores.memory);
    _scoreLine('UI Quality        ', scores.ui);
    _scoreLine('API Hygiene       ', scores.api);
    _scoreLine('Security Score    ', scores.security);
    _scoreLine('Code Quality      ', scores.quality);
    _logger.info('');
    _scoreLine('OVERALL           ', scores.overall, isOverall: true);
    _logger.info('');
  }

  void _scoreLine(String label, int score, {bool isOverall = false}) {
    final filled = (score / 5).round();
    final bar = '${'#' * filled}${'.' * (20 - filled)}';
    final grade = _gradeFor(score);
    final colored = _colorize('$score / 100  $bar  $grade', score);
    final formatted = '$label : $colored';
    if (isOverall) {
      _logger.info(styleBold.wrap(formatted));
    } else {
      _logger.info(formatted);
    }
  }

  String _gradeFor(int score) {
    if (score >= 90) return 'EXCELLENT';
    if (score >= 80) return 'GOOD';
    if (score >= 70) return 'FAIR';
    if (score >= 50) return 'NEEDS WORK';
    return 'POOR';
  }

  String _colorize(String text, int score) {
    if (score >= 80) return green.wrap(text)!;
    if (score >= 60) return yellow.wrap(text)!;
    return red.wrap(text)!;
  }

  void _byCategory(Report report) {
    _logger.info('-' * 60);
    _logger.info('ISSUES BY CATEGORY  (Total: ${report.issues.length})');
    _logger.info('-' * 60);

    final categories = report.byCategory;
    if (categories.isEmpty) {
      _logger.info(green.wrap('  No issues found.')!);
      _logger.info('');
      return;
    }

    final ordered = [
      'security',
      'memory',
      'api',
      'performance',
      'ui',
      'architecture',
      'quality',
    ];
    for (final cat in ordered) {
      final list = categories[cat];
      if (list == null || list.isEmpty) continue;
      _logger.info('');
      _logger.info(
        '${styleBold.wrap('[${cat.toUpperCase()}]')}  ${list.length} issues',
      );

      // Group by ruleId within category.
      final byRule = <String, int>{};
      for (final issue in list) {
        byRule[issue.ruleId] = (byRule[issue.ruleId] ?? 0) + 1;
      }
      for (final entry in byRule.entries) {
        _logger.info('  X ${entry.value} ${_humanize(entry.key)}');
      }
    }
    _logger.info('');
  }

  void _topIssues(Report report) {
    if (report.issues.isEmpty) return;

    _logger.info('-' * 60);
    _logger.info('TOP 5 ISSUES TO FIX FIRST');
    _logger.info('-' * 60);

    final sorted = [...report.issues]
      ..sort(
        (a, b) => b.severity.scorePenalty.compareTo(a.severity.scorePenalty),
      );

    for (var i = 0; i < sorted.length && i < 5; i++) {
      final issue = sorted[i];
      final rel = p.relative(issue.filePath, from: _projectRoot);
      final severityColored = _severityColor(issue.severity);
      _logger.info('  ${i + 1}. $severityColored  $rel:${issue.line}');
      _logger.info('     ${issue.message}');
      if (issue.suggestion != null) {
        _logger.info('     ${cyan.wrap(issue.suggestion!)}');
      }
      _logger.info('');
    }
  }

  String _severityColor(Severity sev) {
    final label = sev.label.padRight(8);
    return switch (sev) {
      Severity.critical => red.wrap(styleBold.wrap(label)!)!,
      Severity.error => red.wrap(label)!,
      Severity.warning => yellow.wrap(label)!,
      Severity.info => cyan.wrap(label)!,
    };
  }

  void _footer() {
    _logger.info('-' * 60);
    _logger.info('Run with --output=json for machine-readable output.');
    _logger.info('');
  }

  String _humanize(String ruleId) {
    return switch (ruleId) {
      'missing_const' => 'widgets missing const',
      'dispose_controllers' => 'undisposed controllers',
      'cancel_subscriptions' => 'uncancelled subscriptions',
      'close_sinks' => 'unclosed sinks',
      'hardcoded_secret' => 'hardcoded secrets',
      'insecure_http' => 'insecure http URLs',
      'unsafe_storage' => 'unsafe storage',
      'print_in_production' => 'print in production',
      'missing_try_catch' => 'missing try/catch',
      'hardcoded_url' => 'hardcoded URLs',
      'huge_build_method' => 'huge build method',
      'deep_widget_nesting' => 'deep widget nesting',
      'business_logic_in_widget' => 'business logic in widget',
      'missing_key_in_list' => 'missing key in list',
      'avoid_inline_text_style' => 'inline text style',
      'hardcoded_size' => 'hardcoded size',
      'empty_catch' => 'empty catch',
      'todo_comment' => 'TODO/FIXME comment',
      'long_method' => 'long method',
      'avoid_foreach' => 'forEach with closure',
      'prefer_listview_builder' => 'eager ListView/GridView',
      _ => ruleId.replaceAll('_', ' '),
    };
  }
}
