import 'package:sip_cli/domain/find_yaml.dart';
import 'package:sip_script_runner/sip_script_runner.dart';
import 'package:sip_script_runner/utils/constants.dart';

class ScriptsYamlImpl extends FindYaml implements ScriptsYaml {
  const ScriptsYamlImpl();

  @override
  Map<String, dynamic>? parse([String? _]) {
    return super.parse(ScriptsYaml.fileName);
  }

  @override
  String? nearest([String? _]) {
    return super.nearest(ScriptsYaml.fileName);
  }

  @override
  String? retrieveNearestContent([String? _]) {
    return super.retrieveNearestContent(ScriptsYaml.fileName);
  }

  @override
  String? retrieveContent([String? path]) {
    return super.retrieveContent(path ?? ScriptsYaml.fileName);
  }

  @override
  Map<String, dynamic>? scripts() {
    final parsed = parse();

    final all = {...?parsed};
    all.remove(Keys.variables);

    return all;
  }

  @override
  Map<String, dynamic>? variables() {
    final parsed = parse();

    return parsed?[Keys.variables]?.cast<String, dynamic>();
  }
}
