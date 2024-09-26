import 'package:path/path.dart' as p;
import 'package:sip_cli/utils/determine_flutter_or_dart.dart';

class PackageToTest {
  PackageToTest({
    required this.tool,
    required String packagePath,
    this.optimizedPath,
  }) {
    this.packagePath = switch (packagePath) {
      _ when packagePath.contains('${p.separator}test') =>
        packagePath.split('${p.separator}test').first,
      _ when packagePath.contains('${p.separator}lib') =>
        packagePath.split('${p.separator}lib').first,
      _ => packagePath,
    };
  }

  final DetermineFlutterOrDart tool;
  late final String packagePath;
  String? optimizedPath;
}
