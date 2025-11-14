import 'package:path/path.dart' as p;
import 'package:sip_cli/src/utils/package.dart';

class PackageToTest {
  PackageToTest({
    required this.pkg,
    required String packagePath,
    this.optimizedPath,
  }) {
    final segments = p.split(packagePath);
    this.packagePath = switch (packagePath) {
      _ when segments.contains('test') => p.joinAll(
        segments.takeWhile((e) => e != 'test'),
      ),
      _ when segments.contains('lib') => p.joinAll(
        segments.takeWhile((e) => e != 'lib'),
      ),
      _ => packagePath,
    };
  }

  final Package pkg;
  late final String packagePath;
  String? optimizedPath;

  @override
  String toString() {
    return '(packagePath: $packagePath, optimizedPath: $optimizedPath)';
  }
}
