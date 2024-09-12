/// The interface for the pubspec.lock file.
abstract interface class PubspecLock {
  static const String fileName = 'pubspec.lock';

  String? findIn(String directory);
}
