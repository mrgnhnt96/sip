import 'package:sip_cli/src/domain/env_config.dart';
import 'package:sip_cli/src/domain/script.dart';
import 'package:sip_cli/src/domain/script_env.dart';
import 'package:sip_cli/src/domain/script_to_run.dart';
import 'package:sip_cli/src/utils/constants.dart';

class ResolvedScript {
  ResolvedScript(
    this.script, {
    this.parent,
    Map<String, String>? flags,
    List<ResolvedScriptPart>? parts,
  }) : _scriptsUsed = {script},
       parts = parts ?? [],
       _flags = flags ?? {} {
    for (final command in script.commands) {
      this.parts.add(ResolvedScriptPart(command, script: this));
    }
  }

  final Script script;
  final ResolvedScript? parent;

  bool get bail => allScriptsUsed.any((e) => e.bail);

  EnvConfig? get envConfig {
    final configs = <ScriptEnv>[
      ?script.env,
      for (final script in _scriptsUsed) ?script.env,
    ];

    final variables = {
      for (final env in configs)
        for (final MapEntry(:key, :value) in env.vars.entries)
          key.trim(): value.trim(),
    };

    final files = {
      for (final env in configs)
        for (final file in env.files) file.trim(),
    };

    final commands = {
      for (final env in configs)
        for (final command in env.commands)
          command.replaceAll(Identifiers.concurrent, '').trim(),
    };

    if (commands.isEmpty && files.isEmpty && variables.isEmpty) {
      return null;
    }

    return EnvConfig(
      commands: commands.toList(),
      files: files.toList(),
      variables: variables,
    );
  }

  final Set<Script> _scriptsUsed;
  void addScriptUsed(Script script) {
    _scriptsUsed.add(script);
  }

  Set<Script> get scriptsUsed => Set.unmodifiable(_scriptsUsed);

  Set<Script> get allScriptsUsed {
    Iterable<Script> retrieve(ResolvedScript script) sync* {
      yield* script._scriptsUsed;

      for (final part in script.parts) {
        for (final resolved in part.replacees.values) {
          yield* retrieve(resolved);
        }
      }
    }

    return retrieve(this).toSet();
  }

  final Map<String, String> _flags;
  void addFlag(String flag, String value) {
    _flags[flag] = value;
  }

  Map<String, String> get flags {
    final flags = <String, String>{};

    void retrieve(ResolvedScript script) {
      flags.addAll(script._flags);

      for (final part in script.parts) {
        for (final resolved in part.replacees.values) {
          retrieve(resolved);
        }
      }
    }

    retrieve(this);

    return flags;
  }

  final List<ResolvedScriptPart> parts;

  List<ResolvedScriptPart> get allParts {
    final parts = <ResolvedScriptPart>[];

    void retrieve(ResolvedScript script) {
      for (final part in script.parts) {
        parts.add(part);
        for (final replacee in part.replacees.values) {
          retrieve(replacee);
        }
      }
    }

    retrieve(this);

    return parts;
  }

  List<Runnable> get commands {
    Iterable<Runnable> retrieve(ResolvedScript script) sync* {
      for (final part in script.parts) {
        yield* part.commands;
      }
    }

    return retrieve(this).toList();
  }

  @override
  String toString() {
    return parts.join(' | ');
  }
}

class ResolvedScriptPart {
  ResolvedScriptPart(
    String part, {
    required this.script,
    bool isConcurrent = false,
  }) : originalPart = part,
       isConcurrent = switch (isConcurrent) {
         true => true,
         false => part.startsWith(Identifiers.concurrent),
       },
       part = part.replaceAll(Identifiers.concurrent, '').trim(),
       replacees = {};

  final ResolvedScript script;
  final String originalPart;
  bool isConcurrent;
  String part;
  Map<String, ResolvedScript> replacees;

  List<Runnable> get commands {
    final replacees = {...this.replacees};

    var parts = <Runnable>[
      ScriptToRun(
        part.trim(),
        scripts: {script},
        label: script.script.keys.join(' '),
        variables: script.envConfig?.variables,
        runInParallel: isConcurrent,
      ),
    ];

    while (replacees.isNotEmpty) {
      final partToReplace = replacees.keys.first;
      final replaceeScript = replacees.remove(partToReplace);
      if (replaceeScript == null) continue;

      final replaceeCommands = replaceeScript.commands;

      parts = List.generate(parts.length * replaceeCommands.length, (index) {
        final commandIndex = index % replaceeCommands.length;
        ScriptToRun replacee;

        switch (replaceeCommands.elementAt(commandIndex)) {
          case ConcurrentBreak():
            return const ConcurrentBreak();
          case final ScriptToRun script:
            replacee = script;
        }

        final partIndex = index ~/ replaceeCommands.length;
        ScriptToRun part;
        switch (parts.elementAt(partIndex)) {
          case ConcurrentBreak():
            return const ConcurrentBreak();
          case final ScriptToRun script:
            part = script;
        }

        return ScriptToRun(
          part.exe.replaceAll(partToReplace, replacee.exe).trim(),
          scripts: {script, replaceeScript},
          label: replacee.label ?? replaceeScript.script.keys.join(' '),
          variables: {...part.variables, ...replacee.variables},
          runInParallel: replacee.runInParallel,
        );
      }).toList();

      if (parts case [..., ScriptToRun(runInParallel: true)]) {
        parts.add(const ConcurrentBreak());
      }
    }

    return [
      for (final part in parts)
        if (part case ScriptToRun(:final exe) when exe.isNotEmpty)
          part
        else if (part case final ConcurrentBreak part)
          part,
    ];
  }

  @override
  String toString() {
    return part;
  }
}
