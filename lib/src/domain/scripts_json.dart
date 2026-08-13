import 'package:sip_cli/src/domain/args.dart';
import 'package:sip_cli/src/domain/script.dart';
import 'package:sip_cli/src/domain/script_locations.dart';
import 'package:sip_cli/src/domain/script_to_run.dart';
import 'package:sip_cli/src/domain/scripts_config.dart';

/// The version of the `--json` payload shape.
///
/// Bumped only when a consumer would have to change to keep reading it, so a
/// tool can check one number instead of probing for fields.
const scriptsJsonVersion = 1;

/// Turns [config] into the payload behind `sip list --json`.
///
/// The scripts come back as a flat list rather than a tree: the question a
/// reader almost always has is "what can I run, and what does it actually
/// do", and a flat list answers it without walking anything. Nesting is still
/// recoverable from `path` and `parent`.
///
/// When [resolve] is set, each runnable script also carries the fully
/// expanded commands -- references, variables and flags substituted -- which
/// is the difference between reading `scripts.yaml` and knowing what will
/// run. Resolution is best-effort: a script that cannot resolve reports the
/// reason in `resolveError` instead of failing the whole listing.
Map<String, Object?> scriptsConfigToJson(
  ScriptsConfig config, {
  required ScriptLocations locations,
  Map<String, String?> executables = const {},
  Map<String, String?> variables = const {},
  bool resolve = true,
  Args flags = const Args(),
  Iterable<Script>? only,
}) {
  // Identity, not `==`: Script's equality compares its command list by
  // reference, so two distinct scripts with no commands compare equal.
  final wanted = switch (only) {
    null => null,
    final only => Set<Script>.identity()..addAll(only),
  };

  final scripts = <Map<String, Object?>>[];

  void visit(Script script, List<String> path) {
    if (wanted == null || wanted.contains(script)) {
      scripts.add(
        scriptToJson(
          script,
          path: path,
          locations: locations,
          resolve: resolve,
          config: config,
          flags: flags,
        ),
      );
    }

    for (final child in script.scripts?.values ?? const <Script>[]) {
      visit(child, [...path, child.name]);
    }
  }

  for (final script in config.scripts.values) {
    visit(script, [script.name]);
  }

  return {
    'version': scriptsJsonVersion,
    'scriptsYaml': locations.file.isEmpty ? null : locations.file,
    'executables': {
      for (final MapEntry(:key, :value) in executables.entries)
        if (value != null) key: value,
    },
    'variables': {
      for (final MapEntry(:key, :value) in variables.entries)
        if (value != null) key: value,
    },
    'scripts': scripts,
  };
}

/// Turns a single [script] into its entry in the `--json` payload.
Map<String, Object?> scriptToJson(
  Script script, {
  required List<String> path,
  required ScriptLocations locations,
  required bool resolve,
  ScriptsConfig? config,
  Args flags = const Args(),
}) {
  final runnable = script.commands.isNotEmpty;

  List<Map<String, Object?>>? resolved;
  String? resolveError;

  if (resolve && runnable) {
    try {
      final (result, _) = script.resolve(flags: flags, scriptsConfig: config);

      if (result == null) {
        resolveError = 'Could not resolve the commands for this script.';
      } else {
        resolved = [
          for (final command in result.commands)
            if (command case final ScriptToRun run)
              {
                'command': run.exe,
                'concurrent': run.runInParallel ?? false,
                if (run.label case final label?) 'label': label,
              },
        ];
      }
    } on Exception catch (e) {
      resolveError = '$e';
    }
  }

  return {
    'path': path,
    'key': path.join('.'),
    'name': script.name,
    'parent': switch (path.length) {
      > 1 => path.sublist(0, path.length - 1).join('.'),
      _ => null,
    },
    'aliases': script.aliases.toList(),
    'description': script.description,
    'private': script.isPrivate,
    'runnable': runnable,
    'bail': script.bail,
    'commands': script.commands,
    if (resolve) 'resolved': resolved,
    if (resolve) 'resolveError': resolveError,
    'env': switch (script.env) {
      null => null,
      final env => {
        'files': env.files,
        'commands': env.commands,
        'vars': env.vars,
      },
    },
    'location': locations.nearest(path)?.toJson(),
  };
}
