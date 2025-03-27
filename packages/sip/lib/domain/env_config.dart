import 'package:equatable/equatable.dart';
import 'package:sip_cli/utils/constants.dart';

part 'env_config.g.dart';

class EnvConfig extends Equatable {
  const EnvConfig({
    required this.commands,
    required this.files,
    required this.workingDirectory,
    required this.variables,
  });

  const EnvConfig.empty()
      : commands = const [],
        files = const [],
        workingDirectory = '',
        variables = const {};

  final Iterable<String>? files;
  final Iterable<String>? commands;
  final String workingDirectory;
  final Map<String, String>? variables;

  @override
  List<Object?> get props => _$props;

  EnvConfig? forceVariableOverride(Map<String, String>? variables) {
    final newVariables = <String, String>{
      ...?this.variables,
      ...?variables,
    };

    return EnvConfig(
      commands: commands,
      files: files,
      workingDirectory: workingDirectory,
      variables: newVariables,
    );
  }
}

extension CombineEnvConfigEnvConfigX on Iterable<EnvConfig?> {
  EnvConfig? combine({required String directory}) {
    final commands = <String>{};
    final files = <String>{};
    final variables = <String, String>{};

    for (final config in this) {
      if (config == null) continue;

      for (var command in config.commands ?? <String>[]) {
        while (command.startsWith(Identifiers.concurrent)) {
          command = command.substring(Identifiers.concurrent.length);
        }

        commands.add(command);
      }

      files.addAll(config.files ?? []);

      if (config.variables case final Map<String, String> vars
          when vars.isNotEmpty) {
        variables.addAll(vars);
      }
    }

    if (commands.isEmpty && files.isEmpty && variables.isEmpty) {
      return null;
    }

    return EnvConfig(
      commands: commands,
      files: files,
      workingDirectory: directory,
      variables: variables,
    );
  }
}
