import 'package:sip_cli/domain/find_file.dart';
import 'package:sip_cli/domain/pubspec_lock.dart';

class PubspecLockImpl extends FindFile implements PubspecLock {
  const PubspecLockImpl({required super.fs});

  @override
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
