/// The interface for the pubspec.yaml file.
abstract interface class PubspecYaml {
  static const String fileName = 'pubspec.yaml';

  String? nearest();

  Future<Iterable<String>> children();
}
