This folder contains the custom TensorFlow Lite model and labels used by the app.

Expected files:
- model_unquant (1).tflite  -> TFLite model for fashion item classification
- labels.txt                -> One label per line, e.g. "hat", "watch", etc.

The app loads these files via the Flutter asset system. Make sure the paths
match what is configured in pubspec.yaml.


