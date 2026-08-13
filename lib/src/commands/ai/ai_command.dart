import 'package:mason_logger/mason_logger.dart';
import 'package:path/path.dart' as path;
import 'package:sip_cli/src/commands/ai/ai_tool.dart';
import 'package:sip_cli/src/deps/analytics.dart';
import 'package:sip_cli/src/deps/args.dart';
import 'package:sip_cli/src/deps/fs.dart';
import 'package:sip_cli/src/deps/logger.dart';

const _usage = '''
Usage: sip ai <tool>

Install a sip reference file for an AI coding assistant

Tools:
  claude      Claude Code (CLAUDE.md)
  cursor      Cursor (.cursor/rules/sip-*.mdc)
  copilot     GitHub Copilot (.github/copilot-instructions.md)
  windsurf    Windsurf (.windsurfrules)
  cline       Cline (.clinerules)
  all         Every tool listed above

Options:
  --help      Print usage information
  --force     Overwrite files that already exist
''';

/// The `ai` command.
///
/// Writes a reference document describing sip and `scripts.yaml` into the
/// location each supported assistant reads, so it can work with the project's
/// scripts without guessing.
class AiCommand {
  const AiCommand();

  Future<ExitCode> run(List<String> commandPath) async {
    if (args.get<bool>('help', defaultValue: false)) {
      logger.write(_usage);
      return ExitCode.success;
    }

    // `Args` stops filling the command path at the first flag, so
    // `sip ai --force claude` leaves the tool in `rest` instead.
    final selection = switch (commandPath) {
      [] => args.rest,
      _ => commandPath,
    };

    final tools = switch (selection) {
      ['all'] => AiTool.values,
      [final name] => switch (AiTool.fromName(name)) {
        final tool? => [tool],
        _ => null,
      },
      _ => null,
    };

    if (tools == null) {
      if (selection case [final name, ...]) {
        logger.err('Unknown tool: $name');
      }

      logger.write(_usage);
      return ExitCode.usage;
    }

    await analytics.track('ai', props: {'tools': tools.length});

    final force = args.get<bool>('force', defaultValue: false);
    var wrote = 0;
    var skipped = 0;

    for (final tool in tools) {
      for (final MapEntry(key: filePath, value: contents)
          in tool.files().entries) {
        if (_write(filePath, contents, force: force)) {
          wrote++;
        } else {
          skipped++;
        }
      }
    }

    if (skipped > 0 && wrote == 0) {
      logger.info('Nothing to do. Use --force to overwrite existing files.');
    }

    return ExitCode.success;
  }

  /// Writes [contents] to [filePath], relative to the current directory.
  ///
  /// Existing files are left alone unless [force] is set. Returns whether the
  /// file was written.
  bool _write(String filePath, String contents, {required bool force}) {
    final file = fs.file(path.join(fs.currentDirectory.path, filePath));

    if (file.existsSync() && !force) {
      logger.info(
        '${yellow.wrap('Skipped')} ${darkGray.wrap(filePath)} '
        '(already exists)',
      );
      return false;
    }

    file.parent.createSync(recursive: true);
    file.writeAsStringSync(contents);

    logger.info('${green.wrap('Created')} ${darkGray.wrap(filePath)}');

    return true;
  }
}
