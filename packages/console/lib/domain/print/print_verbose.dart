import 'package:sip_console/domain/print/print.dart';
import 'package:sip_console/utils/ansi.dart';

/// A print that prints a verbose message.
class PrintVerbose extends Print {
  PrintVerbose()
      : super(
          group: Group(
            tag: '[V]',
            color: lightBlue,
          ),
        );
}
