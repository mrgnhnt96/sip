import 'package:sip/domain/find_yaml.dart';

class ScriptsYaml extends FindYaml {
  const ScriptsYaml();

  static const String fileName = 'scripts.yaml';

  @override
  Map<String, dynamic>? parse([String? _]) {
    return super.parse(fileName);
  }

  @override
  String? nearest([String? _]) {
    return super.nearest(fileName);
  }

  @override
  String? retrieveContent([String? _]) {
    return super.retrieveContent(fileName);
  }
}