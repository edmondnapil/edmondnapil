// Stub file for web platform - tflite_flutter doesn't support web
class Interpreter {
  Interpreter._();
  static Future<Interpreter> fromAsset(String asset) {
    throw UnsupportedError('TFLite is not supported on web platform');
  }
  void close() {}
  dynamic getInputTensor(int index) => null;
  void run(dynamic input, dynamic output) {}
}

