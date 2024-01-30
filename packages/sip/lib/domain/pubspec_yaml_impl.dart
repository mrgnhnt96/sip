import 'package:sip_cli/domain/find_yaml.dart';
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
  String? retrieveNearestContent([String? _]) {
    return super.retrieveNearestContent(PubspecYaml.fileName);
  }

  @override
  String? retrieveContent([String? path]) {
    return super.retrieveContent(path ?? PubspecYaml.fileName);
  }

  @override
  Future<Iterable<String>> children() async {
    final children = await super.childrenOf(PubspecYaml.fileName);

    return children;
  }
}
