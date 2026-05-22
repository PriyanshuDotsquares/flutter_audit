import 'dart:async';
import 'dart:io';

import 'package:args/command_runner.dart';
import 'package:mason_logger/mason_logger.dart';
import 'package:path/path.dart' as p;

import '../core/parser.dart';
import '../core/rules_engine.dart';
import '../core/scanner.dart';
import '../core/score_calculator.dart';
import '../models/report.dart';
import '../models/severity.dart';
import '../output/html_reporter.dart';
import '../output/json_reporter.dart';
import '../output/terminal_reporter.dart';
import '../rules/avoid_foreach_rule.dart';
import '../rules/avoid_inline_text_style_rule.dart';
import '../rules/base_rule.dart';
import '../rules/business_logic_in_widget_rule.dart';
import '../rules/cancel_subscriptions_rule.dart';
import '../rules/close_sinks_rule.dart';
import '../rules/deep_widget_nesting_rule.dart';
import '../rules/dispose_controllers_rule.dart';
import '../rules/empty_catch_rule.dart';
import '../rules/hardcoded_secret_rule.dart';
import '../rules/hardcoded_size_rule.dart';
import '../rules/hardcoded_url_rule.dart';
import '../rules/huge_build_method_rule.dart';
import '../rules/insecure_http_rule.dart';
import '../rules/long_method_rule.dart';
import '../rules/missing_const_rule.dart';
import '../rules/missing_key_in_list_rule.dart';
import '../rules/missing_try_catch_rule.dart';
import '../rules/prefer_listview_builder_rule.dart';
import '../rules/print_in_production_rule.dart';
import '../rules/todo_comment_rule.dart';
import '../rules/unsafe_storage_rule.dart';

/// `flutter_audit scan <path>` — runs the full audit pipeline.
class ScanCommand extends Command<int> {
  @override
  String get name => 'scan';

  @override
  String get description =>
      'Scan a Flutter project and produce an audit report.';

  ScanCommand() {
    argParser.addOption(
      'output',
      abbr: 'o',
      allowed: ['terminal', 'json', 'html'],
      defaultsTo: 'terminal',
      help: 'Output format.',
    );
    argParser.addOption(
      'report-file',
      help:
          'Path to write the report to (only used when --output=html or json). '
          'Defaults to flutter_audit_report.<ext> in the current directory.',
    );
    argParser.addFlag(
      'fail-on-error',
      defaultsTo: false,
      help: 'Exit with non-zero code if any error/critical issue is found.',
    );
  }

  /// All rules registered in this build of the tool.
  ///
  /// Grouped by category. Add a new rule by importing it and appending to
  /// the appropriate section — nothing else needs to change.
  static List<AuditRule> defaultRules() => [
    // performance
    MissingConstRule(),
    AvoidForEachRule(),
    PreferListViewBuilderRule(),
    // memory
    DisposeControllersRule(),
    CancelSubscriptionsRule(),
    CloseSinksRule(),
    // security
    HardcodedSecretRule(),
    InsecureHttpRule(),
    UnsafeStorageRule(),
    // api
    PrintInProductionRule(),
    MissingTryCatchRule(),
    HardcodedUrlRule(),
    // architecture
    HugeBuildMethodRule(),
    DeepWidgetNestingRule(),
    BusinessLogicInWidgetRule(),
    // ui
    MissingKeyInListRule(),
    AvoidInlineTextStyleRule(),
    HardcodedSizeRule(),
    // quality
    EmptyCatchRule(),
    TodoCommentRule(),
    LongMethodRule(),
  ];

  @override
  Future<int> run() async {
    final logger = Logger();
    final rest = argResults?.rest ?? const [];
    final targetPath = rest.isEmpty ? '.' : rest.first;
    final absolutePath = p.absolute(targetPath);

    if (!Directory(absolutePath).existsSync()) {
      logger.err('Directory not found: $absolutePath');
      return 1;
    }

    final outputFormat = argResults!['output'] as String;
    final reportFile = argResults!['report-file'] as String?;
    final failOnError = argResults!['fail-on-error'] as bool;
    final isJson = outputFormat == 'json';
    final isHtml = outputFormat == 'html';
    final isQuiet = isJson; // JSON goes to stdout — keep progress UI quiet.

    final stopwatch = Stopwatch()..start();

    // ----- Scan -----
    final scanProgress = isQuiet ? null : logger.progress('Scanning project');
    final scanner = Scanner();
    final files = await scanner.scan(absolutePath);
    scanProgress?.complete('Scanned ${files.length} Dart files');

    if (files.isEmpty) {
      if (!isJson) logger.warn('No Dart files found in $absolutePath');
      return 0;
    }

    // ----- Parse -----
    final parseProgress = isQuiet ? null : logger.progress('Parsing AST');
    final parser = Parser();
    final parsed = await parser.parseAll(files);
    parseProgress?.complete('Parsed ${parsed.length} files');

    // ----- Run rules -----
    final rules = defaultRules();
    final ruleProgress = isQuiet
        ? null
        : logger.progress('Running ${rules.length} rules');
    final engine = RulesEngine(rules);
    final issues = engine.run(parsed);
    ruleProgress?.complete('Found ${issues.length} issues');

    // ----- Score & build report -----
    final scores = ScoreCalculator().compute(issues);
    final totalLines = parsed.fold<int>(0, (sum, f) => sum + f.lineCount);

    stopwatch.stop();

    final report = Report(
      projectName: p.basename(absolutePath),
      filesScanned: parsed.length,
      linesAnalyzed: totalLines,
      elapsed: stopwatch.elapsed,
      issues: issues,
      scores: scores,
      timestamp: DateTime.now(),
    );

    // ----- Render -----
    if (isHtml) {
      final outPath = reportFile ?? 'flutter_audit_report.html';
      final outFile = File(outPath);
      await outFile.writeAsString(
        HtmlReporter(projectRoot: absolutePath).render(report),
      );
      logger.info('');
      logger.info('HTML report written to ${outFile.absolute.path}');
    } else if (isJson) {
      if (reportFile != null) {
        await File(reportFile).writeAsString(JsonReporter().render(report));
      } else {
        stdout.write(JsonReporter().render(report));
        stdout.writeln();
      }
    } else {
      TerminalReporter(
        projectRoot: absolutePath,
        logger: logger,
      ).render(report);
    }

    // ----- Exit code -----
    if (failOnError) {
      final hasSerious = issues.any(
        (i) => i.severity == Severity.error || i.severity == Severity.critical,
      );
      if (hasSerious) return 2;
    }
    return 0;
  }
}
