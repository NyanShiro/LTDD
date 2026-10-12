import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:frontend/main.dart';

void main() {
  testWidgets('opens the import page from the empty exam manager', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(const MyApp());

    expect(find.text('Chưa có đề thi đã import'), findsOneWidget);
    await tester.tap(find.widgetWithText(ElevatedButton, 'Import đề thi'));
    await tester.pumpAndSettle();

    expect(find.text('Import đề thi từ Word'), findsOneWidget);
    expect(
      find.text('Lựa chọn đặt trong tag <ctrl>...</ctrl>'),
      findsOneWidget,
    );
  });
}
