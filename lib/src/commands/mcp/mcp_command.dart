import 'dart:async';
import 'dart:io' as io;

import 'package:dart_mcp/stdio.dart';
import 'package:mason_logger/mason_logger.dart';
import 'package:scoped_deps/scoped_deps.dart';
import 'package:sip_cli/src/commands/mcp/sip_mcp_server.dart';
import 'package:sip_cli/src/deps/analytics.dart';
import 'package:sip_cli/src/deps/args.dart';
import 'package:sip_cli/src/deps/logger.dart';

const _usage = '''
Usage: sip mcp

Run sip as an MCP server over stdio

Exposes this project's scripts to an AI coding assistant as tools:

  list_scripts   Every script, with the commands it actually runs
  dry_run        What a script expands to, without running it
  run_script     Run a declared script and return its exit code and output
  validate       Check scripts.yaml for problems

Only scripts declared in scripts.yaml can be run; this never executes an
arbitrary command.

This speaks JSON-RPC on stdin/stdout and is not meant to be run by hand.
Point your assistant at it, for example:

  {
    "mcpServers": {
      "sip": { "command": "sip", "args": ["mcp"] }
    }
  }

Options:
  --help      Print usage information
''';

/// The `mcp` command.
///
/// sip's CLI is only used by an assistant that remembers to use it. A tool in
/// the tool list is used because it is there -- which is the difference
/// between an assistant running the project's `test` script and it
/// reconstructing `dart test`, bypassing everything the project declared.
class McpCommand {
  const McpCommand();

  Future<ExitCode> run() async {
    if (args.get<bool>('help', defaultValue: false)) {
      logger.write(_usage);
      return ExitCode.success;
    }

    await analytics.track('mcp');

    // stdout IS the transport. The channel keeps this reference to the real
    // one; everything else gets the redirected view installed below.
    final channel = stdioChannel(input: io.stdin, output: io.stdout);

    // Anything sip writes to stdout -- a warning from loading scripts.yaml,
    // a resolution error, a progress spinner -- would land inside a JSON-RPC
    // frame and break the session. Pointing `stdout` at stderr for the
    // duration catches all of it, including the spinners that write through
    // a handle a Logger subclass cannot reach.
    await io.IOOverrides.runZoned(
      () => runScoped(
        () async {
          final server = SipMcpServer(channel);

          await server.done;
        },
        // Constructed inside the zone, so it captures the override.
        values: {loggerProvider.overrideWith(Logger.new)},
      ),
      stdout: () => io.stderr,
    );

    return ExitCode.success;
  }
}
