import 'package:flutter/material.dart';

import 'api_service.dart';
import 'config.dart';

class PredictionPage extends StatefulWidget {
  const PredictionPage({super.key, this.api});

  final ApiService? api;

  @override
  State<PredictionPage> createState() => _PredictionPageState();
}

class _PredictionPageState extends State<PredictionPage> {
  late final ApiService _api = widget.api ?? ApiService();
  late final Map<String, TextEditingController> _controllers = {
    for (final field in inputFields) field.key: TextEditingController(),
  };

  bool _loading = false;
  PredictionResult? _prediction;
  String? _error;

  @override
  void dispose() {
    for (final c in _controllers.values) {
      c.dispose();
    }
    super.dispose();
  }

  /// Checks one field. Returns an error message, or null when the value is valid.
  String? _check(InputField field, String raw) {
    final text = raw.trim();
    if (text.isEmpty) return '${field.label} is required.';

    switch (field.type) {
      case FieldType.integer:
        final value = int.tryParse(text);
        if (value == null) return '${field.label} must be a whole number.';
        return _checkRange(field, value);
      case FieldType.decimal:
        final value = double.tryParse(text);
        if (value == null) return '${field.label} must be a number.';
        return _checkRange(field, value);
      case FieldType.text:
        final allowed = field.allowedValues;
        if (allowed != null && _matchAllowed(allowed, text) == null) {
          return '${field.label} must be one of: ${allowed.join(', ')}.';
        }
        return null;
    }
  }

  /// Finds the allowed value that matches [text], ignoring upper/lower case,
  /// so "sugary snacks" is sent to the API as "Sugary snacks".
  String? _matchAllowed(List<String> allowed, String text) {
    for (final value in allowed) {
      if (value.toLowerCase() == text.toLowerCase()) return value;
    }
    return null;
  }

  String? _checkRange(InputField field, num value) {
    final min = field.min;
    final max = field.max;
    if ((min != null && value < min) || (max != null && value > max)) {
      return '${field.label} must be between $min and $max.';
    }
    return null;
  }

  dynamic _parse(InputField field, String raw) {
    final text = raw.trim();
    return switch (field.type) {
      FieldType.integer => int.parse(text),
      FieldType.decimal => double.parse(text),
      FieldType.text => field.allowedValues == null
          ? text
          : _matchAllowed(field.allowedValues!, text)!,
    };
  }

  Future<void> _predict() async {
    FocusScope.of(context).unfocus();

    final errors = <String>[];
    for (final field in inputFields) {
      final error = _check(field, _controllers[field.key]!.text);
      if (error != null) errors.add(error);
    }
    if (errors.isNotEmpty) {
      setState(() {
        _prediction = null;
        _error = errors.join('\n');
      });
      return;
    }

    final inputs = {
      for (final field in inputFields)
        field.key: _parse(field, _controllers[field.key]!.text),
    };

    setState(() {
      _loading = true;
      _prediction = null;
      _error = null;
    });

    try {
      final value = await _api.predict(inputs);
      if (!mounted) return;
      setState(() => _prediction = value);
    } on PredictionException catch (e) {
      if (!mounted) return;
      setState(() => _error = e.message);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  String _hintFor(InputField field) {
    if (field.hint != null) return field.hint!;
    if (field.allowedValues != null) return field.allowedValues!.join(' / ');
    if (field.min != null && field.max != null) {
      return '${field.min} - ${field.max}';
    }
    return '';
  }

  TextInputType _keyboardFor(InputField field) => switch (field.type) {
        FieldType.integer => const TextInputType.numberWithOptions(signed: true),
        FieldType.decimal =>
          const TextInputType.numberWithOptions(decimal: true, signed: true),
        FieldType.text => TextInputType.text,
      };

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text(appTitle)),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            for (final (i, field) in inputFields.indexed) ...[
              TextField(
                key: ValueKey('field_${field.key}'),
                controller: _controllers[field.key],
                keyboardType: _keyboardFor(field),
                textInputAction: i == inputFields.length - 1
                    ? TextInputAction.done
                    : TextInputAction.next,
                onSubmitted: (_) {
                  if (i == inputFields.length - 1) _predict();
                },
                decoration: InputDecoration(
                  labelText: field.label,
                  hintText: _hintFor(field),
                  helperText: field.allowedValues == null
                      ? null
                      : 'Options: ${field.allowedValues!.join(', ')}',
                  helperMaxLines: 4,
                  border: const OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
            ],
            const SizedBox(height: 4),
            SizedBox(
              height: 48,
              child: FilledButton(
                onPressed: _loading ? null : _predict,
                child: _loading
                    ? const SizedBox(
                        width: 22,
                        height: 22,
                        child: CircularProgressIndicator(strokeWidth: 2.5),
                      )
                    : const Text('Predict'),
              ),
            ),
            const SizedBox(height: 16),
            _ResultArea(
              loading: _loading,
              prediction: _prediction,
              error: _error,
            ),
          ],
        ),
      ),
    );
  }
}

/// Single display area for the predicted value or a readable error.
class _ResultArea extends StatelessWidget {
  const _ResultArea({
    required this.loading,
    required this.prediction,
    required this.error,
  });

  final bool loading;
  final PredictionResult? prediction;
  final String? error;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    final isError = error != null;

    final Widget content;
    if (isError) {
      content = Text(
        error!,
        key: const ValueKey('result_error'),
        style: text.bodyLarge?.copyWith(color: scheme.onErrorContainer),
      );
    } else if (prediction != null) {
      final unit = resultUnit.isEmpty ? '' : ' $resultUnit';
      content = Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(resultLabel, style: text.labelLarge),
          const SizedBox(height: 4),
          Text(
            '${prediction!.score.toStringAsFixed(2)}$unit',
            key: const ValueKey('result_value'),
            style: text.headlineMedium?.copyWith(fontWeight: FontWeight.w600),
          ),
          if (prediction!.grade.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(
              'Nutri-Score grade: ${prediction!.grade}',
              key: const ValueKey('result_grade'),
              style: text.titleMedium,
            ),
          ],
          const SizedBox(height: 8),
          Text(
            'Scores run from about -15 to 40. Lower is healthier.',
            style: text.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
          ),
          if (prediction!.additivesWarning) ...[
            const SizedBox(height: 8),
            Text(
              'This product has 5 or more additives, a common sign of '
              'ultra-processed food.',
              key: const ValueKey('result_warning'),
              style: text.bodyMedium?.copyWith(color: scheme.error),
            ),
          ],
        ],
      );
    } else {
      content = Text(
        loading
            ? 'Getting prediction... (the server may take up to a minute to wake up)'
            : 'Fill in every field and press Predict.',
        style: text.bodyLarge?.copyWith(color: scheme.onSurfaceVariant),
      );
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isError
            ? scheme.errorContainer
            : scheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(12),
      ),
      child: content,
    );
  }
}
