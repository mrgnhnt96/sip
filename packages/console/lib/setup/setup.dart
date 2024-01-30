import 'package:dart_console2/dart_console2.dart';
import 'package:get_it/get_it.dart';

late GetIt getIt;

GetIt setup([GetIt? get]) {
  getIt = get ?? GetIt.asNewInstance();

  getIt.registerLazySingleton<Console>(Console.new);

  return getIt;
}
