import 'package:sip/domain/find_yaml.dart';
import 'package:sip_script_runner/sip_script_runner.dart';

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
}
