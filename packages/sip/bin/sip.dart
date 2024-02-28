import 'dart:io';

import 'package:file/file.dart';
import 'package:file/local.dart';
import 'package:get_it/get_it.dart';
import 'package:sip_cli/setup/setup.dart' as sip;
import 'package:sip_cli/sip_runner.dart';
import 'package:sip_console/domain/level.dart';
import 'package:sip_console/sip_console.dart';
import 'package:sip_console/sip_console_setup.dart' as console;

void main(List<String> _) async {
  final args = List<String>.from(_);
  final hasDebug = args.remove('--debug');

  var level = Level.normal;

  if (hasDebug) {
    level = Level.debug;
    print('Debug mode enabled');
  }

  final getIt = GetIt.asNewInstance();

  getIt.registerLazySingleton<FileSystem>(LocalFileSystem.new);

  sip.setup(getIt);
  console.setup(getIt, level);

  final exitCode = await SipRunner().run(args);

  sip.getIt<SipConsole>().v('[$args] Finishing with: $exitCode');

  exit(exitCode.code);
}
