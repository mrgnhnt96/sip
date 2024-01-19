import 'package:file/file.dart';
import 'package:sip/setup/dependency_injection.dart';

class FindFile {
  const FindFile();

  String? nearest(String fileName) {
    Directory? directory = getIt<FileSystem>().currentDirectory;

    // traverse up the directory tree until we find a scripts.yaml file
    File? file;

    while (directory != null) {
      final possible = directory.childFile(fileName);
      if (possible.existsSync()) {
        file = possible;
        break;
      }

      if (directory.path == directory.parent.path) {
        break;
      }

      directory = directory.parent;
    }

    return file?.path;
  }

  String? retrieveContent(String fileName) {
    final scriptsPath = nearest(fileName);

    if (scriptsPath == null) {
      return null;
    }

    final scriptsFile = getIt<FileSystem>().file(scriptsPath);

    return scriptsFile.readAsStringSync();
  }
}
