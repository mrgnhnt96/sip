import 'package:sip_cli/src/domain/script_locations.dart';

/// How much a [Diagnostic] matters.
enum Severity {
  /// `scripts.yaml` is wrong, and running it will not do what it says.
  error,

  /// `scripts.yaml` works, but not the way it looks like it does.
  warning;

  String get name => switch (this) {
    Severity.error => 'error',
    Severity.warning => 'warning',
  };
}

/// One problem found in `scripts.yaml`.
class Diagnostic {
  const Diagnostic({
    required this.severity,
    required this.code,
    required this.message,
    this.location,
    this.script,
    this.help,
  });

  const Diagnostic.error({
    required String code,
    required String message,
    ScriptLocation? location,
    String? script,
    String? help,
  }) : this(
         severity: Severity.error,
         code: code,
         message: message,
         location: location,
         script: script,
         help: help,
       );

  const Diagnostic.warning({
    required String code,
    required String message,
    ScriptLocation? location,
    String? script,
    String? help,
  }) : this(
         severity: Severity.warning,
         code: code,
         message: message,
         location: location,
         script: script,
         help: help,
       );

  final Severity severity;

  /// A stable identifier for this kind of problem, such as
  /// `unknown-reference`. Meant to be matched on; the message is not.
  final String code;

  final String message;
  final ScriptLocation? location;

  /// The dotted key of the script the problem is in, when there is one.
  final String? script;

  /// What to do about it.
  final String? help;

  Map<String, Object?> toJson() => {
    'severity': severity.name,
    'code': code,
    'message': message,
    'script': script,
    'help': help,
    'location': location?.toJson(),
  };

  /// The compiler-style one-liner: `file:line:column: severity: message`.
  String format() {
    final buffer = StringBuffer();

    if (location case final location?) {
      buffer.write('${location.file}:${location.line}:${location.column}: ');
    }

    buffer.write('${severity.name}: $message');

    return buffer.toString();
  }
}

/// Everything [Diagnostic] found in one pass over `scripts.yaml`.
class ValidationResult {
  const ValidationResult(this.diagnostics);

  final List<Diagnostic> diagnostics;

  Iterable<Diagnostic> get errors =>
      diagnostics.where((e) => e.severity == Severity.error);

  Iterable<Diagnostic> get warnings =>
      diagnostics.where((e) => e.severity == Severity.warning);

  bool get hasErrors => errors.isNotEmpty;
  bool get hasWarnings => warnings.isNotEmpty;
  bool get isClean => diagnostics.isEmpty;
}
