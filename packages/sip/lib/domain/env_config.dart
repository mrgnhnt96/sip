import 'package:equatable/equatable.dart';

part 'env_config.g.dart';

class EnvConfig extends Equatable {
  const EnvConfig({
    required this.commands,
    required this.files,
    required String this.workingDirectory,
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
