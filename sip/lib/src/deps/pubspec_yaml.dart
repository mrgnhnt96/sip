import 'package:scoped_deps/scoped_deps.dart';
import 'package:sip_cli/src/domain/pubspec_yaml.dart';

final pubspecYamlProvider = create<PubspecYaml>(PubspecYaml.new);

PubspecYaml get pubspecYaml => read(pubspecYamlProvider);
