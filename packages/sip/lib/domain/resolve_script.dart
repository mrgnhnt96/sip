import 'package:sip_cli/domain/env_config.dart';
import 'package:sip_cli/domain/script.dart';

class ResolveScript {
  ResolveScript({
    required this.resolvedScripts,
    required this.envConfig,
    required this.script,
    required this.needsRunBeforeNext,
  }) : originalCommand = null;

  ResolveScript._({
    required this.resolvedScripts,
    required this.envConfig,
    required this.script,
    required this.originalCommand,
    required this.needsRunBeforeNext,
    required String? replacedCommand,
  }) : _replacedCommand = replacedCommand;

  ResolveScript.command({
    required String command,
    required this.envConfig,
    required this.script,
    required this.needsRunBeforeNext,
  })  : resolvedScripts = const [],
        originalCommand = command;

  final Script script;
  final String? originalCommand;
  final Iterable<ResolveScript> resolvedScripts;
  final EnvConfig? envConfig;
  final bool needsRunBeforeNext;

  String? _replacedCommand;

  void replaceCommandPart(String part, String replacement) {
    _replacedCommand ??= command;
    _replacedCommand = _replacedCommand?.replaceAll(part, replacement);
  }

  ResolveScript copy({
    EnvConfig? envConfig,
    bool? needsRunBeforeNext,
  }) {
    return ResolveScript._(
      resolvedScripts: resolvedScripts,
      envConfig: envConfig ?? this.envConfig,
      script: script,
      originalCommand: originalCommand,
      replacedCommand: _replacedCommand,
      needsRunBeforeNext: needsRunBeforeNext ?? this.needsRunBeforeNext,
    );
  }

  Iterable<ResolveScript> get flatten => {
        if (command != null)
          this
        else if (resolvedScripts.isNotEmpty)
          ...resolvedScripts.expand((e) => e.flatten),
      };

  String? get command => _replacedCommand ?? originalCommand;
}
