import 'dart:io';

import 'package:file/file.dart';
import 'package:file/local.dart';
import 'package:sip_cli/setup/setup.dart' as sip;
import 'package:sip_cli/sip_runner.dart';
import 'package:sip_cli/utils/exit_code.dart';
import 'package:sip_console/domain/level.dart';
import 'package:sip_console/sip_console.dart';

void main(List<String> _) async {
  final args = List<String>.from(_);
  final hasDebug = args.remove('--debug');

  var level = Level.normal;

  if (hasDebug) {
    level = Level.debug;
    print('Debug mode enabled');
  }

  sip.setup(level: level);

  sip.getIt.registerLazySingleton<FileSystem>(LocalFileSystem.new);

  final exitCode = await SipRunner().run(args);

  sip.getIt<SipConsole>().v('[$args] Finishing with: $exitCode');

  exit(exitCode.code);
}
