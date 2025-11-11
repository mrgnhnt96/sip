import 'dart:convert';

import 'package:sip_cli/src/domain/find_yaml.dart';
import 'package:sip_cli/src/utils/constants.dart';

class ScriptsYaml extends FindYaml {
  const ScriptsYaml();

  static const String fileName = 'scripts.yaml';

  @override
  Map<String, dynamic>? parse([String? fileName]) {
    return super.parse(ScriptsYaml.fileName);
  }

  @override
  String? nearest([String? fileName]) {
    return super.nearest(ScriptsYaml.fileName);
  }

  @override
  String? retrieveNearestContent([String? fileName]) {
    return super.retrieveNearestContent(ScriptsYaml.fileName);
  }

  @override
  String? retrieveContent([String? path]) {
    return super.retrieveContent(path ?? ScriptsYaml.fileName);
  }

  Map<String, dynamic>? scripts() {
    final parsed = parse();

    final all = {...?parsed}
      ..removeWhere((e, _) => Keys.nonScriptKeys.contains(e));

    return switch (jsonDecode(jsonEncode(all))) {
      final Map<String, dynamic> json => json,
      _ => {},
    };
  }

  Map<String, dynamic>? variables() {
    final parsed = parse();

    return Map.from(parsed?[Keys.variables] as Map? ?? {});
  }

  Map<String, dynamic>? executables() {
    final parsed = parse();

    return Map.from(parsed?[Keys.executables] as Map? ?? {});
  }
}
