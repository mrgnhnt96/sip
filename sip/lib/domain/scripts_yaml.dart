/// This is the interface for the scripts.yaml file.
abstract interface class ScriptsYaml {
  static const String fileName = 'scripts.yaml';

  Map<String, dynamic>? parse();

  Map<String, dynamic>? variables();

  Map<String, dynamic>? scripts();

  Map<String, dynamic>? executables();

  String? nearest();

  String? retrieveContent();
}
