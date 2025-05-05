import 'dart:io';

import 'package:mason_logger/mason_logger.dart';
import 'package:path/path.dart' as p;

typedef FormattedTest = ({
  String message,
  ({int passing, int failing}) count,
  bool isError
});
typedef Formatter = FormattedTest Function(String);

enum FilterType {
  flutterTest,
  dartTest;

  bool Function(String)? get filter => _getFilter(this);
  Formatter? get formatter => _getFormatter(this);

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

Formatter? _getFormatter(FilterType? type) {
  return switch (type) {
    FilterType.flutterTest => _formatFlutterTest,
    FilterType.dartTest => _formatDartTest,
    null => null,
  };
}

final resetToStart = switch (stdout.hasTerminal) {
  true => '\x1B[0G',
  false => '',
};
final clearToEnd = switch (stdout.hasTerminal) {
  true => '\x1B[K',
  false => '',
};
final maxCol = switch (stdout.hasTerminal) {
  true => stdout.terminalColumns,
  false => 1000,
};

FormattedTest _formatFlutterTest(String string) {
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

  final isLoading = RegExp(r': loading .*\.dart').hasMatch(m);
  final isFinished = m.contains('All tests passed');
  final hasError = m.contains('[E]');

  if (path case final path? when description != null) {
    description = description.replaceAll(path, '');
  }

  description = description?.trim();

  final relative = switch (path) {
    String() => p.relative(path, from: p.current),
    _ => null,
  };

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
    if (description?.trim() case final String description
        when description.isNotEmpty)
      switch (hasError) {
        true => red.wrap(fullDescription),
        _ => darkGray.wrap(description),
      },
    if (isLoading) darkGray.wrap('loading tests...'),
    if (isFinished) green.wrap('Ran all tests'),
  ].join(' ').trim();

  final message = [
    resetToStart,
    coreMessage,
    clearToEnd,
    if (hasError) '\n',
  ].join();

  final passingCount = int.tryParse(passing ?? '') ?? 0;
  final failingCount = int.tryParse(failing ?? '') ?? 0;

  return (
    message: message,
    count: (passing: passingCount, failing: failingCount),
    isError: hasError
  );
}

FormattedTest _formatDartTest(String string) {
  final m = resetAll.wrap(string) ?? '';
  final time = RegExp(r'\d+:\d+').firstMatch(m)?.group(0);
  final passing = RegExp(r'\+\d+').firstMatch(m)?.group(0);
  final failing = RegExp(r'-\d+').firstMatch(m)?.group(0);
  var description =
      RegExp(r'[\-\+]\d+.*\.dart:?(.*)').firstMatch(m)?.group(1)?.trim();

  final isLoading = RegExp(r': loading .*\.dart').hasMatch(m);
  final isFinished = m.contains('All tests passed');
  final hasError = m.contains('[E]');

  final path = switch (hasError) {
    true => RegExp(r'(\S*\.dart)').firstMatch(m)?.group(1)?.trim(),
    _ => null,
  };

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
    if (description?.trim() case final String description
        when description.isNotEmpty)
      switch (hasError) {
        true => red.wrap(fullDescription),
        _ => darkGray.wrap(description),
      },
    if (isLoading) darkGray.wrap('loading tests...'),
    if (isFinished) green.wrap('Ran all tests'),
  ].whereType<String>().join(' ').trim();

  final message = [
    resetToStart,
    coreMessage,
    clearToEnd,
    if (hasError) '\n',
  ].join();

  final passingCount = int.tryParse(passing ?? '') ?? 0;
  final failingCount = int.tryParse(failing ?? '') ?? 0;

  return (
    message: message,
    count: (passing: passingCount, failing: failingCount),
    isError: hasError
  );
}
