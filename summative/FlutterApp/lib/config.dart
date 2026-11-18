/// App configuration: the API address and the model's input variables.
///
/// The prediction page builds one labelled text field per entry in
/// [inputFields], so this list must match the Pydantic request model in
/// summative/API/prediction.py field for field (same keys, types and ranges).
library;

/// Public base URL of the FastAPI service on Render (no trailing slash).
const String apiBaseUrl = 'https://your-service.onrender.com';

/// Title shown in the app bar.
const String appTitle = 'Prediction';

/// Label shown above the predicted value.
const String resultLabel = 'Predicted value';

/// Unit appended to the predicted value, e.g. 'kg/ha'. Leave empty for none.
const String resultUnit = '';

enum FieldType { integer, decimal, text }

class InputField {
  const InputField({
    required this.key,
    required this.label,
    required this.type,
    this.min,
    this.max,
    this.allowedValues,
    this.hint,
  });

  /// JSON key sent to the API. Must equal the Pydantic field name.
  final String key;

  /// Human-readable label shown on the text field.
  final String label;

  final FieldType type;

  /// Inclusive numeric bounds (numeric fields only).
  final num? min;
  final num? max;

  /// Accepted values for categorical (text) fields.
  final List<String>? allowedValues;

  /// Optional hint text inside the field.
  final String? hint;
}

// TODO: replace these placeholders with the dataset's real input variables.
const List<InputField> inputFields = [
  InputField(
    key: 'example_number',
    label: 'Example number',
    type: FieldType.decimal,
    min: 0,
    max: 100,
  ),
  InputField(
    key: 'example_count',
    label: 'Example count',
    type: FieldType.integer,
    min: 0,
    max: 10,
  ),
  InputField(
    key: 'example_category',
    label: 'Example category',
    type: FieldType.text,
    allowedValues: ['A', 'B', 'C'],
  ),
];
