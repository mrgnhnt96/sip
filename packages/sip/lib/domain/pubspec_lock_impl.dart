import 'package:sip_cli/domain/find_file.dart';
import 'package:sip_script_runner/domain/pubspec_lock.dart';

class PubspecLockImpl extends FindFile implements PubspecLock {
  const PubspecLockImpl();

  @override
  String? findIn(String directoryPath) {
    final result = super.fileWithin(PubspecLock.fileName, directoryPath);

    return result;
  }

  @override
  String? retrieveContent([String? path]) {
    return super.retrieveNearestContent(PubspecLock.fileName);
  }
}
