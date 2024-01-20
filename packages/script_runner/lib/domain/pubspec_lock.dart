abstract interface class PubspecLock {
  static const String fileName = 'pubspec.lock';

  String? findIn(String directory);
}
