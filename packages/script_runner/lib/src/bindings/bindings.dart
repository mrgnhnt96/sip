abstract interface class Bindings {
  const Bindings();

  Future<int> runScript(String script, {bool showOutput});
}
