import 'package:equatable/equatable.dart';
import 'package:sip_cli/utils/constants.dart';

part 'env_config.g.dart';

class EnvConfig extends Equatable {
  const EnvConfig({
    required this.commands,
    required this.files,
    required this.workingDirectory,
  });
  const EnvConfig.empty()
      : commands = const [],
        files = const [],
        workingDirectory = '';

  final Iterable<String>? files;
  final Iterable<String>? commands;
  final String workingDirectory;

  @override
  List<Object?> get props => _$props;
}

extension CombineEnvConfigEnvConfigX on Iterable<EnvConfig?> {
  EnvConfig? combine({required String directory}) {
    final commands = <String>{};
    final files = <String>{};

    for (final config in this) {
      if (config == null) continue;

      for (var command in config.commands ?? <String>[]) {
        while (command.startsWith(Identifiers.concurrent)) {
          command = command.substring(Identifiers.concurrent.length);
        }

        commands.add(command);
      }

      files.addAll(config.files ?? []);
    }

    if (commands.isEmpty && files.isEmpty) return null;

    return EnvConfig(
      commands: commands,
      files: files,
      workingDirectory: directory,
    );
  }
}
