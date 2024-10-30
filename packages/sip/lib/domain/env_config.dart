import 'package:equatable/equatable.dart';

part 'env_config.g.dart';

class EnvConfig extends Equatable {
  const EnvConfig({
    required this.commands,
    required this.files,
  });
  const EnvConfig.empty() : this(commands: const {}, files: const {});

  final Iterable<String>? files;
  final Iterable<String>? commands;

  @override
  List<Object?> get props => _$props;
}
