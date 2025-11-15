import 'package:sip_cli/src/deps/scripts_yaml.dart';

class Executables {
  const Executables({
    required this.dart,
    required this.flutter,
    required this.all,
  });

  factory Executables.load() {
    return Executables.fromJson(scriptsYaml.executables() ?? {});
  }

  factory Executables.fromJson(Map<String, dynamic> json) {
    return Executables(
      dart: switch (json['dart']) {
        final String dart => dart,
        _ => null,
      },
      flutter: switch (json['flutter']) {
        final String flutter => flutter,
        _ => null,
      },
      all: {
        for (final MapEntry(:key, :value) in json.entries)
          if ((key.trim(), value) case (final String key, final String value))
            if (key != 'dart' && key != 'flutter') key: value.trim(),
      },
    );
  }

  final String? dart;
  final String? flutter;
  final Map<String, String> all;

  Map<String, dynamic> toJson() {
    return {'dart': dart, 'flutter': flutter};
  }
}
