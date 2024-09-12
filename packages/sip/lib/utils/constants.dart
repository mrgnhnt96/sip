/// The keys that are used in the scripts.yaml file
class Keys {
  const Keys._();

  static const String bail = '(bail)';
  static const String env = '(env)';
  static const String aliases = '(aliases)';
  static const String description = '(description)';
  static const String command = '(command)';
  static const String variables = '(variables)';
  static const String name = '__(name)__';
  static const String parents = '__(parents)__';

  static const List<String> scriptParameters = [
    aliases,
    description,
    command,
    bail,
    name,
    env,
  ];
}

/// The variables that can be used in the scripts
class Vars {
  const Vars._();

  static const String projectRoot = 'projectRoot';
  static const String scriptsRoot = 'scriptsRoot';
  static const String cwd = 'cwd';

  static const Set<String> values = {projectRoot, scriptsRoot, cwd};
}

class Identifiers {
  const Identifiers._();

  static const String concurrent = '(+) ';
}
