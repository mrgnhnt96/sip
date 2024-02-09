import 'package:args/args.dart';
import 'package:file/file.dart';
import 'package:file/local.dart';
import 'package:sip_cli/setup/setup.dart' as sip;
import 'package:sip_cli/sip_runner.dart';
import 'package:sip_console/domain/level.dart';

void main(List<String> args) {
  final parser = ArgParser()..addFlag('debug', negatable: false);
  final results = parser.parse(args);

  var level = Level.normal;

  if (results['debug'] as bool) {
    // remove the debug flag from the args
    args = args.where((arg) => arg != '--debug').toList();
    level = Level.debug;
    print('Debug mode enabled');
  }

  sip.setup(level: level);

  sip.getIt.registerLazySingleton<FileSystem>(LocalFileSystem.new);

  final runner = SipRunner();

  runner.run(args);
}
