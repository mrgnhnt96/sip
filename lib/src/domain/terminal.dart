import 'dart:io' as io;

/// The terminal sip is attached to, if any.
///
/// Wrapped in a class so tests (and the MCP server, which is never attached
/// to one) can substitute an answer instead of inheriting the test runner's.
class Terminal {
  const Terminal();

  /// Whether stdout is connected to a terminal.
  ///
  /// False when sip's output is piped, redirected to a file, or captured by
  /// another program.
  bool get hasTerminal => io.stdout.hasTerminal;
}

/// A [Terminal] that always reports the value it was given.
class FakeTerminal implements Terminal {
  const FakeTerminal({required this.hasTerminal});

  @override
  final bool hasTerminal;
}
