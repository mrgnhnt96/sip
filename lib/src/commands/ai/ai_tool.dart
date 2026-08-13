import 'package:path/path.dart' as path;
import 'package:sip_cli/src/commands/ai/ai_templates.dart';

/// An AI coding assistant that `sip ai` can install a reference file for.
enum AiTool {
  claude('claude', 'Claude Code (CLAUDE.md)'),
  cursor('cursor', 'Cursor (.cursor/rules/sip-*.mdc)'),
  copilot('copilot', 'GitHub Copilot (.github/copilot-instructions.md)'),
  windsurf('windsurf', 'Windsurf (.windsurfrules)'),
  cline('cline', 'Cline (.clinerules)');

  const AiTool(this.commandName, this.description);

  final String commandName;
  final String description;

  static AiTool? fromName(String name) {
    for (final tool in values) {
      if (tool.commandName == name) return tool;
    }

    return null;
  }

  /// The files to write, keyed by their path relative to the project root.
  Map<String, String> files() => switch (this) {
    AiTool.claude => {'CLAUDE.md': claudeMd},
    AiTool.cursor => {
      for (final MapEntry(:key, :value) in cursorMdcFiles.entries)
        path.join('.cursor', 'rules', key): value,
    },
    AiTool.copilot => {
      path.join('.github', 'copilot-instructions.md'): copilotMd,
    },
    AiTool.windsurf => {'.windsurfrules': windsurfRules},
    AiTool.cline => {'.clinerules': clineRules},
  };
}
