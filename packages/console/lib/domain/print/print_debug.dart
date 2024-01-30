import 'package:sip_console/domain/print/print.dart';
import 'package:sip_console/utils/ansi.dart';

/// A print that prints a debug message.
class PrintDebug extends Print {
  PrintDebug()
      : super(
          group: Group(
            tag: '[D]',
            color: lightCyan,
          ),
        );
}
