import 'package:sip_cli/src/domain/resolved_script.dart';

sealed class Runnable {
  const Runnable();
}

class ConcurrentBreak implements Runnable {
  const ConcurrentBreak();
}

class ScriptToRun implements Runnable {
  ScriptToRun(
    this.exe, {
    this.label,
    this.workingDirectory,
    bool? bail,
    this.scripts,
    Map<String, String>? variables,
    this.runInParallel,
    this.data,
  }) : _bail = bail,
       variables = variables ?? {};

  final bool? _bail;
  bool get bail => _bail ?? scripts?.any((e) => e.bail) ?? false;

  final String exe;
  final Map<String, String> variables;
  final Set<ResolvedScript>? scripts;
  final String? workingDirectory;
  final bool? runInParallel;
  final Object? data;

  final String? label;

  @override
  String toString() {
    return exe;
  }
}
