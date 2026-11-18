import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:prediction_app/api_service.dart';
import 'package:prediction_app/config.dart';
import 'package:prediction_app/main.dart';
import 'package:prediction_app/prediction_page.dart';

/// A valid value for each configured field.
String validValue(InputField f) => switch (f.type) {
      FieldType.text => f.allowedValues?.first ?? 'x',
      _ => '${f.min ?? 0}',
    };

Future<void> fillAll(WidgetTester tester) async {
  for (final f in inputFields) {
    await tester.enterText(find.byKey(ValueKey('field_${f.key}')), validValue(f));
  }
}

Widget appWith(http.Client client) =>
    MaterialApp(home: PredictionPage(api: ApiService(client: client)));

void main() {
  testWidgets('shows one labelled field per input and a Predict button',
      (tester) async {
    await tester.pumpWidget(const PredictionApp());
    expect(find.byType(TextField), findsNWidgets(inputFields.length));
    for (final f in inputFields) {
      expect(find.text(f.label), findsOneWidget);
    }
    expect(find.text('Predict'), findsOneWidget);
  });

  testWidgets('missing values show an error without calling the API',
      (tester) async {
    var called = false;
    await tester.pumpWidget(appWith(MockClient((_) async {
      called = true;
      return http.Response('{}', 200);
    })));
    await tester.tap(find.text('Predict'));
    await tester.pump();
    expect(find.byKey(const ValueKey('result_error')), findsOneWidget);
    expect(called, isFalse);
  });

  testWidgets('valid inputs display the predicted value', (tester) async {
    await tester.pumpWidget(appWith(MockClient((req) async {
      final body = jsonDecode(req.body) as Map<String, dynamic>;
      expect(body.keys.toSet(), inputFields.map((f) => f.key).toSet());
      return http.Response(jsonEncode({'prediction': 42.5}), 200);
    })));
    await fillAll(tester);
    await tester.tap(find.text('Predict'));
    await tester.pumpAndSettle();
    expect(find.text('42.50'), findsOneWidget);
  });

  testWidgets('API validation errors are shown readably', (tester) async {
    final f = inputFields.first;
    await tester.pumpWidget(appWith(MockClient((_) async => http.Response(
        jsonEncode({
          'detail': [
            {'loc': ['body', f.key], 'msg': 'Input should be valid'}
          ]
        }),
        422))));
    await fillAll(tester);
    await tester.tap(find.text('Predict'));
    await tester.pumpAndSettle();
    expect(find.text('${f.label}: Input should be valid'), findsOneWidget);
  });
}
