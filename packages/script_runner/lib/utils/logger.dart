typedef Log = void Function(String);

class Logger {
  static void setup({
    required Log detail,
    required Log err,
    required Log warn,
  }) {
    Logger._detail = detail;
    Logger._err = err;
    Logger._warn = warn;
  }

  static Log? _detail;
  static Log? _err;
  static Log? _warn;

  static Log get detail => _detail ?? (_) => {};
  static Log get err => _err ?? (_) => {};
  static Log get warn => _warn ?? (_) => {};
}
