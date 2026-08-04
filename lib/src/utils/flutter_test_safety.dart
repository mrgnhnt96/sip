/// Safety pre-checks for combining Flutter widget-test files into a single
/// shared isolate (see `Package.bucketPlan`).
///
/// A file that fails either check must run alone, never combined with other
/// files:
///  - Binding-class check: `LiveTestWidgetsFlutterBinding` /
///    `IntegrationTestWidgetsFlutterBinding` (or any other explicit
///    non-default `TestWidgetsFlutterBinding` subtype) hard-asserts if it
///    isn't the first binding initialized in the isolate, which combining
///    would violate.
///  - Surface-mutation check: `tester.view.physicalSize`/`.devicePixelRatio`/
///    `binding.setSurfaceSize(...)` mutate process-global test-surface state.
///    Without a matching reset, that mutation leaks into whatever else
///    shares the isolate once combined.
abstract final class FlutterTestSafety {
  static const unsafeBindingPatterns = <String>[
    'LiveTestWidgetsFlutterBinding',
    'IntegrationTestWidgetsFlutterBinding',
  ];

  /// Any `<Prefix>TestWidgetsFlutterBinding` identifier is suspect *unless*
  /// it's the bare default (`TestWidgetsFlutterBinding`, which resolves to
  /// the safe `AutomatedTestWidgetsFlutterBinding` under `flutter test`) or
  /// an explicit `AutomatedTestWidgetsFlutterBinding` reference.
  static final _anyBindingClassRegex = RegExp(
    r'\b([A-Za-z]*TestWidgetsFlutterBinding)\b',
  );

  static const _safeBindingNames = <String>{
    'TestWidgetsFlutterBinding',
    'AutomatedTestWidgetsFlutterBinding',
  };

  static final _surfaceMutationRegex = RegExp(
    r'\.view\.physicalSize\s*=|\.view\.devicePixelRatio\s*=|\.setSurfaceSize\s*\(',
  );

  static final _surfaceResetRegex = RegExp(
    r'resetPhysicalSize|resetDevicePixelRatio|setSurfaceSize\s*\(\s*null\s*\)',
  );

  /// Returns true if [content] is safe to combine into a shared bucket file.
  static bool isCombinable(String content) {
    for (final pattern in unsafeBindingPatterns) {
      if (content.contains(pattern)) return false;
    }

    for (final match in _anyBindingClassRegex.allMatches(content)) {
      final name = match.group(1)!;
      if (!_safeBindingNames.contains(name)) return false;
    }

    if (_surfaceMutationRegex.hasMatch(content) &&
        !_surfaceResetRegex.hasMatch(content)) {
      return false;
    }

    return true;
  }

  /// Human-readable reason [content] was routed to solo execution, for
  /// reporting purposes. Only meaningful when [isCombinable] is false.
  static String soloReason(String content) {
    for (final pattern in unsafeBindingPatterns) {
      if (content.contains(pattern)) return 'uses $pattern';
    }

    for (final match in _anyBindingClassRegex.allMatches(content)) {
      final name = match.group(1)!;
      if (!_safeBindingNames.contains(name)) return 'uses $name';
    }

    if (_surfaceMutationRegex.hasMatch(content) &&
        !_surfaceResetRegex.hasMatch(content)) {
      return 'mutates the test surface '
          '(physicalSize/devicePixelRatio/setSurfaceSize) without a reset';
    }

    return 'unknown';
  }
}
