import 'package:sip_cli/domain/find_yaml.dart';
import 'package:sip_cli/domain/scripts_yaml.dart';
import 'package:sip_cli/utils/constants.dart';

class ScriptsYamlImpl extends FindYaml implements ScriptsYaml {
  const ScriptsYamlImpl({
    required super.fs,
  });

  @override
  Map<String, dynamic>? parse([String? fileName]) {
    return super.parse(ScriptsYaml.fileName);
  }

  @override
  String? nearest([String? fileName]) {
    return super.nearest(ScriptsYaml.fileName);
  }

  @override
  String? retrieveNearestContent([String? fileName]) {
    return super.retrieveNearestContent(ScriptsYaml.fileName);
  }

  @override
  String? retrieveContent([String? path]) {
    return super.retrieveContent(path ?? ScriptsYaml.fileName);
  }

  @override
  Map<String, dynamic>? scripts() {
    final parsed = parse();

    final all = {...?parsed}
      ..removeWhere((e, _) => Keys.nonScriptKeys.contains(e));

    return all;
  }

  @override
  Map<String, dynamic>? variables() {
    final parsed = parse();

    return Map.from(parsed?[Keys.variables] as Map? ?? {});
  }

  @override
  Map<String, dynamic>? executables() {
    final parsed = parse();

    return Map.from(parsed?[Keys.executables] as Map? ?? {});
  }
}
