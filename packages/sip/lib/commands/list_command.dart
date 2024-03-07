import 'package:args/command_runner.dart';
import 'package:sip_cli/domain/scripts_yaml_impl.dart';
import 'package:sip_cli/setup/setup.dart';
import 'package:sip_cli/utils/exit_code.dart';
import 'package:sip_console/domain/sip_console.dart';
import 'package:sip_console/utils/ansi.dart';
import 'package:sip_script_runner/sip_script_runner.dart';

/// The command to list all available scripts
class ListCommand extends Command<ExitCode> {
  ListCommand({
    required this.scriptsYaml,
  });

  final ScriptsYaml scriptsYaml;

  @override
  String get description => 'List all scripts defined in scripts.yaml';

  @override
  String get name => 'list';

  @override
  List<String> get aliases => ['ls'];

  @override
  Future<ExitCode> run() async {
    final content = scriptsYaml.scripts();
    if (content == null) {
      getIt<SipConsole>().e('No ${ScriptsYaml.fileName} file found');
      return ExitCode.noInput;
    }

    final scriptConfig = ScriptsConfig.fromJson(content);

    getIt<SipConsole>()
      ..emptyLine()
      ..l(
        scriptConfig.listOut(
          wrapCallableKey: (s) => lightGreen.wrap(s) ?? s,
          wrapNonCallableKey: (s) => cyan.wrap(s) ?? s,
          wrapMeta: (s) => lightBlue.wrap(s) ?? s,
        ),
      );

    return ExitCode.success;
  }
}
