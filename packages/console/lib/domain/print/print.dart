import 'package:dart_console2/dart_console2.dart';
import 'package:sip_console/setup/setup.dart';
import 'package:sip_console/utils/ansi.dart';

abstract class Print {
  const Print({
    required Group this.group,
  });
  const Print.noGroup() : group = null;

  final Group? group;

  void print(String message) {
    final console = getIt<Console>();

    final msg = group == null ? message : '$group $message';

    console.writeLine(msg);
  }
}

class Group {
  const Group({
    required this.tag,
    required this.color,
  });
  const Group.name(String this.tag) : color = null;

  final String? tag;
  final AnsiCode? color;

  @override
  String toString() {
    final tag = this.tag;
    if (tag == null) return '';

    final color = this.color;
    if (color == null) return tag;

    return color.wrap(tag) ?? tag;
  }
}
