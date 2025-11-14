import 'package:sip_cli/src/deps/logger.dart';

mixin DartOrFlutterMixin {
  void warnDartOrFlutter({
    required bool isFlutterOnly,
    required bool isDartOnly,
  }) {
    if (isDartOnly || isFlutterOnly) {
      if (isDartOnly && !isFlutterOnly) {
        logger.info('Running only in dart packages');
      } else if (isFlutterOnly && !isDartOnly) {
        logger.info('Running only in flutter packages');
      } else {
        logger.info('Running both dart and flutter');
      }
    }
  }
}
