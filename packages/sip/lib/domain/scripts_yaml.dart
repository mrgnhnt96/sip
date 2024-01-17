import 'package:file/file.dart';
import 'package:sip/setup/dependency_injection.dart';
import 'package:yaml/yaml.dart';

class ScriptsYaml {
  const ScriptsYaml();

  static const String fileName = 'scripts.yaml';

  String? nearest([String fileName = fileName]) {
    Directory? directory = getIt<FileSystem>().currentDirectory;

    // traverse up the directory tree until we find a scripts.yaml file
    File? scriptsFile;

    while (directory != null) {
      final possible = directory.childFile(fileName);
      if (possible.existsSync()) {
        scriptsFile = possible;
        break;
      }

      if (directory.path == directory.parent.path) {
        break;
      }

      directory = directory.parent;
    }

    return scriptsFile?.path;
  }

  String? retrieveContent() {
    final scriptsPath = nearest();

    if (scriptsPath == null) {
      return null;
    }

    final scriptsFile = getIt<FileSystem>().file(scriptsPath);

    return scriptsFile.readAsStringSync();
  }

  Map<String, dynamic>? parse() {
    final content = retrieveContent();

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
