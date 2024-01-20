import 'package:file/file.dart';
import 'package:sip/setup/setup.dart';

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

  String? retrieveNearestContent(String fileName) {
    final scriptsPath = nearest(fileName);

    if (scriptsPath == null) {
      return null;
    }

    return retrieveContent(scriptsPath);
  }

  String? retrieveContent(String path) {
    final file = getIt<FileSystem>().file(path);

    if (!file.existsSync()) {
      return null;
    }

    return file.readAsStringSync();
  }

  String? fileWithin(String fileName, String directoryPath) {
    final directory = getIt<FileSystem>().directory(directoryPath);

    final file = directory.childFile(fileName);

    if (file.existsSync()) {
      return file.path;
    }

    return null;
  }

  /// finds all children that match the given file name, starts from the current
  /// directory and traverses down
  Future<List<String>> childrenOf(
    String fileName,
    List<String>? inPaths,
  ) async {
    final children = <String>[];

    var directories = <Directory>[];

    if (inPaths != null && inPaths.isNotEmpty) {
      for (final inPath in inPaths) {
        final directory = getIt<FileSystem>().directory(inPath);
        if (!directory.existsSync()) continue;

        directories.add(directory);
      }
    } else {
      final directory = getIt<FileSystem>().currentDirectory;
      directories = [directory];
    }

    final recursive = directories.length == 1;

    for (final directory in directories) {
      final entities = directory.list(
        followLinks: false,
        recursive: recursive,
      );

      await for (final entity in entities) {
        if (entity is! File) continue;
        if (entity.basename != fileName) continue;

        children.add(entity.path);
      }
    }

    return children;
  }
}
