import 'package:args/command_runner.dart';
import 'package:sip/domain/scripts_yaml_impl.dart';
import 'package:sip/setup/setup.dart';
import 'package:sip/utils/exit_code.dart';
import 'package:sip_console/domain/sip_console.dart';
import 'package:sip_console/utils/ansi.dart';
import 'package:sip_script_runner/sip_script_runner.dart';

class ListCommand extends Command<ExitCode> {
  ListCommand({
    this.scriptsYaml = const ScriptsYamlImpl(),
  });

  final ScriptsYaml scriptsYaml;

  @override
  String get description => 'List all scripts defined in scripts.yaml';

  @override
  String get name => 'list';

  @override
  List<String> get aliases => ['ls'];

  Future<ExitCode> run() async {
    final content = scriptsYaml.parse();
    if (content == null) {
      getIt<SipConsole>().e('No ${ScriptsYaml.fileName} file found');
      return ExitCode.noInput;
    }

    final scriptConfig = ScriptsConfig.fromJson(content);

    getIt<SipConsole>().l(scriptConfig.listOut(
      wrapKey: (s) => lightGreen.wrap(s) ?? s,
      wrapMeta: (s) => lightBlue.wrap(s) ?? s,
    ));

    return ExitCode.success;
  }
}
