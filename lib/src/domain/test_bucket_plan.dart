/// A generated combined test file and the original (package-relative) test
/// files that were folded into it.
class TestBucket {
  const TestBucket({required this.file, required this.originalFiles});

  /// Path to the generated combined file, relative to the package root.
  final String file;

  /// Paths of the original test files combined into [file], relative to the
  /// package root, in the same order they appear in the generated file.
  final List<String> originalFiles;
}

/// The result of planning how to bucket a Flutter package's test files:
/// which files were safely combined into [buckets], and which files were
/// routed to [soloFiles] (run individually, never combined) because they
/// failed a safety pre-check.
class TestBucketPlan {
  const TestBucketPlan({
    required this.buckets,
    required this.soloFiles,
    required this.soloReasons,
  });

  final List<TestBucket> buckets;

  /// Paths relative to the package root.
  final List<String> soloFiles;

  /// Maps a solo file's path (relative to the package root) to the reason
  /// it couldn't be safely combined, for reporting purposes.
  final Map<String, String> soloReasons;
}
