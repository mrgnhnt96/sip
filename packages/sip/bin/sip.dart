import 'package:file/file.dart';
import 'package:file/local.dart';
import 'package:sip/setup/setup.dart';
import 'package:sip/sip_runner.dart';

void main(List<String> args) {
  setup();

  getIt..registerLazySingleton<FileSystem>(LocalFileSystem.new);

  final runner = SipRunner();

  runner.run(args);
}
