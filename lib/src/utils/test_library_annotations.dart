/// The test-runner annotations on a test file's `library` directive, such as
/// `@Tags(['slow'])` or `@TestOn('vm')`, as arguments to a `group` call.
///
/// `package:test` only reads these from the library of the file it runs. Once
/// a file runs inside a generated bucket wrapper (see `Package.bucketPlan`),
/// the wrapper is that library, so the wrapper passes them to the file's
/// `group` instead.
///
/// Like `package:test`, which only accepts literals here, this reads the
/// source rather than resolving it: an annotation's arguments are copied
/// verbatim, minus any import prefix, comments and line breaks.
final class TestLibraryAnnotations {
  const TestLibraryAnnotations._(this.arguments);

  /// Reads the annotations on the `library` directive in [content].
  ///
  /// Annotations on anything else, or in a file without a `library`
  /// directive, are not library annotations and are ignored, as
  /// `package:test` ignores them.
  factory TestLibraryAnnotations.parse(String content) {
    final scanner = _Scanner(content)..skipHeader();
    final annotations = <(List<String>, String?)>[];

    while (true) {
      scanner.skipTrivia();

      if (scanner.atLibraryKeyword) break;
      if (!scanner.skip('@')) return none;

      final name = scanner.readName();
      if (name.isEmpty) return none;

      scanner.skipTrivia();
      final arguments = scanner.peek('(') ? scanner.readParenthesized() : null;
      annotations.add((name, arguments));
    }

    final result = <String, String>{};
    for (final (name, arguments) in annotations) {
      if (_argument(name, arguments) case (final key, final value)) {
        result[key] = value;
      }
    }

    return TestLibraryAnnotations._(result);
  }

  static const none = TestLibraryAnnotations._({});

  /// The named arguments to pass `group`, keyed by parameter name.
  final Map<String, String> arguments;

  bool get isEmpty => arguments.isEmpty;

  /// The [arguments] as source, each preceded by `, `.
  String get source =>
      arguments.entries.map((e) => ', ${e.key}: ${e.value}').join();

  /// The `group` argument for the annotation [name] (its identifiers,
  /// prefix included) called with the source [arguments], or `null` for an
  /// annotation that `group` has no argument for.
  static (String, String)? _argument(List<String> name, String? arguments) {
    final index = name.indexWhere(_parameters.containsKey);
    if (index == -1) return null;

    final type = name[index];
    final prefix = name.take(index).join('.');
    final constructor = name.skip(index + 1).join('.');
    final value = arguments == null ? null : _clean(arguments, prefix);

    return (
      _parameters[type]!,
      switch (type) {
        'Skip' when value == null || value.isEmpty => 'true',
        'Timeout' when constructor.isEmpty => 'Timeout($value)',
        'Timeout' when value == null => 'Timeout.$constructor',
        'Timeout' => 'Timeout.$constructor($value)',
        _ => value ?? '',
      },
    );
  }

  /// The `group` parameter each `package:test` annotation maps to.
  static const _parameters = {
    'Tags': 'tags',
    'TestOn': 'testOn',
    'Skip': 'skip',
    'Timeout': 'timeout',
    'OnPlatform': 'onPlatform',
    'Retry': 'retry',
  };

  /// [arguments] on one line, without comments, a trailing comma, or the
  /// import [prefix] the original file referred to `package:test` with.
  static String _clean(String arguments, String prefix) {
    final prefixRegex = prefix.isEmpty
        ? null
        : RegExp('(?<![\\w\$.])${RegExp.escape(prefix)}\\s*\\.\\s*');

    final buffer = StringBuffer();
    for (final (segment, isCode) in _Scanner(arguments).segments()) {
      if (!isCode) {
        buffer.write(segment);
        continue;
      }

      var code = segment.replaceAll(RegExp(r'\s+'), ' ');
      if (prefixRegex != null) code = code.replaceAll(prefixRegex, '');
      buffer.write(code);
    }

    final cleaned = buffer.toString().trim();
    return cleaned.endsWith(',')
        ? cleaned.substring(0, cleaned.length - 1).trim()
        : cleaned;
  }
}

/// A minimal Dart lexer: just enough to step over comments, strings and
/// balanced parentheses.
class _Scanner {
  _Scanner(this.content);

  final String content;
  var _index = 0;

  bool get _done => _index >= content.length;

  bool peek(String text) => content.startsWith(text, _index);

  bool skip(String text) {
    if (!peek(text)) return false;
    _index += text.length;
    return true;
  }

  /// Skips a byte order mark and a `#!` script tag.
  void skipHeader() {
    skip('﻿');
    if (peek('#!')) _skipLine();
  }

  void _skipLine() {
    final end = content.indexOf('\n', _index);
    _index = end == -1 ? content.length : end + 1;
  }

  /// Skips whitespace and comments.
  void skipTrivia() {
    while (!_done) {
      if (_whitespace.hasMatch(content[_index])) {
        _index++;
      } else if (peek('//')) {
        _skipLine();
      } else if (peek('/*')) {
        _skipBlockComment();
      } else {
        return;
      }
    }
  }

  void _skipBlockComment() {
    var depth = 0;
    while (!_done) {
      if (skip('/*')) {
        depth++;
      } else if (skip('*/')) {
        if (--depth == 0) return;
      } else {
        _index++;
      }
    }
  }

  bool get atLibraryKeyword =>
      peek('library') &&
      !_identifierPart.hasMatch(
        content.length > _index + 7 ? content[_index + 7] : ' ',
      );

  /// Reads a dotted name such as `Tags` or `test.Timeout.factor`.
  List<String> readName() {
    final parts = <String>[];
    while (true) {
      final match = _identifier.matchAsPrefix(content, _index);
      if (match == null) return parts;

      parts.add(match[0]!);
      _index = match.end;

      final dot = _dot.matchAsPrefix(content, _index);
      if (dot == null) return parts;
      _index = dot.end;
    }
  }

  /// Reads a parenthesized argument list starting at `(`, and returns what is
  /// between the parentheses.
  String readParenthesized() {
    final start = ++_index;
    var depth = 1;
    while (!_done) {
      if (_skipCommentOrString()) continue;

      final char = content[_index++];
      if (char == '(') depth++;
      if (char == ')' && --depth == 0) {
        return content.substring(start, _index - 1);
      }
    }

    return content.substring(start);
  }

  /// Splits [content] into string literals (`false`) and the code between
  /// them (`true`), with each comment replaced by a space.
  Iterable<(String, bool)> segments() sync* {
    final code = StringBuffer();
    var codeStart = _index;
    while (!_done) {
      final start = _index;
      if (!_skipCommentOrString()) {
        _index++;
        continue;
      }

      code.write(content.substring(codeStart, start));
      codeStart = _index;

      final skipped = content.substring(start, _index);
      if (skipped.startsWith('/')) {
        code.write(' ');
        continue;
      }

      yield (code.toString(), true);
      code.clear();
      yield (skipped, false);
    }

    yield ('$code${content.substring(codeStart)}', true);
  }

  /// Steps over a comment or string literal at the current position, if
  /// there is one.
  bool _skipCommentOrString() {
    if (peek('//')) {
      _skipLine();
      return true;
    }

    if (peek('/*')) {
      _skipBlockComment();
      return true;
    }

    final match = _stringStart.matchAsPrefix(content, _index);
    if (match == null) return false;

    final raw = match[1] != null;
    final quote = match[2]!;
    _index = match.end;

    while (!_done) {
      if (!raw && peek(r'\')) {
        _index += 2;
      } else if (skip(quote)) {
        return true;
      } else {
        _index++;
      }
    }

    return true;
  }

  static final _whitespace = RegExp(r'\s');
  static final _identifierPart = RegExp(r'[\w$]');
  static final _identifier = RegExp(r'[A-Za-z_$][\w$]*');
  static final _dot = RegExp(r'\s*\.\s*');
  static final _stringStart = RegExp(r"""((?<![\w$])r)?('{3}|"{3}|'|")""");
}
