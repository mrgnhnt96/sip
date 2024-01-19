abstract interface class PubspecYaml {
  static const String fileName = 'pubspec.yaml';

  Map<String, dynamic>? parse();

  String? nearest();

  String? retrieveContent();
}
