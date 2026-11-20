import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:prediction_app/api_service.dart';
import 'package:prediction_app/config.dart';
import 'package:prediction_app/main.dart';
import 'package:prediction_app/prediction_page.dart';

/// A valid value for each configured field. The food group is typed in lower
/// case on purpose, to check the app still sends the exact API value.
String validValue(InputField f) => switch (f.type) {
      FieldType.text => (f.allowedValues?.first ?? 'x').toLowerCase(),
      _ => '${f.min ?? 0}',
    };

Future<void> fillAll(WidgetTester tester) async {
  for (final f in inputFields) {
    await tester.enterText(find.byKey(ValueKey('field_${f.key}')), validValue(f));
  }
}

/// Makes the test screen tall enough to show all the fields at once.
void useTallScreen(WidgetTester tester) {
  tester.view.physicalSize = const Size(1080, 4000);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
}

Widget appWith(http.Client client) =>
    MaterialApp(home: PredictionPage(api: ApiService(client: client)));

void main() {
  testWidgets('shows one labelled field per input and a Predict button',
      (tester) async {
    useTallScreen(tester);
    await tester.pumpWidget(const PredictionApp());
    expect(find.byType(TextField), findsNWidgets(inputFields.length));
    for (final f in inputFields) {
      expect(find.text(f.label), findsOneWidget);
    }
    expect(find.text('Predict'), findsOneWidget);
  });

  testWidgets('missing values show an error without calling the API',
      (tester) async {
    useTallScreen(tester);
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

  testWidgets('valid inputs display the score, grade and warning',
      (tester) async {
    useTallScreen(tester);
    await tester.pumpWidget(appWith(MockClient((req) async {
      final body = jsonDecode(req.body) as Map<String, dynamic>;
      expect(body.keys.toSet(), inputFields.map((f) => f.key).toSet());
      expect(body['food_group'], foodGroups.first);
      return http.Response(
          jsonEncode({'prediction': 22.5, 'grade': 'E', 'additives_warning': true}),
          200);
    })));
    await fillAll(tester);
    await tester.tap(find.text('Predict'));
    await tester.pumpAndSettle();
    expect(find.text('22.50 $resultUnit'), findsOneWidget);
    expect(find.text('Nutri-Score grade: E'), findsOneWidget);
    expect(find.byKey(const ValueKey('result_warning')), findsOneWidget);
  });

  testWidgets('API validation errors are shown readably', (tester) async {
    useTallScreen(tester);
    final f = inputFields[1];
    await tester.pumpWidget(appWith(MockClient((_) async => http.Response(
        jsonEncode({
          'detail': [
            {'loc': ['body', f.key], 'msg': 'Input should be valid'},
            {
              'loc': ['body'],
              'msg': 'Value error, saturated_fat_g cannot be more than fat_g'
            },
          ]
        }),
        422))));
    await fillAll(tester);
    await tester.tap(find.text('Predict'));
    await tester.pumpAndSettle();
    expect(
        find.text('${f.label}: Input should be valid\n'
            'saturated fat cannot be more than fat'),
        findsOneWidget);
  });
}
