import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/models.dart';
import '../../services/ai/broget_ai_service.dart';

final authRepositoryProvider = Provider(
  (ref) => AuthRepository(FirebaseAuth.instance),
);
final sessionProvider = StreamProvider<User?>(
  (ref) => ref.watch(authRepositoryProvider).changes,
);
final userRepositoryProvider = Provider(
  (ref) => UserRepository(FirebaseFirestore.instance),
);
final profileProvider = StreamProvider<UserProfile?>((ref) {
  final user = ref.watch(sessionProvider).value;
  return user == null
      ? Stream.value(null)
      : ref.watch(userRepositoryProvider).watch(user.uid);
});
final mealRepositoryProvider = Provider(
  (ref) => MealRepository(FirebaseFirestore.instance, ref.watch(apiProvider)),
);
final selectedDayProvider = NotifierProvider<SelectedDay, DateTime>(
  SelectedDay.new,
);

class SelectedDay extends Notifier<DateTime> {
  @override
  DateTime build() => dayStart(DateTime.now());
  void select(DateTime day) => state = dayStart(day);
}

final dailyMealsProvider = StreamProvider<List<Meal>>((ref) {
  final user = ref.watch(sessionProvider).value;
  if (user == null) return Stream.value([]);
  final day = ref.watch(selectedDayProvider);
  return ref
      .watch(mealRepositoryProvider)
      .watchRange(user.uid, day, DateTime(day.year, day.month, day.day + 1));
});
final settingsProvider = StreamProvider<AppSettings>((ref) {
  final uid = ref.watch(sessionProvider).value?.uid;
  return uid == null
      ? Stream.value(const AppSettings())
      : ref.watch(userRepositoryProvider).settings(uid);
});
final chatRepositoryProvider = Provider(
  (ref) => ChatRepository(FirebaseFirestore.instance),
);
final chatProvider = StreamProvider<List<ChatMessage>>((ref) {
  final uid = ref.watch(sessionProvider).value?.uid;
  return uid == null
      ? Stream.value([])
      : ref.watch(chatRepositoryProvider).watch(uid);
});

class AuthRepository {
  AuthRepository(this.auth);
  final FirebaseAuth auth;
  Stream<User?> get changes => auth.userChanges();
  Future<void> login(String email, String password) async {
    await auth.signInWithEmailAndPassword(
      email: email.trim(),
      password: password,
    );
  }

  Future<bool> register(String name, String email, String password) async {
    final credential = await auth.createUserWithEmailAndPassword(
      email: email.trim(),
      password: password,
    );
    try {
      await credential.user!.updateDisplayName(name.trim());
      await credential.user!.sendEmailVerification();
      return true;
    } on FirebaseAuthException {
      // The account already exists: allow onboarding and resend from Overview.
      return false;
    }
  }

  Future<void> reset(String email) async {
    try {
      await auth.sendPasswordResetEmail(email: email.trim());
    } on FirebaseAuthException catch (error) {
      if (error.code != 'user-not-found') rethrow;
      // Keep the same response for registered and unregistered addresses.
    }
  }

  Future<bool> refreshVerification() async {
    await auth.currentUser?.reload();
    final user = auth.currentUser;
    if (user == null) return false;
    await user.getIdToken(true);
    return user.emailVerified;
  }

  Future<void> signOut() => auth.signOut();
  Future<void> reauthenticate(String password) async {
    final user = auth.currentUser!;
    await user.reauthenticateWithCredential(
      EmailAuthProvider.credential(email: user.email!, password: password),
    );
  }
}

class UserRepository {
  UserRepository(this.db);
  final FirebaseFirestore db;
  final Map<String, Future<void>> _accountInitializations = {};
  DocumentReference<Map<String, dynamic>> doc(String uid) =>
      db.collection('users').doc(uid);
  Stream<UserProfile?> watch(String uid) => doc(uid).snapshots().map(
    (s) => s.exists ? UserProfile.fromJson(uid, s.data()!) : null,
  );
  Future<void> ensureAccount(User user) =>
      _accountInitializations.putIfAbsent(user.uid, () async {
        try {
          await db
              .runTransaction((tx) async {
                final snap = await tx.get(doc(user.uid));
                if (!snap.exists) {
                  tx.set(doc(user.uid), {
                    'userId': user.uid,
                    'name': user.displayName ?? '',
                    'health': null,
                    'createdAt': FieldValue.serverTimestamp(),
                    'updatedAt': FieldValue.serverTimestamp(),
                  });
                }
              })
              .timeout(const Duration(seconds: 20));
        } finally {
          _accountInitializations.remove(user.uid);
        }
      });

  Future<void> save(String uid, String name, HealthProfile health) async {
    if (!health.valid || name.trim().isEmpty || name.length > 80) {
      throw const FormatException('Invalid profile');
    }
    await doc(uid)
        .update({
          'name': name.trim(),
          'health': health.toJson(),
          'updatedAt': FieldValue.serverTimestamp(),
        })
        .timeout(const Duration(seconds: 20));
  }

  Stream<AppSettings> settings(String uid) => doc(uid)
      .collection('settings')
      .doc('preferences')
      .snapshots()
      .map(
        (s) => s.exists ? AppSettings.fromJson(s.data()!) : const AppSettings(),
      );
  Future<void> saveSettings(String uid, AppSettings settings) => doc(uid)
      .collection('settings')
      .doc('preferences')
      .set(settings.toJson())
      .timeout(const Duration(seconds: 20));
}

class MealRepository {
  MealRepository(this.db, this.api);
  final FirebaseFirestore db;
  final BrogetApi api;
  CollectionReference<Map<String, dynamic>> collection(String uid) =>
      db.collection('users').doc(uid).collection('meals');
  Query<Map<String, dynamic>> range(String uid, DateTime start, DateTime end) =>
      collection(uid)
          .where(
            'eatenAt',
            isGreaterThanOrEqualTo: Timestamp.fromDate(start.toUtc()),
          )
          .where('eatenAt', isLessThan: Timestamp.fromDate(end.toUtc()))
          .orderBy('eatenAt');
  Stream<List<Meal>> watchRange(String uid, DateTime start, DateTime end) =>
      range(uid, start, end).limit(601).snapshots().map((s) {
        if (s.size > 600) {
          throw const FormatException('Too many meals in range');
        }
        return s.docs.map((d) => Meal.fromJson(d.id, d.data())).toList();
      });
  Future<List<Meal>> report(String uid, DateTime start, DateTime end) async {
    final s = await range(
      uid,
      start,
      end,
    ).limit(601).get().timeout(const Duration(seconds: 20));
    if (s.size > 600) throw const FormatException('Too many meals in range');
    return s.docs.map((d) => Meal.fromJson(d.id, d.data())).toList();
  }

  Future<MealPage> page(
    String uid, {
    DocumentSnapshot<Map<String, dynamic>>? cursor,
  }) async {
    Query<Map<String, dynamic>> q = collection(
      uid,
    ).orderBy('eatenAt', descending: true).limit(20);
    if (cursor != null) q = q.startAfterDocument(cursor);
    final s = await q.get().timeout(const Duration(seconds: 20));
    return MealPage(
      s.docs.map((d) => Meal.fromJson(d.id, d.data())).toList(),
      s.docs.isEmpty ? null : s.docs.last,
      s.docs.length == 20,
    );
  }

  Future<void> save(Meal meal) async {
    if (!mealTypes.contains(meal.mealType) ||
        meal.foods.isEmpty ||
        meal.foods.length > 12 ||
        meal.foods.any(
          (f) => !f.grams.isFinite || f.grams < 1 || f.grams > 3000,
        )) {
      throw const FormatException('Invalid meal');
    }
    await api.request('PUT', '/meals/${meal.id}', {
      'id': meal.id,
      'mealType': meal.mealType,
      'eatenAt': meal.eatenAt.toUtc().toIso8601String(),
      'foods': meal.foods.map((f) => f.toJson()).toList(),
      'imagePath': meal.imagePath,
      'timeZone': await api.timeZone,
    });
  }

  Future<void> delete(String uid, String id) async {
    await api.request('DELETE', '/meals/$id');
  }
}

class MealPage {
  MealPage(this.meals, this.cursor, this.hasMore);
  final List<Meal> meals;
  final DocumentSnapshot<Map<String, dynamic>>? cursor;
  final bool hasMore;
}

class ChatRepository {
  ChatRepository(this.db);
  final FirebaseFirestore db;
  CollectionReference<Map<String, dynamic>> collection(String uid) =>
      db.collection('users').doc(uid).collection('chat');
  Stream<List<ChatMessage>> watch(String uid) => collection(uid)
      .orderBy('createdAt', descending: true)
      .limit(40)
      .snapshots()
      .map(
        (s) => s.docs.reversed
            .map(
              (d) => ChatMessage(
                d.id,
                d['role'],
                d['text'],
                d.data()['createdAt'] == null
                    ? null
                    : dateValue(d['createdAt']),
              ),
            )
            .toList(),
      );
}
