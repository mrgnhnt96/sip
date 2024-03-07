// ignore_for_file: cascade_invocations

import 'dart:io';

import 'package:file/file.dart';
import 'package:file/local.dart';
import 'package:get_it/get_it.dart';
import 'package:sip_cli/setup/setup.dart' as sip;
import 'package:sip_cli/domain/cwd_impl.dart';
import 'package:sip_cli/domain/find_file.dart';
import 'package:sip_cli/domain/pubspec_lock_impl.dart';
import 'package:sip_cli/domain/pubspec_yaml_impl.dart';
import 'package:sip_cli/domain/scripts_yaml_impl.dart';
import 'package:sip_cli/sip_runner.dart';
import 'package:sip_console/sip_console.dart';
import 'package:sip_console/sip_console_setup.dart' as console;
import 'package:sip_script_runner/sip_script_runner.dart';

void main(List<String> _) async {
  final args = List<String>.from(_);

  final getIt = GetIt.asNewInstance();

  getIt.registerLazySingleton<FileSystem>(LocalFileSystem.new);

  console.setup(getIt);

  const scriptsYaml = ScriptsYamlImpl();
  const pubspecYaml = PubspecYamlImpl();

  final exitCode = await SipRunner(
    bindings: const BindingsImpl(),
    scriptsYaml: scriptsYaml,
    findFile: const FindFile(),
    pubspecLock: const PubspecLockImpl(),
    pubspecYaml: pubspecYaml,
    variables: const Variables(
      cwd: CWDImpl(),
      pubspecYaml: pubspecYaml,
      scriptsYaml: scriptsYaml,
    ),
  ).run(args);

  sip.getIt<SipConsole>().v('[$args] Finishing with: $exitCode');

  exit(exitCode.code);
}
