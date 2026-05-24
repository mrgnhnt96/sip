import 'dart:io';

void main() {
  final value = Platform.environment['SIP_SMOKE'];

  if (value != 'ok') {
    stderr.writeln('Expected SIP_SMOKE=ok, got: $value');
    exit(1);
  }

  stdout.writeln('env ok');
}
