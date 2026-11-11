class Interpreter {
  static Future<Interpreter> fromAsset(String assetName) async {
    throw UnsupportedError('On-device model scanning is not available on web.');
  }

  int get address => 0;

  void close() {}
}

class IsolateInterpreter {
  static Future<IsolateInterpreter> create({
    required int address,
    String debugName = 'TfLiteInterpreterIsolate',
  }) async {
    throw UnsupportedError('On-device model scanning is not available on web.');
  }

  Future<void> run(Object input, Object output) async {
    throw UnsupportedError('On-device model scanning is not available on web.');
  }

  Future<void> runForMultipleInputs(
    List<Object> inputs,
    Map<int, Object> outputs,
  ) async {
    throw UnsupportedError('On-device model scanning is not available on web.');
  }

  Future<void> close() async {}
}
