import 'dart:io';
import 'package:analyzer/dart/analysis/features.dart';
import 'package:analyzer/dart/analysis/utilities.dart';
import 'package:analyzer/dart/ast/ast.dart';

/// Holds the parsed AST of a single Dart source file plus the raw text.
///
/// Passed to every rule. Rules walk [unit] using AST visitors.
class ParsedFile {
  final File source;
  final CompilationUnit unit;
  final String content;
  final int lineCount;

  ParsedFile({required this.source, required this.unit, required this.content})
    : lineCount = '\n'.allMatches(content).length + 1;

  /// Returns the source line at [lineNumber] (1-based), trimmed.
  String? lineAt(int lineNumber) {
    final lines = content.split('\n');
    if (lineNumber < 1 || lineNumber > lines.length) return null;
    return lines[lineNumber - 1].trim();
  }
}

/// Wraps the `analyzer` package to produce [ParsedFile]s.
///
/// Files that fail to parse (syntax errors, encoding issues) are skipped
/// rather than crashing the whole scan.
class Parser {
  /// Parses [file] and returns its AST, or `null` if parsing fails.
  Future<ParsedFile?> parse(File file) async {
    try {
      final content = await file.readAsString();
      final result = parseString(
        content: content,
        path: file.absolute.path,
        featureSet: FeatureSet.latestLanguageVersion(),
        throwIfDiagnostics: false,
      );

      return ParsedFile(source: file, unit: result.unit, content: content);
    } catch (_) {
      return null;
    }
  }

  /// Parses a list of files in parallel. Returns only successfully parsed
  /// files; failures are silently dropped.
  Future<List<ParsedFile>> parseAll(List<File> files) async {
    final results = await Future.wait(files.map(parse));
    return results.whereType<ParsedFile>().toList();
  }
}
