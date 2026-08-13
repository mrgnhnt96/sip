import 'package:sip_cli/src/deps/scripts_yaml.dart';
import 'package:sip_cli/src/domain/script_locations.dart';

/// Builds a [ScriptLocations] index for the nearest `scripts.yaml`.
///
/// Returns an empty index when the file cannot be found or read, so callers
/// can offer locations where they exist without having to branch.
ScriptLocations loadScriptLocations() {
  final file = scriptsYaml.nearest();
  if (file == null) return const ScriptLocations.empty();

  final content = scriptsYaml.retrieveContent(file);
  if (content == null) return const ScriptLocations.empty();

  return ScriptLocations.parse(content, file: file);
}
