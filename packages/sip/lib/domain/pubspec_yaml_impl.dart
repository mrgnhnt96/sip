import 'package:sip/domain/find_yaml.dart';
import 'package:sip_script_runner/domain/domain.dart';

class PubspecYamlImpl extends FindYaml implements PubspecYaml {
  const PubspecYamlImpl();

  @override
  Map<String, dynamic>? parse([String? _]) {
    return super.parse(PubspecYaml.fileName);
  }

  @override
  String? nearest([String? _]) {
    return super.nearest(PubspecYaml.fileName);
  }

  @override
  String? retrieveContent([String? _]) {
    return super.retrieveContent(PubspecYaml.fileName);
  }
}
