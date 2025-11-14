import 'package:sip_cli/src/deps/scripts_yaml.dart';

class Executables {
  const Executables({required this.dart, required this.flutter});

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
    );
  }

  final String? dart;
  final String? flutter;

  Map<String, dynamic> toJson() {
    return {'dart': dart, 'flutter': flutter};
  }
}
