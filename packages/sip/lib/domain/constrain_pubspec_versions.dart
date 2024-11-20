import 'package:file/file.dart';
import 'package:mason_logger/mason_logger.dart';
import 'package:pub_semver/pub_semver.dart';
import 'package:yaml/yaml.dart';
import 'package:yaml_edit/yaml_edit.dart';

class ConstrainPubspecVersions {
  const ConstrainPubspecVersions({
    required this.fs,
    required this.logger,
  });

  final FileSystem fs;
  final Logger logger;

  bool constrain(
    String path, {
    bool includeDevDependencies = false,
  }) {
    final file = fs.file(path);

    if (!file.existsSync()) {
      return false;
    }

    final content = file.readAsStringSync();

    final result = applyConstraintsTo(
      content,
      additionalKeys: [
        if (includeDevDependencies) 'dev_dependencies',
      ],
    );

    if (result == null) {
      return false;
    }

    file.writeAsStringSync(result);

    return true;
  }

  String? applyConstraintsTo(
    String content, {
    Iterable<String> additionalKeys = const [],
  }) {
    final yaml = YamlEditor(content);

    final dependencies = [
      'dependencies',
      ...additionalKeys,
    ];

    var changesMade = false;

    for (final key in dependencies) {
      logger.detail('Constraining versions for $key');
      if (yaml[key] case final YamlMap deps) {
        for (final MapEntry(key: name, value: version) in deps.entries) {
          final depConstraint = constraint(name, version);

          if (depConstraint == null) continue;

          changesMade = true;

          yaml.update([key, depConstraint.name], depConstraint.version);
          logger.delayed('  - $name: $version -> ${depConstraint.version}');
        }
      }
    }

    if (!changesMade) {
      return null;
    }

    return yaml.toString();
  }

  ({dynamic name, dynamic version})? constraint(dynamic name, dynamic version) {
    if (name is! String || version is! String) {
      return null;
    }

    Version semVersion;

    try {
      semVersion = Version.parse(version.replaceFirst('^', ''));
    } on FormatException {
      return null;
    }

    final nextVersion = semVersion.nextBreaking;

    final constraint = '>=$semVersion <$nextVersion';

    return (name: name, version: constraint);
  }
}

extension _YamlEditorX on YamlEditor {
  YamlNode? operator [](dynamic key) {
    try {
      return switch (key) {
        String() => parseAt([key]),
        List<String>() => parseAt(key),
        _ => throw StateError('Expected a string or list of strings.'),
      };
    } catch (_) {
      return null;
    }
  }
}
