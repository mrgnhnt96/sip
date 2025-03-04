import 'package:path/path.dart' as p;
import 'package:sip_cli/utils/determine_flutter_or_dart.dart';

class PackageToTest {
  PackageToTest({
    required this.tool,
    required String packagePath,
    this.optimizedPath,
  }) {
    final segments = p.split(packagePath);
    this.packagePath = switch (packagePath) {
      _ when segments.contains('test') =>
        p.joinAll(segments.takeWhile((e) => e != 'test')),
      _ when segments.contains('lib') =>
        p.joinAll(segments.takeWhile((e) => e != 'lib')),
      _ => packagePath,
    };
  }

  final DetermineFlutterOrDart tool;
  late final String packagePath;
  String? optimizedPath;

  @override
  String toString() {
    return '(packagePath: $packagePath, optimizedPath: $optimizedPath)';
  }
}
