import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;

import 'config.dart';

/// Thrown when the API cannot return a prediction. [message] is shown to
/// the user as-is.
class PredictionException implements Exception {
  PredictionException(this.message);
  final String message;

  @override
  String toString() => message;
}

class ApiService {
  ApiService({http.Client? client}) : _client = client ?? http.Client();

  final http.Client _client;

  // A free Render service can take up to a minute to wake from sleep.
  static const Duration _timeout = Duration(seconds: 90);

  /// Sends [inputs] to POST /predict and returns the predicted value.
  Future<double> predict(Map<String, dynamic> inputs) async {
    final uri = Uri.parse('$apiBaseUrl/predict');

    final http.Response response;
    try {
      response = await _client
          .post(
            uri,
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode(inputs),
          )
          .timeout(_timeout);
    } on TimeoutException {
      throw PredictionException(
          'The server took too long to respond. Please try again.');
    } on SocketException {
      throw PredictionException(
          'Could not reach the server. Check your internet connection.');
    } on http.ClientException {
      throw PredictionException('Could not reach the server.');
    }

    final dynamic body = _decode(response.body);

    if (response.statusCode == 200) {
      final value = body is Map ? body['prediction'] : null;
      if (value is num) return value.toDouble();
      throw PredictionException('The server returned an unexpected response.');
    }

    if (response.statusCode == 422) {
      throw PredictionException(_validationMessage(body));
    }

    final detail = body is Map ? body['detail'] : null;
    throw PredictionException(detail is String
        ? detail
        : 'Server error (${response.statusCode}). Please try again.');
  }

  dynamic _decode(String text) {
    try {
      return jsonDecode(text);
    } on FormatException {
      return null;
    }
  }

  /// Turns FastAPI's 422 body into readable lines, e.g.
  /// "Example number: Input should be less than or equal to 100".
  String _validationMessage(dynamic body) {
    final detail = body is Map ? body['detail'] : null;
    if (detail is! List || detail.isEmpty) {
      return 'Some inputs are invalid. Please check your values.';
    }

    final labels = {for (final f in inputFields) f.key: f.label};
    final lines = <String>[];
    for (final error in detail) {
      if (error is! Map) continue;
      final loc = error['loc'];
      final key = loc is List && loc.isNotEmpty ? loc.last.toString() : '';
      final name = labels[key] ?? key;
      final msg = error['msg']?.toString() ?? 'Invalid value';
      lines.add(name.isEmpty ? msg : '$name: $msg');
    }
    return lines.join('\n');
  }
}
