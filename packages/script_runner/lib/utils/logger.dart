typedef Log = void Function(String);

class Logger {
  static void setup({
    required Log detail,
    required Log err,
    required Log warn,
    required Log write,
  }) {
    Logger._detail = detail;
    Logger._err = err;
    Logger._warn = warn;
    Logger._write = write;
  }

  static Log? _detail;
  static Log? _err;
  static Log? _warn;
  static Log? _write;

  static Log get detail => _detail ?? (_) => {};
  static Log get err => _err ?? (_) => {};
  static Log get warn => _warn ?? (_) => {};
  static Log get write => _write ?? (_) => {};
}
