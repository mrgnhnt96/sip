import 'package:sip/commands/a_pub_command.dart';
import 'package:sip/domain/pubspec_lock_impl.dart';
import 'package:sip/domain/pubspec_yaml_impl.dart';

class PubGetCommand extends APubGetCommand {
  PubGetCommand({
    super.pubspecLock = const PubspecLockImpl(),
    super.pubspecYaml = const PubspecYamlImpl(),
  }) {
    argParser.addFlag(
      'offline',
      help: 'Use cached packages instead of accessing the network.',
    );

    argParser.addFlag(
      'dry-run',
      abbr: 'n',
      negatable: false,
      help: "Report what dependencies would change but don't change any.",
    );

    argParser.addFlag(
      'enforce-lockfile',
      negatable: false,
      help:
          'Enforce pubspec.lock. Fail resolution if pubspec.lock does not satisfy pubspec.yaml',
    );

    argParser.addFlag(
      'precompile',
      help: 'Build executables in immediate dependencies.',
    );
  }

  @override
  String get name => 'get';

  @override
  List<String> get pubFlags => [
        if (argResults!['offline'] as bool) '--offline',
        if (argResults!['dry-run'] as bool) '--dry-run',
        if (argResults!['enforce-lockfile'] as bool) '--enforce-lockfile',
        if (argResults!['precompile'] as bool) '--precompile',
      ];
}
