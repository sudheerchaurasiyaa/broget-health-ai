import 'dart:async';
import 'package:health_broget/data/models/models.dart';
import 'package:health_broget/data/repositories/repositories.dart';
import 'package:health_broget/features/profile/profile_page.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

class NamedUser extends Fake implements User {
  NamedUser(this.displayName);
  @override
  final String? displayName;
  @override
  String get email => 'name-test@example.com';
}

Finder nameField() => find.byWidgetPredicate(
  (widget) => widget is TextField && widget.decoration?.labelText == 'Name',
);

void main() {
  testWidgets(
    'late registration name fills an empty profile without replacing edits',
    (tester) async {
      final sessions = StreamController<User?>();
      final profiles = StreamController<UserProfile?>();
      addTearDown(sessions.close);
      addTearDown(profiles.close);
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            sessionProvider.overrideWith((ref) => sessions.stream),
            profileProvider.overrideWith((ref) => profiles.stream),
          ],
          child: const MaterialApp(home: ProfilePage(onboarding: true)),
        ),
      );
      sessions.add(NamedUser(null));
      profiles.add(const UserProfile(userId: 'test', name: ''));
      await tester.pumpAndSettle();
      expect(tester.widget<TextField>(nameField()).controller!.text, '');
      sessions.add(NamedUser('Sudheer'));
      await tester.pumpAndSettle();
      expect(tester.widget<TextField>(nameField()).controller!.text, 'Sudheer');
      await tester.enterText(nameField(), 'My edited name');
      profiles.add(const UserProfile(userId: 'test', name: 'Old saved name'));
      await tester.pumpAndSettle();
      expect(
        tester.widget<TextField>(nameField()).controller!.text,
        'My edited name',
      );
      await tester.enterText(nameField(), '');
      sessions.add(NamedUser('Updated account name'));
      await tester.pumpAndSettle();
      expect(tester.widget<TextField>(nameField()).controller!.text, '');
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('saved profile name takes priority when it arrives after auth', (
    tester,
  ) async {
    final profiles = StreamController<UserProfile?>();
    addTearDown(profiles.close);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          sessionProvider.overrideWith(
            (ref) => Stream.value(NamedUser('Account name')),
          ),
          profileProvider.overrideWith((ref) => profiles.stream),
        ],
        child: const MaterialApp(home: ProfilePage(onboarding: true)),
      ),
    );
    await tester.pumpAndSettle();
    expect(
      tester.widget<TextField>(nameField()).controller!.text,
      'Account name',
    );
    profiles.add(const UserProfile(userId: 'test', name: 'Saved profile name'));
    await tester.pumpAndSettle();
    expect(
      tester.widget<TextField>(nameField()).controller!.text,
      'Saved profile name',
    );
    expect(tester.takeException(), isNull);
  });
}
