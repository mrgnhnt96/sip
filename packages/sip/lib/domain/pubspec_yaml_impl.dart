import 'package:path/path.dart' as path;
import 'package:sip_cli/domain/find_yaml.dart';
import 'package:sip_script_runner/sip_script_runner.dart';

class PubspecYamlImpl extends FindYaml implements PubspecYaml {
  const PubspecYamlImpl({
    required super.fs,
  });

  @override
  Map<String, dynamic>? parse([String? fileName]) {
    return super.parse(PubspecYaml.fileName);
  }

  @override
  String? nearest([String? fileName]) {
    return super.nearest(PubspecYaml.fileName);
  }

  @override
  String? retrieveNearestContent([String? fileName]) {
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

  @override
  Future<Iterable<String>> all({bool recursive = false}) async {
    final pubspecs = <String>{};

    final pubspec = nearest();

    if (pubspec != null) {
      pubspecs.add(pubspec);
    }

    if (recursive) {
      final children = await this.children();
      pubspecs.addAll(children.map((e) => path.join(path.separator, e)));
    }

    return pubspecs;
  }
}
