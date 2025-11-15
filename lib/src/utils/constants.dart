import 'package:sip_cli/src/deps/platform.dart';

/// The keys that are used in the scripts.yaml file
class Keys {
  const Keys._();

  static const String bail = '(bail)';
  static const String env = '(env)';
  static const String aliases = '(aliases)';
  static const String description = '(description)';
  static const String command = '(command)';
  static const String variables = '(variables)';
  static const String executables = '(executables)';

  static const List<String> scriptParameters = [
    aliases,
    description,
    command,
    bail,
    env,
  ];

  static const Set<String> nonScriptKeys = {variables, executables};
}

/// The variables that can be used in the scripts
class Vars {
  const Vars._();

  static const String projectRoot = 'projectRoot';
  static const String scriptsRoot = 'scriptsRoot';
  static const String cwd = 'cwd';
  static const String dartOrFlutter = 'dartOrFlutter';
  static const String dart = 'dart';
  static const String flutter = 'flutter';

  static const Set<String> values = {
    projectRoot,
    scriptsRoot,
    cwd,
    dartOrFlutter,
    dart,
    flutter,
  };
}

class Identifiers {
  const Identifiers._();

  static const String concurrent = '(+) ';
}

class Env {
  const Env._();

  static const String _sipCliScript = 'SIP_CLI_SCRIPT';

  static ({String name, bool isSet}) get sipCliScript => (
    name: _sipCliScript,
    isSet: platform.environment.containsKey(_sipCliScript),
  );
}
