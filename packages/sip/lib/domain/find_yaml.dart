import 'package:sip_cli/domain/find_file.dart';
import 'package:yaml/yaml.dart';

abstract class FindYaml extends FindFile {
  const FindYaml({
    required super.fs,
  });

  Map<String, dynamic>? parse(String fileName) {
    final content = retrieveNearestContent(fileName);

    if (content == null) {
      return null;
    }

    final yaml = loadYaml(content);

    if (yaml is! Map) {
      return null;
    }

    return yaml.cast<String, dynamic>();
  }
}
