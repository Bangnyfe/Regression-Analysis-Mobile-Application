/// App configuration: the API address and the model's input variables.
///
/// The prediction page builds one labelled text field per entry in
/// [inputFields], so this list must match the Pydantic request model in
/// summative/API/prediction.py field for field (same keys, types and ranges).
library;

/// Public base URL of the FastAPI service on Render (no trailing slash).
const String apiBaseUrl = 'https://nutrition-score-api.onrender.com';

/// Title shown in the app bar.
const String appTitle = 'Nutrition Score';

/// Label shown above the predicted value.
const String resultLabel = 'Predicted nutrition score';

/// Unit appended to the predicted value. Leave empty for none.
const String resultUnit = 'points';

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

const List<String> foodGroups = [
  'Beverages',
  'Cereals and potatoes',
  'Composite foods',
  'Fat and sauces',
  'Fish meat eggs',
  'Fruits and vegetables',
  'Milk and dairy products',
  'Salty snacks',
  'Sugary snacks',
];

/// The 11 values the model needs, all read from a food label (per 100 g).
const List<InputField> inputFields = [
  InputField(
    key: 'food_group',
    label: 'Food group',
    type: FieldType.text,
    allowedValues: foodGroups,
    hint: 'e.g. Sugary snacks',
  ),
  InputField(
    key: 'additives_n',
    label: 'Number of additives',
    type: FieldType.integer,
    min: 0,
    max: 30,
  ),
  InputField(
    key: 'palm_oil_ingredients_n',
    label: 'Palm oil ingredients',
    type: FieldType.integer,
    min: 0,
    max: 5,
  ),
  InputField(
    key: 'energy_kj',
    label: 'Energy (kJ per 100 g)',
    type: FieldType.decimal,
    min: 0,
    max: 3800,
  ),
  InputField(
    key: 'fat_g',
    label: 'Fat (g per 100 g)',
    type: FieldType.decimal,
    min: 0,
    max: 100,
  ),
  InputField(
    key: 'saturated_fat_g',
    label: 'Saturated fat (g per 100 g)',
    type: FieldType.decimal,
    min: 0,
    max: 100,
  ),
  InputField(
    key: 'carbohydrates_g',
    label: 'Carbohydrates (g per 100 g)',
    type: FieldType.decimal,
    min: 0,
    max: 100,
  ),
  InputField(
    key: 'sugars_g',
    label: 'Sugars (g per 100 g)',
    type: FieldType.decimal,
    min: 0,
    max: 100,
  ),
  InputField(
    key: 'fiber_g',
    label: 'Fibre (g per 100 g)',
    type: FieldType.decimal,
    min: 0,
    max: 100,
  ),
  InputField(
    key: 'proteins_g',
    label: 'Protein (g per 100 g)',
    type: FieldType.decimal,
    min: 0,
    max: 100,
  ),
  InputField(
    key: 'salt_g',
    label: 'Salt (g per 100 g)',
    type: FieldType.decimal,
    min: 0,
    max: 100,
  ),
];
