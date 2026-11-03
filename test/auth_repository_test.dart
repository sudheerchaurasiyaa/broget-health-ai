import 'package:broget_ai/data/repositories/repositories.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_test/flutter_test.dart';

class TestUser extends Fake implements User {
  bool verificationFails = false, refreshed = false, forceToken = false;
  @override
  String? displayName;
  @override
  bool get emailVerified => refreshed;
  @override
  Future<void> updateDisplayName(String? value) async {
    displayName = value;
  }

  @override
  Future<void> sendEmailVerification([ActionCodeSettings? settings]) async {
    if (verificationFails) {
      throw FirebaseAuthException(code: 'too-many-requests');
    }
  }

  @override
  Future<void> reload() async {
    refreshed = true;
  }

  @override
  Future<String?> getIdToken([bool forceRefresh = false]) async {
    forceToken = forceRefresh;
    return 'test-token';
  }
}

class TestCredential extends Fake implements UserCredential {
  TestCredential(this.user);
  @override
  final User user;
}

class TestAuth extends Fake implements FirebaseAuth {
  final user = TestUser();
  String? emailUsed, passwordUsed, resetFailure;
  @override
  User? get currentUser => user;
  @override
  Future<UserCredential> createUserWithEmailAndPassword({
    required String email,
    required String password,
  }) async {
    emailUsed = email;
    passwordUsed = password;
    return TestCredential(user);
  }

  @override
  Future<UserCredential> signInWithEmailAndPassword({
    required String email,
    required String password,
  }) async {
    emailUsed = email;
    passwordUsed = password;
    return TestCredential(user);
  }

  @override
  Future<void> sendPasswordResetEmail({
    required String email,
    ActionCodeSettings? actionCodeSettings,
  }) async {
    emailUsed = email;
    if (resetFailure != null) throw FirebaseAuthException(code: resetFailure!);
  }
}

void main() {
  test(
    'registration succeeds even if verification delivery must be retried',
    () async {
      final auth = TestAuth()..user.verificationFails = true;
      expect(
        await AuthRepository(
          auth,
        ).register(' Sam ', ' sam@example.com ', ' example-password '),
        isFalse,
      );
      expect(auth.emailUsed, 'sam@example.com');
      expect(auth.passwordUsed, ' example-password ');
      expect(auth.user.displayName, 'Sam');
      auth.user.verificationFails = false;
      expect(
        await AuthRepository(
          auth,
        ).register('Sam', 'sam@example.com', 'password123456'),
        isTrue,
      );
    },
  );
  test('login trims email without changing the password', () async {
    final auth = TestAuth();
    await AuthRepository(auth).login(' sam@example.com ', ' password ');
    expect(auth.emailUsed, 'sam@example.com');
    expect(auth.passwordUsed, ' password ');
  });
  test(
    'reset hides unknown accounts and preserves actionable failures',
    () async {
      final auth = TestAuth()..resetFailure = 'user-not-found';
      final repository = AuthRepository(auth);
      await repository.reset(' unknown@example.com ');
      expect(auth.emailUsed, 'unknown@example.com');
      auth.resetFailure = 'network-request-failed';
      await expectLater(
        repository.reset('sam@example.com'),
        throwsA(isA<FirebaseAuthException>()),
      );
    },
  );
  test(
    'verification refresh reloads the user and refreshes backend claims',
    () async {
      final auth = TestAuth();
      expect(await AuthRepository(auth).refreshVerification(), isTrue);
      expect(auth.user.forceToken, isTrue);
    },
  );
}
