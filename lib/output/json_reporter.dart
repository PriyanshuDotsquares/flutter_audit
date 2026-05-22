import 'dart:convert';

import '../models/report.dart';

/// Serializes a [Report] to JSON for CI/CD pipelines and machine consumption.
class JsonReporter {
  String render(Report report) {
    const encoder = JsonEncoder.withIndent('  ');
    return encoder.convert(report.toJson());
  }
}
