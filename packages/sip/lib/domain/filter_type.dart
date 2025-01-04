import 'dart:io';

import 'package:mason_logger/mason_logger.dart';
import 'package:path/path.dart' as p;

enum FilterType {
  flutterTest,
  dartTest;

  bool Function(String)? get filter => _getFilter(this);
  String Function(String)? get formatter => _getFormatter(this);

  static FilterType? fromString(String? value) {
    return FilterType.values.asNameMap()[value];
  }
}

bool Function(String)? _getFilter(FilterType? type) {
  return switch (type) {
    FilterType.flutterTest => RegExp(r'\d+:\d+').hasMatch,
    FilterType.dartTest => RegExp(r'\d+:\d+').hasMatch,
    null => null,
  };
}

String Function(String)? _getFormatter(FilterType? type) {
  return switch (type) {
    FilterType.flutterTest => _formatFlutterTest,
    FilterType.dartTest => _formatDartTest,
    null => null,
  };
}

String _formatFlutterTest(String string) {
  final m = resetAll.wrap(string) ?? '';
  final time = RegExp(r'\d+:\d+').firstMatch(m)?.group(0);
  final passing = RegExp(r'\+\d+').firstMatch(m)?.group(0);
  final failing = RegExp(r'-\d+').firstMatch(m)?.group(0);
  var description = RegExp(r'[\+\-]\d+:(.*)')
      .firstMatch(m)
      ?.group(1)
      ?.replaceAll(' ...', '')
      .replaceFirst(RegExp(': '), '');

  final path = RegExp(r'([\/\\].*\.dart):?')
      .firstMatch(description ?? '')
      ?.group(1)
      ?.trim();

  if (path case final path? when description != null) {
    description = description.replaceAll(path, '');
  }

  description = description?.trim();

  final relative = switch (path) {
    String() => p.relative(path, from: p.current),
    _ => null,
  };

  final hasError = m.contains('[E]');
  const resetToStart = '\x1B[0G';
  const clearToEnd = '\x1B[K';
  final maxCol = stdout.terminalColumns;

  var testOverview = [
    if (time case final time?) time,
    if (passing case final passing?) green.wrap(passing),
    if (failing case final failing?) red.wrap(failing),
  ].join(' ');
  testOverview = '$testOverview:';

  final totalLength =
      testOverview.length + (relative?.length ?? 0) + ' |'.length;

  final descriptionLength = description?.length ?? 0;
  final fullDescription = description;
  if (totalLength + descriptionLength > maxCol) {
    description = description?.substring(0, maxCol - totalLength - 5);
  }

  final coreMessage = [
    testOverview,
    if (relative case final relative? when hasError)
      darkGray.wrap('$relative |'),
    if (description?.trim() case final String description)
      switch (hasError) {
        true => red.wrap(fullDescription),
        _ => darkGray.wrap(description),
      },
  ].join(' ').trim();

  final message = [
    resetToStart,
    coreMessage,
    clearToEnd,
    if (hasError) '\n',
  ].join();

  return message;
}

String _formatDartTest(String string) {
  final m = resetAll.wrap(string) ?? '';
  final time = RegExp(r'\d+:\d+').firstMatch(m)?.group(0);
  final passing = RegExp(r'\+\d+').firstMatch(m)?.group(0);
  final failing = RegExp(r'-\d+').firstMatch(m)?.group(0);
  var description = RegExp(r'[\-\+]\d+.*:(.*)').firstMatch(m)?.group(1);

  final path =
      RegExp(r'(\S*\.dart)').firstMatch(description ?? '')?.group(1)?.trim();

  if (path case final path? when description != null) {
    description = description.replaceAll(path, '');
  }

  description = description?.trim();

  final hasError = m.contains('[E]');
  const resetToStart = '\x1B[0G';
  const clearToEnd = '\x1B[K';
  final maxCol = stdout.terminalColumns;

  var testOverview = [
    if (time case final time?) time,
    if (passing case final passing?) green.wrap(passing),
    if (failing case final failing?) red.wrap(failing),
  ].join(' ');
  testOverview = '$testOverview:';

  final totalLength = testOverview.length + (path?.length ?? 0) + ' |'.length;

  final descriptionLength = description?.length ?? 0;
  final fullDescription = description;
  if (totalLength + descriptionLength > maxCol) {
    description = description?.substring(0, maxCol - totalLength - 5);
  }

  final coreMessage = [
    testOverview,
    if (path case final path when hasError) darkGray.wrap('$path |'),
    if (description?.trim() case final String description)
      switch (hasError) {
        true => red.wrap(fullDescription),
        _ => darkGray.wrap(description),
      },
  ].whereType<String>().join(' ').trim();

  final message = [
    resetToStart,
    coreMessage,
    clearToEnd,
    if (hasError) '\n',
  ].join();

  return message;
}
