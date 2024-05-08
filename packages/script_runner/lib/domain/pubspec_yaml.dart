/// The interface for the pubspec.yaml file.
abstract interface class PubspecYaml {
  static const String fileName = 'pubspec.yaml';

  String? nearest();

  Future<Iterable<String>> children();

  /// This method is used to find all the pubspecs in the project
  ///
  /// When [recursive] is true, this finds pubspecs in subdirectories
  /// as well as the current directory.
  ///
  /// When [recursive] is false, this only finds the pubspec in the
  /// current directory.
  Future<Iterable<String>> all({bool recursive = false});
}
