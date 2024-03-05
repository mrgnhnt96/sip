import 'package:sip_console/domain/print/print.dart';
import 'package:sip_console/utils/ansi.dart';

/// A print that prints a warn message.
class PrintWarn extends Print {
  PrintWarn()
      : super(
          group: const Group(
            tag: '⚠',
            color: lightYellow,
          ),
        );
}
