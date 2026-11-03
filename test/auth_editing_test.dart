import 'package:broget_ai/features/authentication/auth_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  for (final mode in ['login', 'register']) {
    testWidgets('$mode password stays editable after visibility changes', (
      tester,
    ) async {
      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(home: AuthPage(mode: mode)),
        ),
      );
      final password = find.byWidgetPredicate(
        (widget) =>
            widget is TextField && widget.decoration?.labelText == 'Password',
      );
      await tester.enterText(password, 'Example123!');
      await tester.ensureVisible(password);
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('Show password'));
      await tester.pump();
      final field = tester.widget<TextField>(password);
      expect(field.focusNode!.hasFocus, isTrue);
      expect(field.obscureText, isFalse);
      await tester.sendKeyEvent(LogicalKeyboardKey.backspace);
      await tester.pump();
      expect(field.controller!.text, 'Example123');
      await tester.tap(find.byTooltip('Hide password'));
      await tester.pump();
      await tester.sendKeyEvent(LogicalKeyboardKey.backspace);
      await tester.pump();
      expect(field.controller!.text, 'Example12');
      expect(tester.widget<TextField>(password).obscureText, isTrue);
    });
  }
}
