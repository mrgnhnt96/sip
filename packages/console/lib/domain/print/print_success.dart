import 'package:sip_console/domain/print/print.dart';
import 'package:sip_console/utils/ansi.dart';

/// A print that prints a success message.
class PrintSuccess extends Print {
  PrintSuccess()
      : super(
            group: Group(
          tag: '✔',
          color: lightGreen,
        ));
}
