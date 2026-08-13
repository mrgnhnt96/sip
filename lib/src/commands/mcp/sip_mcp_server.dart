import 'dart:async';
import 'dart:convert';

import 'package:dart_mcp/server.dart';
import 'package:sip_cli/src/deps/script_runner.dart';
import 'package:sip_cli/src/deps/scripts_yaml.dart';
import 'package:sip_cli/src/deps/variables.dart';
import 'package:sip_cli/src/domain/args.dart';
import 'package:sip_cli/src/domain/executables.dart';
import 'package:sip_cli/src/domain/script.dart';
import 'package:sip_cli/src/domain/script_to_run.dart';
import 'package:sip_cli/src/domain/script_validator.dart';
import 'package:sip_cli/src/domain/scripts_config.dart';
import 'package:sip_cli/src/domain/scripts_json.dart';
import 'package:sip_cli/src/domain/scripts_yaml.dart';
import 'package:sip_cli/src/utils/script_locations_loader.dart';
import 'package:sip_cli/src/version.dart';

const _instructions = '''
This project's scripts are declared in scripts.yaml and run with sip.

Call list_scripts first to see what exists and what each script actually
runs -- the resolved commands, not just what was written. Prefer running a
declared script over reconstructing its command yourself: the script is what
the project maintains, and it may set environment variables, change
directory or run steps concurrently.

Use dry_run to check what a script expands to before running it, and
validate after editing scripts.yaml.
''';

/// The sip MCP server.
///
/// A CLI convention is something a model has to remember to follow, and under
/// context pressure it often does not -- it reconstructs `dart test` and
/// bypasses whatever the project actually declared. A tool in the tool list
/// gets used because it is there.
///
/// Every tool is a thin wrapper over the same functions behind `sip list
/// --json`, `sip run --print --json`, `sip validate --json` and `sip run`, so
/// there is one behaviour and one place to change it.
base class SipMcpServer extends MCPServer with ToolsSupport {
  SipMcpServer(super.channel)
    : super.fromStreamChannel(
        implementation: Implementation(name: 'sip', version: packageVersion),
        instructions: _instructions,
      ) {
    registerTool(_listScriptsTool, _listScripts);
    registerTool(_dryRunTool, _dryRun);
    registerTool(_runScriptTool, _runScript);
    registerTool(_validateTool, _validate);
  }

  // -------------------------------------------------------------------
  // list_scripts
  // -------------------------------------------------------------------

  static final _listScriptsTool = Tool(
    name: 'list_scripts',
    description:
        "List every script in this project's scripts.yaml, with its dotted "
        'key, aliases, description, the raw commands as written and the fully '
        'resolved commands that will actually run. Call this before running '
        'anything, to find the script the project already declares for a '
        'task.',
    inputSchema: Schema.object(
      properties: {
        'query': Schema.string(
          description:
              'Only return scripts whose name, alias or description contains '
              'this text. Omit to return everything.',
        ),
        'resolve': Schema.bool(
          description:
              'Expand references, variables and executables into the commands '
              'that will run. Defaults to true.',
        ),
      },
    ),
  );

  FutureOr<CallToolResult> _listScripts(CallToolRequest request) {
    final config = ScriptsConfig.load();
    final query = request.arguments?['query'] as String?;
    final resolve = request.arguments?['resolve'] as bool? ?? true;

    Iterable<Script>? only;
    if (query != null && query.trim().isNotEmpty) {
      only = config.search(query.trim()).toList();

      if (only.isEmpty) {
        return _error(
          'No scripts match "$query". Call list_scripts with no '
          'query to see everything.',
        );
      }
    }

    final executables = Executables.load();

    return _json(
      scriptsConfigToJson(
        config,
        locations: loadScriptLocations(),
        executables: {
          'dart': executables.dart,
          'flutter': executables.flutter,
          ...executables.all,
        },
        variables: variables.retrieve(),
        resolve: resolve,
        only: only,
      ),
    );
  }

  // -------------------------------------------------------------------
  // dry_run
  // -------------------------------------------------------------------

  static final _dryRunTool = Tool(
    name: 'dry_run',
    description:
        'Show the exact commands a script would run, without running them. '
        'Use this to confirm what a script expands to before calling '
        'run_script.',
    inputSchema: Schema.object(
      properties: {'script': _scriptProperty},
      required: ['script'],
    ),
  );

  FutureOr<CallToolResult> _dryRun(CallToolRequest request) {
    final config = ScriptsConfig.load();
    final path = _pathFrom(request.arguments?['script']);

    final script = config.find(path);
    if (script == null) return _unknownScript(path, config);

    if (script.commands.isEmpty) {
      return _error(
        '"${path.join('.')}" is a group with no (command) of its own. Its '
        'subscripts are ${_childrenOf(script)}.',
      );
    }

    final (resolved, _) = script.resolve(
      flags: Args(path: path),
      scriptsConfig: config,
    );

    if (resolved == null) {
      return _error(
        'Could not resolve "${path.join('.')}". Call validate for the reason.',
      );
    }

    return _json({
      'key': script.keys.join('.'),
      'bail': resolved.bail,
      'commands': [
        for (final command in resolved.commands)
          if (command case final ScriptToRun run)
            {'command': run.exe, 'concurrent': run.runInParallel ?? false},
      ],
    });
  }

  // -------------------------------------------------------------------
  // run_script
  // -------------------------------------------------------------------

  static final _runScriptTool = Tool(
    name: 'run_script',
    description:
        'Run a script declared in scripts.yaml and return its exit code and '
        'output. Only declared scripts can be run -- this does not execute '
        'arbitrary commands.',
    inputSchema: Schema.object(
      properties: {
        'script': _scriptProperty,
        'bail': Schema.bool(
          description: 'Stop at the first command that fails.',
        ),
      },
      required: ['script'],
    ),
    annotations: ToolAnnotations(
      title: 'Run a sip script',
      // It runs whatever the project declared, which can write files, delete
      // build output or publish. Nothing here is safe to retry blindly.
      readOnlyHint: false,
      destructiveHint: true,
      idempotentHint: false,
    ),
  );

  Future<CallToolResult> _runScript(CallToolRequest request) async {
    final config = ScriptsConfig.load();
    final path = _pathFrom(request.arguments?['script']);

    final script = config.find(path);
    if (script == null) return _unknownScript(path, config);

    if (script.commands.isEmpty) {
      return _error(
        '"${path.join('.')}" is a group with no (command) of its own. Its '
        'subscripts are ${_childrenOf(script)}.',
      );
    }

    final (resolved, _) = script.resolve(
      flags: Args(path: path),
      scriptsConfig: config,
    );

    if (resolved == null) {
      return _error(
        'Could not resolve "${path.join('.')}". Call validate for the reason.',
      );
    }

    final bail = request.arguments?['bail'] as bool? ?? resolved.bail;

    // The aggregate result only carries output for commands that failed, and
    // the whole point here is to hand back what the script printed either
    // way. Collect each command's own result instead.
    final stdout = StringBuffer();
    final stderr = StringBuffer();

    // showOutput: false keeps the child's output off this process's stdout,
    // which is the MCP transport, and buffers it for us instead.
    final result = await scriptRunner.run(
      resolved.commands,
      bail: bail,
      showOutput: false,
      logTime: false,
      printLabels: false,
      onScriptResult: (_, result) {
        stdout.write(result.output);
        stderr.write(result.error);
      },
    );

    return _json({
      'key': script.keys.join('.'),
      'exitCode': result.exitCode,
      'ok': result.exitCode == 0,
      'stdout': stdout.toString().trim(),
      'stderr': stderr.toString().trim(),
    }, isError: result.exitCode != 0);
  }

  // -------------------------------------------------------------------
  // validate
  // -------------------------------------------------------------------

  static final _validateTool = Tool(
    name: 'validate',
    description:
        'Check scripts.yaml for unresolvable references, malformed '
        'substitutions, circular references, invalid names, duplicate aliases '
        'and settings that do not mean what they look like. Call this after '
        'editing scripts.yaml.',
    inputSchema: Schema.object(properties: {}),
    annotations: ToolAnnotations(
      title: 'Validate scripts.yaml',
      readOnlyHint: true,
    ),
  );

  FutureOr<CallToolResult> _validate(CallToolRequest request) {
    final file = scriptsYaml.nearest();
    final content = switch (file) {
      null => null,
      final file => scriptsYaml.retrieveContent(file),
    };

    if (file == null || content == null) {
      return _error('No ${ScriptsYaml.fileName} found in this project.');
    }

    final result = validateScripts(
      content: content,
      file: file,
      config: ScriptsConfig.load(),
      knownVariables: variables.retrieve().keys.toSet(),
    );

    return _json({
      'scriptsYaml': file,
      'ok': !result.hasErrors,
      'errors': result.errors.length,
      'warnings': result.warnings.length,
      'diagnostics': [
        for (final diagnostic in result.diagnostics) diagnostic.toJson(),
      ],
    });
  }

  // -------------------------------------------------------------------
  // Shared pieces
  // -------------------------------------------------------------------

  static final _scriptProperty = Schema.string(
    description:
        'The script to run, as its dotted key from list_scripts (for example '
        '"build_runner.build"). Spaces work too.',
  );

  /// Splits a script identifier into the path segments `find` expects.
  ///
  /// `sip run` takes them space-separated and `${{ }}` references use dots,
  /// so both turn up in the wild and both are accepted here.
  static List<String> _pathFrom(Object? raw) => switch (raw) {
    final String script => [
      for (final part in script.trim().split(RegExp(r'[.\s]+')))
        if (part.isNotEmpty) part,
    ],
    _ => const [],
  };

  static String _childrenOf(Script script) {
    final children = [
      for (final name in script.scripts?.keys ?? const <String>[])
        if (!name.startsWith('_')) name,
    ];

    return children.isEmpty ? 'none' : children.join(', ');
  }

  CallToolResult _unknownScript(List<String> path, ScriptsConfig config) {
    final available = [
      for (final name in config.scripts.keys)
        if (!name.startsWith('_')) name,
    ];

    return _error(
      'No script "${path.join('.')}" in scripts.yaml. Top-level scripts are: '
      '${available.join(', ')}. Call list_scripts for the full tree.',
    );
  }

  CallToolResult _json(Map<String, Object?> payload, {bool isError = false}) {
    return CallToolResult(
      content: [
        TextContent(text: const JsonEncoder.withIndent('  ').convert(payload)),
      ],
      isError: isError,
    );
  }

  CallToolResult _error(String message) {
    return CallToolResult(content: [TextContent(text: message)], isError: true);
  }
}
