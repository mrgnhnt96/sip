import 'package:sip_cli/src/domain/find_file.dart';

class PubspecLock extends FindFile {
  const PubspecLock();

  static const String fileName = 'pubspec.lock';

  String? findIn(String directoryPath) {
    final result = super.fileWithin(PubspecLock.fileName, directoryPath);

    // this is the correct approach for workspaces, but if ANY packages depend
    // on Flutter, then all tools will resolve as Flutter.
    // if (result == null) {
    //   return super.nearest(PubspecLock.fileName);
    // }

    return result;
  }

  @override
  String? retrieveContent([String? path]) {
    return super.retrieveNearestContent(PubspecLock.fileName);
  }
}
