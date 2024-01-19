abstract interface class ScriptsYaml {
  static const String fileName = 'scripts.yaml';

  Map<String, dynamic>? parse();

  String? nearest();

  String? retrieveContent();
}
