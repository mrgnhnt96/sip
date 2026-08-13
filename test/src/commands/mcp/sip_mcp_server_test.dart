import 'dart:async';
import 'dart:convert';

import 'package:dart_mcp/client.dart';
import 'package:file/file.dart';
import 'package:file/memory.dart';
import 'package:sip_cli/src/commands/mcp/sip_mcp_server.dart';
import 'package:stream_channel/stream_channel.dart';
import 'package:test/test.dart';

import '../../../utils/test_scoped.dart';

void main() {
  group(SipMcpServer, () {
    const yaml = r'''
(executables):
  dart: fvm dart

greet:
  (description): Say hello
  (aliases): [g]
  (command): echo hello

build_runner:
  _: ${{ dart }} run build_runner
  build: ${{ build_runner._ }} build

group_only:
  child: echo child

broken: echo ${{ nope }}
''';

    FileSystem createFs() {
      final fs = MemoryFileSystem.test();
      fs.file('/scripts.yaml')
        ..createSync(recursive: true)
        ..writeAsStringSync(yaml);

      return fs;
    }

    /// Connects a client to a [SipMcpServer] over an in-memory channel pair
    /// and initializes the session.
    Future<ServerConnection> connect() async {
      final clientController = StreamController<String>();
      final serverController = StreamController<String>();

      SipMcpServer(
        StreamChannel<String>.withCloseGuarantee(
          clientController.stream,
          serverController.sink,
        ),
      );

      final client = MCPClient(Implementation(name: 'test', version: '1.0.0'));

      final connection = client.connectServer(
        StreamChannel<String>.withCloseGuarantee(
          serverController.stream,
          clientController.sink,
        ),
      );

      await connection.initialize(
        InitializeRequest(
          protocolVersion: ProtocolVersion.latestSupported,
          capabilities: client.capabilities,
          clientInfo: client.implementation,
        ),
      );
      connection.notifyInitialized();

      return connection;
    }

    /// The JSON payload a tool returned.
    Map<String, Object?> payloadOf(CallToolResult result) {
      final text = (result.content.single as TextContent).text;

      return jsonDecode(text) as Map<String, Object?>;
    }

    String textOf(CallToolResult result) =>
        (result.content.single as TextContent).text;

    testScoped('advertises every tool', fileSystem: createFs, () async {
      final connection = await connect();

      final tools = (await connection.listTools()).tools.map((e) => e.name);

      expect(
        tools,
        containsAll(['list_scripts', 'dry_run', 'run_script', 'validate']),
      );
    });

    testScoped(
      'list_scripts returns the resolved commands',
      fileSystem: createFs,
      () async {
        final connection = await connect();

        final result = await connection.callTool(
          CallToolRequest(name: 'list_scripts'),
        );

        expect(result.isError, isNot(true));

        final scripts = (payloadOf(result)['scripts']! as List)
            .cast<Map<String, Object?>>();

        final build = scripts.firstWhere(
          (e) => e['key'] == 'build_runner.build',
        );

        // Resolved through the reference AND the (executables) override, which
        // is exactly what reading scripts.yaml would not tell you.
        expect(
          (build['resolved']! as List).cast<Map<String, Object?>>().single,
          containsPair('command', 'fvm dart run build_runner build'),
        );
      },
    );

    testScoped('list_scripts filters by query', fileSystem: createFs, () async {
      final connection = await connect();

      final result = await connection.callTool(
        CallToolRequest(name: 'list_scripts', arguments: {'query': 'greet'}),
      );

      final keys = (payloadOf(result)['scripts']! as List)
          .cast<Map<String, Object?>>()
          .map((e) => e['key']);

      expect(keys, ['greet']);
    });

    testScoped(
      'list_scripts reports a query that matches nothing',
      fileSystem: createFs,
      () async {
        final connection = await connect();

        final result = await connection.callTool(
          CallToolRequest(name: 'list_scripts', arguments: {'query': 'zzz'}),
        );

        expect(result.isError, isTrue);
        expect(textOf(result), contains('No scripts match'));
      },
    );

    testScoped(
      'dry_run expands a script without running it',
      fileSystem: createFs,
      () async {
        final connection = await connect();

        final result = await connection.callTool(
          CallToolRequest(
            name: 'dry_run',
            arguments: {'script': 'build_runner.build'},
          ),
        );

        expect(result.isError, isNot(true));

        final commands = (payloadOf(result)['commands']! as List)
            .cast<Map<String, Object?>>();

        expect(commands.single['command'], 'fvm dart run build_runner build');
      },
    );

    testScoped(
      'dry_run accepts a space-separated path',
      fileSystem: createFs,
      () async {
        // `sip run` takes them space-separated and references use dots, so both
        // turn up in the wild.
        final connection = await connect();

        final result = await connection.callTool(
          CallToolRequest(
            name: 'dry_run',
            arguments: {'script': 'build_runner build'},
          ),
        );

        expect(result.isError, isNot(true));
        // Either form resolves to the same script, and the reply always
        // names it the one canonical way.
        expect(payloadOf(result)['key'], 'build_runner.build');
      },
    );

    testScoped(
      'dry_run names the available scripts for an unknown one',
      fileSystem: createFs,
      () async {
        final connection = await connect();

        final result = await connection.callTool(
          CallToolRequest(name: 'dry_run', arguments: {'script': 'nope'}),
        );

        expect(result.isError, isTrue);
        // An unknown name is a recoverable mistake, so the error carries what
        // to try instead.
        expect(textOf(result), contains('greet'));
      },
    );

    testScoped(
      'dry_run explains a group with no command of its own',
      fileSystem: createFs,
      () async {
        final connection = await connect();

        final result = await connection.callTool(
          CallToolRequest(name: 'dry_run', arguments: {'script': 'group_only'}),
        );

        expect(result.isError, isTrue);
        expect(textOf(result), contains('child'));
      },
    );

    testScoped(
      'validate reports the diagnostics',
      fileSystem: createFs,
      () async {
        final connection = await connect();

        final result = await connection.callTool(
          CallToolRequest(name: 'validate'),
        );

        final payload = payloadOf(result);

        expect(payload['ok'], isFalse);

        final codes = (payload['diagnostics']! as List)
            .cast<Map<String, Object?>>()
            .map((e) => e['code']);

        expect(codes, contains('unknown-reference'));
      },
    );

    testScoped(
      'run_script refuses a script that is not declared',
      fileSystem: createFs,
      () async {
        // The tool takes a script name, never a command, so there is no way to
        // reach an arbitrary shell string through it.
        final connection = await connect();

        final result = await connection.callTool(
          CallToolRequest(
            name: 'run_script',
            arguments: {'script': 'rm -rf /'},
          ),
        );

        expect(result.isError, isTrue);
        expect(textOf(result), contains('No script'));
      },
    );
  });
}
