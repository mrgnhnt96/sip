// ignore_for_file: cascade_invocations

import 'package:dart_console2/dart_console2.dart';
import 'package:get_it/get_it.dart';
import 'package:sip_console/domain/level.dart';
import 'package:sip_console/domain/sip_console.dart';

late GetIt getIt;

/// Sets up the dependencies for the console package
GetIt setup(GetIt getIt_, [Level? level]) {
  getIt = getIt_;

  getIt.registerLazySingleton<Console>(Console.new);
  getIt.registerLazySingleton<SipConsole>(
    () => SipConsole(level: level ?? Level.normal),
  );

  return getIt;
}
