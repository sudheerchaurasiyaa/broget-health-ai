import 'package:broget_ai/widgets/common.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  for (final width in [240.0, 320.0, 768.0, 1440.0]) {
    testWidgets('loading status remains compact at $width px and large text', (
      tester,
    ) async {
      tester.view.physicalSize = Size(width, 500);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(
        MaterialApp(
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(
              context,
            ).copyWith(textScaler: const TextScaler.linear(2)),
            child: child!,
          ),
          home: const Scaffold(
            body: Center(
              child: LoadingPanel(message: 'Loading your meal journal…'),
            ),
          ),
        ),
      );
      await tester.pump();
      expect(
        tester.getSize(find.byType(CircularProgressIndicator)),
        const Size(20, 20),
      );
      expect(tester.getSize(find.byType(Row)).width, lessThanOrEqualTo(280));
      expect(tester.getSize(find.byType(Row)).height, lessThan(180));
      expect(find.byType(LinearProgressIndicator), findsNothing);
      expect(tester.takeException(), isNull);
    });
  }
}
