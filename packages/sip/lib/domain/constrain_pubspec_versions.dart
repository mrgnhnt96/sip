import 'package:file/file.dart';
import 'package:mason_logger/mason_logger.dart';
import 'package:pub_semver/pub_semver.dart';
import 'package:yaml/yaml.dart';
import 'package:yaml_edit/yaml_edit.dart';

enum VersionBump {
  patch,
  minor,
  major,
  breaking,
}

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
    VersionBump versionBump = VersionBump.breaking,
    bool dryRun = false,
  }) {
    final file = fs.file(path);

    if (!file.existsSync()) {
      return false;
    }

    final content = file.readAsStringSync();

    final result = applyConstraintsTo(
      content,
      versionBump: versionBump,
      additionalKeys: [
        if (includeDevDependencies) 'dev_dependencies',
      ],
    );

    if (result == null) {
      return false;
    }

    if (dryRun) {
      return true;
    }

    file.writeAsStringSync(result);

    return true;
  }

  String? applyConstraintsTo(
    String content, {
    Iterable<String> additionalKeys = const [],
    VersionBump versionBump = VersionBump.breaking,
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
          final depConstraint = constraint(name, version, versionBump);

          if (depConstraint == null) continue;
          if (depConstraint.version == version) continue;

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

  ({dynamic name, dynamic version})? constraint(
    dynamic name,
    dynamic version, [
    VersionBump versionBump = VersionBump.breaking,
  ]) {
    if (name is! String || version is! String) {
      return null;
    }

    Version semVersion;

    final minVersion = RegExp(r'^\^');
    final rangedVersion = RegExp(r'^\>\=?([\d.+-\w]+)');

    final sanitized = switch (version) {
      _ when minVersion.hasMatch(version) => version.replaceFirst('^', ''),
      _ when rangedVersion.hasMatch(version) =>
        rangedVersion.firstMatch(version)?.group(1) ?? version,
      _ => version,
    };

    try {
      semVersion = Version.parse(sanitized);
    } on FormatException {
      return null;
    }

    final nextVersion = switch (versionBump) {
      VersionBump.patch => semVersion.nextPatch,
      VersionBump.minor => semVersion.nextMinor,
      VersionBump.major => semVersion.nextMajor,
      VersionBump.breaking => semVersion.nextBreaking,
    };

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