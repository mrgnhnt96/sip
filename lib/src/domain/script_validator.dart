import 'package:sip_cli/src/domain/diagnostic.dart';
import 'package:sip_cli/src/domain/script.dart';
import 'package:sip_cli/src/domain/script_locations.dart';
import 'package:sip_cli/src/domain/scripts_config.dart';
import 'package:sip_cli/src/domain/variables.dart';
import 'package:sip_cli/src/utils/constants.dart';
import 'package:yaml/yaml.dart';

/// Anything that looks like a sip substitution, however malformed.
///
/// [Variables.variablePattern] only matches substitutions sip can actually
/// resolve, so a malformed one -- `${{ a:b }}` being the common case -- does
/// not match it and is passed to the shell verbatim. Matching loosely first
/// is what makes it possible to say so instead of staying quiet.
final _looseSubstitution = RegExp(r'\$\{\{[^{}]*\}\}');

/// The keys sip gives meaning to inside a script.
const _reservedScriptKeys = Keys.scriptParameters;

/// The keys sip gives meaning to at the top level of the file.
const _reservedTopLevelKeys = Keys.nonScriptKeys;

final _allowedKey = RegExp(
  r'^_?([a-z][a-z0-9_.\-]*)?(?<=[a-z0-9_])$',
  caseSensitive: false,
);

/// Checks `scripts.yaml` for the mistakes that otherwise only show up as a
/// shell error, or as a script quietly doing the wrong thing.
///
/// [content] is the raw file, so problems can be reported against the line
/// they were written on. [config] is the same parsed model `sip run` uses, so
/// reference lookups here resolve exactly the way they will at run time --
/// aliases included.
ValidationResult validateScripts({
  required String content,
  required String file,
  required ScriptsConfig config,
  required Set<String> knownVariables,
}) {
  final diagnostics = <Diagnostic>[];
  final locations = ScriptLocations.parse(content, file: file);

  YamlNode root;
  try {
    root = loadYamlNode(content);
  } on YamlException catch (e) {
    return ValidationResult([
      Diagnostic.error(
        code: 'invalid-yaml',
        message: 'scripts.yaml is not valid YAML: ${e.message}',
        location: ScriptLocation(
          file: file,
          line: (e.span?.start.line ?? 0) + 1,
          column: (e.span?.start.column ?? 0) + 1,
        ),
      ),
    ]);
  }

  if (root is! YamlMap) {
    return ValidationResult([
      Diagnostic.error(
        code: 'invalid-yaml',
        message: 'scripts.yaml must be a map of script names to commands.',
        location: ScriptLocation(file: file, line: 1, column: 1),
      ),
    ]);
  }

  ScriptLocation? at(List<String> path) => locations.nearest(path);

  // ---------------------------------------------------------------------
  // Per-command checks: substitutions that will not resolve.
  // ---------------------------------------------------------------------

  void checkCommand(String command, List<String> path, String scriptKey) {
    for (final match in _looseSubstitution.allMatches(command)) {
      final raw = match.group(0)!;
      final strict = Variables.variablePattern.firstMatch(raw);

      if (strict == null) {
        diagnostics.add(
          Diagnostic.error(
            code: 'malformed-substitution',
            message:
                '$raw is not a valid substitution, so it is passed to '
                'the shell unchanged.',
            location: at(path),
            script: scriptKey,
            help: switch (raw.contains(':')) {
              true =>
                'Separate script names with dots: '
                    '${raw.replaceAll(':', '.')}',
              false => r'Use ${{ name }}, ${{ a.b }} or ${{ --flag }}.',
            },
          ),
        );
        continue;
      }

      final variable = strict.group(1)!;

      // A flag substitution is optional by design -- an unsupplied flag
      // expands to nothing -- so there is nothing to resolve.
      if (variable.startsWith('-')) continue;

      if (knownVariables.contains(variable)) continue;

      final parts = variable.split('.');
      if (parts case [final first, ...] when first.startsWith(r'$')) {
        parts[0] = first.substring(1);
      }

      final reference = config.find(parts);

      if (reference == null) {
        diagnostics.add(
          Diagnostic.error(
            code: 'unknown-reference',
            message:
                '$raw refers to "$variable", which is not a script or a '
                'variable.',
            location: at(path),
            script: scriptKey,
            help: 'Check the spelling, or declare it under (variables).',
          ),
        );
        continue;
      }

      if (reference.commands.isEmpty) {
        diagnostics.add(
          Diagnostic.error(
            code: 'reference-has-no-command',
            message:
                '$raw refers to "$variable", which has no (command) to '
                'substitute.',
            location: at(path),
            script: scriptKey,
            help:
                'Give "$variable" a (command), or reference one of its '
                'subscripts.',
          ),
        );
      }
    }
  }

  // ---------------------------------------------------------------------
  // Structural checks: walk the file the way sip reads it.
  // ---------------------------------------------------------------------

  void checkCommandNode(YamlNode node, List<String> path, String scriptKey) {
    switch (node) {
      case YamlScalar(value: final String command):
        checkCommand(command, path, scriptKey);
      case final YamlList list:
        for (final (index, item) in list.nodes.indexed) {
          checkCommandNode(item, [
            ...path,
            ScriptLocations.indexKey(index),
          ], scriptKey);
        }
      default:
        break;
    }
  }

  void checkScript(YamlNode node, List<String> path) {
    final scriptKey = path.join('.');

    switch (node) {
      case YamlScalar(value: final String _) || YamlList():
        checkCommandNode(node, path, scriptKey);
        return;
      case final YamlMap map:
        var hasCommand = false;
        var hasChild = false;

        for (final MapEntry(:key, :value) in map.nodes.entries) {
          if (key is! YamlScalar) continue;

          final name = '${key.value}';
          final childPath = [...path, name];

          if (name.startsWith('(') || name.endsWith(')')) {
            if (!_reservedScriptKeys.contains(name)) {
              diagnostics.add(
                Diagnostic.warning(
                  code: 'unknown-reserved-key',
                  message:
                      '"$name" looks like a reserved key but is not one, '
                      'so it is read as a subscript named "$name".',
                  location: at(childPath),
                  script: scriptKey,
                  help:
                      'Reserved keys are '
                      '${_reservedScriptKeys.join(', ')}.',
                ),
              );
            }

            switch (name) {
              case Keys.command:
                hasCommand = switch (value) {
                  YamlScalar(value: final String _) => true,
                  final YamlList list => list.isNotEmpty,
                  _ => false,
                };
                checkCommandNode(value, childPath, scriptKey);
              case Keys.bail:
                // An empty YAML value is null, which sip reads as false --
                // the opposite of what writing `(bail):` looks like it means.
                if (value case YamlScalar(value: null)) {
                  diagnostics.add(
                    Diagnostic.warning(
                      code: 'empty-bail',
                      message:
                          '(bail) has no value, which sip reads as '
                          'false.',
                      location: at(childPath),
                      script: scriptKey,
                      help: 'Write `(bail): true`.',
                    ),
                  );
                }
              case Keys.env:
                if (value case final YamlMap env) {
                  for (final MapEntry(key: envKey, value: envValue)
                      in env.nodes.entries) {
                    if (envKey is! YamlScalar) continue;

                    final envName = '${envKey.value}';
                    // Only `command`/`commands` hold shell to run; the rest
                    // of (env) is file paths and literal values.
                    if (envName case 'command' || 'commands') {
                      checkCommandNode(envValue, [
                        ...childPath,
                        envName,
                      ], scriptKey);
                    }
                  }
                }
            }

            continue;
          }

          hasChild = true;
          _checkKey(name, childPath, scriptKey, at, diagnostics);
          checkScript(value, childPath);
        }

        if (!hasCommand && !hasChild) {
          diagnostics.add(
            Diagnostic.warning(
              code: 'empty-script',
              message:
                  '"$scriptKey" has no (command) and no subscripts, so '
                  'there is nothing to run.',
              location: at(path),
              script: scriptKey,
            ),
          );
        }

        _checkDuplicateAliases(map, path, scriptKey, at, diagnostics);

      default:
        diagnostics.add(
          Diagnostic.error(
            code: 'invalid-script',
            message:
                '"$scriptKey" is not a command, a list of commands, or a '
                'map of subscripts.',
            location: at(path),
            script: scriptKey,
          ),
        );
    }
  }

  for (final MapEntry(:key, :value) in root.nodes.entries) {
    if (key is! YamlScalar) continue;

    final name = '${key.value}';
    if (_reservedTopLevelKeys.contains(name)) continue;

    if (name.startsWith('(') || name.endsWith(')')) {
      diagnostics.add(
        Diagnostic.warning(
          code: 'unknown-reserved-key',
          message:
              '"$name" looks like a reserved top-level key but is not '
              'one, so it is read as a script named "$name".',
          location: at([name]),
          help:
              'Top-level reserved keys are '
              '${_reservedTopLevelKeys.join(', ')}.',
        ),
      );
      continue;
    }

    _checkKey(name, [name], name, at, diagnostics);
    checkScript(value, [name]);
  }

  _checkDuplicateAliases(root, const [], null, at, diagnostics);
  diagnostics
    ..addAll(_findCycles(config, knownVariables, locations))
    // Report in file order, so reading the output top to bottom matches
    // reading scripts.yaml top to bottom.
    ..sort((a, b) {
      final lineA = a.location?.line ?? 0;
      final lineB = b.location?.line ?? 0;
      if (lineA != lineB) return lineA.compareTo(lineB);

      return (a.location?.column ?? 0).compareTo(b.location?.column ?? 0);
    });

  return ValidationResult(diagnostics);
}

void _checkKey(
  String name,
  List<String> path,
  String scriptKey,
  ScriptLocation? Function(List<String>) at,
  List<Diagnostic> diagnostics,
) {
  if (name.contains(' ')) {
    diagnostics.add(
      Diagnostic.error(
        code: 'invalid-key',
        message: 'The script name "$name" contains spaces, which sip rejects.',
        location: at(path),
        script: scriptKey,
      ),
    );
    return;
  }

  if (!_allowedKey.hasMatch(name)) {
    diagnostics.add(
      Diagnostic.error(
        code: 'invalid-key',
        message: 'The script name "$name" uses characters sip rejects.',
        location: at(path),
        script: scriptKey,
        help:
            'Names must match ${_allowedKey.pattern} (case insensitive): '
            'start with a letter or _, end with a letter, digit or _.',
      ),
    );
  }
}

void _checkDuplicateAliases(
  YamlMap map,
  List<String> path,
  String? scriptKey,
  ScriptLocation? Function(List<String>) at,
  List<Diagnostic> diagnostics,
) {
  final owners = <String, List<String>>{};

  for (final MapEntry(:key, :value) in map.nodes.entries) {
    if (key is! YamlScalar) continue;

    final name = '${key.value}';
    if (name.startsWith('(')) continue;
    if (value is! YamlMap) continue;

    final aliases = switch (value.nodes[Keys.aliases]) {
      YamlScalar(value: final String alias) => [alias],
      final YamlList list => [
        for (final item in list)
          if (item case final String alias) alias,
      ],
      _ => const <String>[],
    };

    for (final alias in aliases) {
      (owners[alias] ??= []).add(name);
    }
  }

  for (final MapEntry(key: alias, value: scripts) in owners.entries) {
    if (scripts.length < 2) continue;

    diagnostics.add(
      Diagnostic.warning(
        code: 'duplicate-alias',
        message:
            'The alias "$alias" is claimed by ${scripts.join(', ')}, so '
            'sip deactivates it and none of them can be run by it.',
        location: at(path.isEmpty ? [scripts.first] : path),
        script: scriptKey,
        help: 'Give each script a distinct alias.',
      ),
    );
  }
}

/// Finds reference cycles, which fail at run time with a stack of names and
/// no indication of where the loop was written.
Iterable<Diagnostic> _findCycles(
  ScriptsConfig config,
  Set<String> knownVariables,
  ScriptLocations locations,
) {
  // Identity throughout: Script's `==` compares its command list, so two
  // distinct scripts that both have no commands compare equal and would
  // collapse into one node -- inventing cycles that are not there.
  final edges = Map<Script, Set<Script>>.identity();
  final paths = Map<Script, List<String>>.identity();

  void collect(Script script, List<String> path) {
    paths[script] = path;

    final referenced = Set<Script>.identity();

    for (final command in script.commands) {
      for (final match in Variables.variablePattern.allMatches(command)) {
        final variable = match.group(1)!;
        if (variable.startsWith('-')) continue;
        if (knownVariables.contains(variable)) continue;

        final parts = variable.split('.');
        if (parts case [final first, ...] when first.startsWith(r'$')) {
          parts[0] = first.substring(1);
        }

        if (config.find(parts) case final reference?) {
          referenced.add(reference);
        }
      }
    }

    edges[script] = referenced;

    for (final child in script.scripts?.values ?? const <Script>[]) {
      collect(child, [...path, child.name]);
    }
  }

  for (final script in config.scripts.values) {
    collect(script, [script.name]);
  }

  final diagnostics = <Diagnostic>[];
  final reported = Set<Script>.identity();
  final visited = Set<Script>.identity();
  final stack = <Script>[];

  String nameOf(Script script) => (paths[script] ?? [script.name]).join('.');

  void visit(Script script) {
    final start = stack.indexWhere((e) => identical(e, script));

    if (start != -1) {
      final loop = [...stack.sublist(start), script];

      // One diagnostic per cycle, reported against the script it starts at.
      if (reported.add(script)) {
        diagnostics.add(
          Diagnostic.error(
            code: 'circular-reference',
            message: 'Circular reference: ${loop.map(nameOf).join(' -> ')}',
            location: locations.nearest(paths[script] ?? [script.name]),
            script: (paths[script] ?? [script.name]).join('.'),
            help: 'Break the loop by inlining one of the commands.',
          ),
        );
      }

      return;
    }

    if (!visited.add(script)) return;

    stack.add(script);
    for (final next in edges[script] ?? const <Script>{}) {
      visit(next);
    }
    stack.removeLast();
  }

  for (final script in edges.keys) {
    visit(script);
  }

  return diagnostics;
}
