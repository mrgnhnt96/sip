import 'package:scoped_deps/scoped_deps.dart';
import 'package:sip_cli/src/domain/scripts_yaml.dart';

final scriptsYamlProvider = create<ScriptsYaml>(ScriptsYaml.new);

ScriptsYaml get scriptsYaml => read(scriptsYamlProvider);
