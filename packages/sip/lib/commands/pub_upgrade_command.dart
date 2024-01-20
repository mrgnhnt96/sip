import 'package:sip/commands/a_pub_command.dart';
import 'package:sip/domain/pubspec_lock_impl.dart';
import 'package:sip/domain/pubspec_yaml_impl.dart';

class PubUpgradeCommand extends APubGetCommand {
  PubUpgradeCommand({
    super.pubspecLock = const PubspecLockImpl(),
    super.pubspecYaml = const PubspecYamlImpl(),
  }) {}

  @override
  String get name => 'upgrade';
}
