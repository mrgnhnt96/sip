import 'package:sip_cli/src/deps/fs.dart';
import 'package:sip_cli/src/domain/find_yaml.dart';

class PubspecYaml extends FindYaml {
  const PubspecYaml();

  static const String fileName = 'pubspec.yaml';

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

  Future<Iterable<String>> children() async {
    final children = await super.childrenOf(PubspecYaml.fileName);

    return children;
  }

  Future<List<String>> all({bool recursive = false}) async {
    final pubspecs = <String>{};

    if (recursive) {
      final children = await this.children();
      pubspecs.addAll(children.map((e) => fs.path.join(fs.path.separator, e)));
    } else {
      final nearest = this.nearest();
      if (nearest != null) {
        pubspecs.add(nearest);
      }
    }

    final sortedPubspecs = [...pubspecs]
      ..sort()
      ..sort((a, b) => fs.path.split(b).length - fs.path.split(a).length);

    return sortedPubspecs..removeWhere((e) {
      final segments = fs.path.split(e);

      if (segments.contains('build')) {
        return true;
      }

      if (segments.any((e) => e.startsWith('.'))) {
        return true;
      }

      return false;
    });
  }
}
