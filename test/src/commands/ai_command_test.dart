import 'package:file/file.dart';
import 'package:file/memory.dart';
import 'package:mason_logger/mason_logger.dart';
import 'package:sip_cli/src/commands/ai/ai_command.dart';
import 'package:sip_cli/src/commands/ai/ai_tool.dart';
import 'package:sip_cli/src/deps/fs.dart';
import 'package:sip_cli/src/domain/args.dart';
import 'package:sip_cli/src/domain/boolean_flags.dart';
import 'package:test/test.dart';

import '../../utils/test_scoped.dart';

void main() {
  group(AiCommand, () {
    late FileSystem fileSystem;

    FileSystem createFs() => fileSystem = MemoryFileSystem.test();

    Args parse(List<String> args) => Args.parse(args);

    group('writes the expected files', () {
      for (final (tool, expected) in [
        (AiTool.agents, ['AGENTS.md']),
        (AiTool.claude, ['CLAUDE.md']),
        (
          AiTool.cursor,
          ['.cursor/rules/sip-scripts.mdc', '.cursor/rules/sip-cli.mdc'],
        ),
        (AiTool.copilot, ['.github/copilot-instructions.md']),
        (AiTool.windsurf, ['.windsurfrules']),
        (AiTool.cline, ['.clinerules']),
      ]) {
        testScoped(
          tool.commandName,
          fileSystem: createFs,
          args: () => parse(['ai', tool.commandName]),
          () async {
            final exitCode = await const AiCommand().run([tool.commandName]);

            expect(exitCode, ExitCode.success);

            for (final path in expected) {
              final file = fs.file(path);
              expect(file.existsSync(), isTrue, reason: 'missing $path');
              expect(file.readAsStringSync(), isNotEmpty);
            }
          },
        );
      }
    });

    testScoped(
      "all writes every tool's files",
      fileSystem: createFs,
      args: () => parse(['ai', 'all']),
      () async {
        final exitCode = await const AiCommand().run(['all']);

        expect(exitCode, ExitCode.success);

        for (final tool in AiTool.values) {
          for (final path in tool.files().keys) {
            expect(fs.file(path).existsSync(), isTrue, reason: 'missing $path');
          }
        }
      },
    );

    testScoped(
      'does not overwrite an existing file without --force',
      fileSystem: createFs,
      args: () => parse(['ai', 'claude']),
      () async {
        fs.file('CLAUDE.md').writeAsStringSync('do not clobber me');

        final exitCode = await const AiCommand().run(['claude']);

        expect(exitCode, ExitCode.success);
        expect(fs.file('CLAUDE.md').readAsStringSync(), 'do not clobber me');
      },
    );

    testScoped(
      'overwrites an existing file with --force',
      fileSystem: createFs,
      args: () => parse(['ai', 'claude', '--force']),
      () async {
        fs.file('CLAUDE.md').writeAsStringSync('do not clobber me');

        final exitCode = await const AiCommand().run(['claude']);

        expect(exitCode, ExitCode.success);
        expect(
          fs.file('CLAUDE.md').readAsStringSync(),
          isNot('do not clobber me'),
        );
      },
    );

    testScoped(
      'returns usage for an unknown tool',
      fileSystem: createFs,
      args: () => parse(['ai', 'notatool']),
      () async {
        final exitCode = await const AiCommand().run(['notatool']);

        expect(exitCode, ExitCode.usage);
        expect(fileSystem.file('CLAUDE.md').existsSync(), isFalse);
      },
    );

    testScoped(
      'returns usage when no tool is given',
      fileSystem: createFs,
      args: () => parse(['ai']),
      () async {
        expect(await const AiCommand().run([]), ExitCode.usage);
      },
    );

    testScoped(
      '--help returns success without writing',
      fileSystem: createFs,
      args: () => parse(['ai', '--help']),
      () async {
        expect(await const AiCommand().run([]), ExitCode.success);
        expect(fileSystem.file('CLAUDE.md').existsSync(), isFalse);
      },
    );

    test('--force is registered as a boolean flag', () {
      // Otherwise `sip ai --force claude` reads `claude` as the flag's value
      // and loses the tool entirely.
      expect(booleanFlagNames, contains('force'));

      final args = Args.parse(['ai', '--force', 'claude']);
      expect(args.get<bool>('force', defaultValue: false), isTrue);
      // The path stops at the first flag, so the tool lands in `rest`.
      expect(args.path, ['ai']);
      expect(args.rest, ['claude']);
    });

    testScoped(
      'accepts the tool when it follows a flag',
      fileSystem: createFs,
      args: () => parse(['ai', '--force', 'claude']),
      () async {
        expect(await const AiCommand().run([]), ExitCode.success);
        expect(fs.file('CLAUDE.md').existsSync(), isTrue);
      },
    );
  });
}
