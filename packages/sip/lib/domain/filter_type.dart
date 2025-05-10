import 'dart:io';

import 'package:mason_logger/mason_logger.dart';
import 'package:path/path.dart' as p;

typedef FormattedTest = ({
  String message,
  ({int passing, int failing, int skipped}) count,
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
  final passing = RegExp(r'\+(\d+)').firstMatch(m)?.group(1);
  final failing = RegExp(r'-(\d+)').firstMatch(m)?.group(1);
  final skipped = RegExp(r'~(\d+)').firstMatch(m)?.group(1);

  var description = RegExp(r'[\+\-\~]\d+:(.*)')
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
    if (passing case final passing?) green.wrap('+$passing'),
    if (failing case final failing?) red.wrap('-$failing'),
    if (skipped case final skipped?) yellow.wrap('~$skipped'),
  ].join(' ');
  testOverview = '$testOverview:';

  final totalLength =
      testOverview.length + (relative?.length ?? 0) + ' |'.length;

  if (isFinished) {
    description = 'Tests completed';
  } else if (isLoading) {
    description = 'loading tests...';
  }

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
      switch ((hasError, isFinished)) {
        (true, _) => red.wrap(fullDescription),
        (_, true) => green.wrap(description),
        _ => darkGray.wrap(description),
      },
  ].join(' ').trim();

  final message = [
    resetToStart,
    coreMessage,
    clearToEnd,
    if (hasError) '\n',
  ].join();

  final passingCount = int.tryParse(passing ?? '') ?? 0;
  final failingCount = int.tryParse(failing ?? '') ?? 0;
  final skippedCount = int.tryParse(skipped ?? '') ?? 0;

  return (
    message: message,
    count: (
      passing: passingCount,
      failing: failingCount,
      skipped: skippedCount
    ),
    isError: hasError
  );
}

FormattedTest _formatDartTest(String string) {
  final m = resetAll.wrap(string) ?? '';
  final time = RegExp(r'\d+:\d+').firstMatch(m)?.group(0);
  final passing = RegExp(r'\+(\d+)').firstMatch(m)?.group(1);
  final failing = RegExp(r'-(\d+)').firstMatch(m)?.group(1);
  final skipped = RegExp(r'~(\d+)').firstMatch(m)?.group(1);

  var description =
      RegExp(r'[\-\+\~]\d+.*\.dart:?(.*)').firstMatch(m)?.group(1)?.trim();

  final isLoading = RegExp(r': loading .*\.dart').hasMatch(m);
  final isFinished = m.contains('All tests passed');
  final hasError = m.contains('[E]');

  final path = switch (hasError) {
    true => RegExp(r'(\S*\.dart)').firstMatch(m)?.group(1)?.trim(),
    _ => null,
  };

  var testOverview = [
    if (time case final time?) time,
    if (passing case final passing?) green.wrap('+$passing'),
    if (failing case final failing?) red.wrap('-$failing'),
    if (skipped case final skipped?) yellow.wrap('~$skipped'),
  ].join(' ');
  testOverview = '$testOverview:';

  final totalLength = testOverview.length + (path?.length ?? 0) + ' |'.length;

  if (isFinished) {
    description = 'Tests completed';
  } else if (isLoading) {
    description = 'loading tests...';
  }

  final descriptionLength = description?.length ?? 0;
  final fullDescription = description;
  if (totalLength + descriptionLength > maxCol) {
    description = description?.substring(0, maxCol - totalLength - 5);
  }

  description = description?.trim();

  final coreMessage = [
    testOverview,
    if (path case final path when hasError) darkGray.wrap('$path |'),
    if (description case final String description when description.isNotEmpty)
      switch ((hasError, isFinished)) {
        (true, _) => red.wrap(fullDescription),
        (_, true) => green.wrap(description),
        _ => darkGray.wrap(description),
      },
  ].whereType<String>().join(' ').trim();

  final message = [
    resetToStart,
    coreMessage,
    clearToEnd,
    if (hasError) '\n',
  ].join();

  final passingCount = int.tryParse(passing ?? '') ?? 0;
  final failingCount = int.tryParse(failing ?? '') ?? 0;
  final skippedCount = int.tryParse(skipped ?? '') ?? 0;

  return (
    message: message,
    count: (
      passing: passingCount,
      failing: failingCount,
      skipped: skippedCount
    ),
    isError: hasError
  );
}
