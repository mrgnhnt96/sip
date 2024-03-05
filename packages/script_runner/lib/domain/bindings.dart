/// The bindings for the script runner
///
/// This is the interface that the script runner
/// uses to interact with the outside (rust) world
abstract interface class Bindings {
  const Bindings();

  Future<int> runScript(String script, {bool showOutput});
}
