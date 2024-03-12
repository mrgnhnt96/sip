enum RunTests {
  package,
  modified,
  all;

  const RunTests();

  bool get isModified => this == RunTests.modified;
  bool get isAll => this == RunTests.all;

  String get title {
    switch (this) {
      case RunTests.package:
        return 'package tests';
      case RunTests.modified:
        return 'test file';
      case RunTests.all:
        return 'all tests';
    }
  }

  String get option {
    switch (this) {
      case RunTests.package:
        return 'package';
      case RunTests.modified:
        return 'file';
      case RunTests.all:
        return 'all';
    }
  }

  String get help {
    switch (this) {
      case RunTests.package:
        return 'Run package tests with the most recent changed file';
      case RunTests.modified:
        return 'Run the test file associated with the most recent changed file';
      case RunTests.all:
        return 'Run all tests in all packages';
    }
  }

  static RunTests toggle(RunTests runType) {
    final index = RunTests.values.indexOf(runType);

    return RunTests.values[index == RunTests.values.length - 1 ? 0 : index + 1];
  }

  static Map<String, RunTests> get options {
    return {
      for (final val in RunTests.values) val.option: val,
    };
  }
}
