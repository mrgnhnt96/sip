enum Level {
  verbose,
  debug,
  normal;

  bool get isVerbose {
    return this == Level.verbose;
  }

  bool get isDebug {
    return this == Level.debug;
  }

  bool get isNormal {
    return this == Level.normal;
  }
}
