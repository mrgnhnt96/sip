enum TestScope {
  active,
  file,
  all;

  const TestScope();

  bool get isModified => this == TestScope.file;
  bool get isAll => this == TestScope.all;

  String get option => name;

  String get help {
    switch (this) {
      case TestScope.active:
        return 'Run tests in the active package, '
            'based on the most recent changed file';
      case TestScope.file:
        return 'Run the test file associated with the most recent changed file';
      case TestScope.all:
        return 'Run all tests in the project';
    }
  }

  static TestScope toggle(TestScope runType) {
    final index = TestScope.values.indexOf(runType);

    return TestScope.values[index == TestScope.values.length - 1
        ? 0
        : index + 1];
  }

  static Map<String, TestScope> get options {
    return {for (final val in TestScope.values) val.option: val};
  }
}
