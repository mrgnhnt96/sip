import 'package:sip_console/domain/print/print.dart';
import 'package:sip_console/utils/ansi.dart';

/// A print that prints an error message.
class PrintError extends Print {
  PrintError()
      : super(
          group: Group(
            tag: '✖',
            color: lightRed,
          ),
        );
}
