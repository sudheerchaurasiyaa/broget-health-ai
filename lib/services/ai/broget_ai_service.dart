import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_app_check/firebase_app_check.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:uuid/uuid.dart';
import '../../core/config/app_config.dart';
import '../../core/errors/app_error.dart';
import '../../data/models/models.dart';
import '../../data/models/nutrition_report.dart';

abstract interface class BrogetAiService {
  Future<AIAnalysis> analyzeFoodImage(
    Uint8List image, {
    bool reference = false,
    String referenceDescription = '',
  });
  Future<AIAnalysis> estimatePortion(
    Uint8List image,
    String referenceDescription,
  );
  Future<ChatReply> chat(
    String message,
    DateTime localDay, {
    String? requestId,
  });
  Future<String> generateNutritionSummary(DateTime start, DateTime end);
  Future<ChatReply> generateMealSuggestion(DateTime localDay);
}

final apiProvider = Provider((ref) {
  final api = BrogetApi(http.Client());
  ref.onDispose(api.dispose);
  return api;
});
final aiServiceProvider = Provider<BrogetAiService>(
  (ref) => ref.watch(apiProvider),
);

class ChatReply {
  ChatReply(this.text, this.proposal);
  final String text;
  final Map<String, dynamic>? proposal;
}

class BrogetApi implements BrogetAiService {
  BrogetApi(this.client);
  final http.Client client;
  Future<String>? _timeZone;
  Future<String> get timeZone => _timeZone ??=
      FlutterTimezone.getLocalTimezone().then((zone) => zone.identifier);
  Future<void> prepareHistory() async {
    final zone = await timeZone;
    for (var page = 0; page < 20; page++) {
      final result = await request('POST', '/reports/prepare', {
        'timeZone': zone,
      });
      if (result['complete'] == true) return;
    }
    throw const AppError('reports-indexing');
  }

  Future<NutritionReport> nutritionReport(DateTime start, DateTime end) async {
    await prepareHistory();
    return NutritionReport.fromJson(
      await request(
        'GET',
        '/reports?startDate=${dayKey(start)}&endDate=${dayKey(end)}',
      ),
    );
  }

  void dispose() => client.close();
  Future<Map<String, dynamic>> request(
    String method,
    String path, [
    Map<String, dynamic>? body,
  ]) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) throw const AppError('sign-in-required');
    final headers = {
      'Content-Type': 'application/json',
      'Authorization': 'Bearer ${await user.getIdToken()}',
    };
    if (AppConfig.production) {
      headers['X-Firebase-AppCheck'] =
          await FirebaseAppCheck.instance.getToken() ?? '';
    }
    final req = http.Request(method, Uri.parse('${AppConfig.apiUrl}$path'))
      ..headers.addAll(headers);
    if (body != null) req.body = jsonEncode(body);
    final response = await (() async => http.Response.fromStream(
      await client.send(req),
    ))().timeout(const Duration(seconds: 145));
    final data = jsonDecode(response.body) as Map<String, dynamic>;
    if (response.statusCode >= 400) {
      throw AppError(data['code'] as String? ?? 'service-unavailable');
    }
    return data;
  }

  Future<List<FoodItem>> searchFood(String query) async {
    final data = await request(
      'GET',
      '/foods?q=${Uri.encodeQueryComponent(query)}',
    );
    return (data['foods'] as List)
        .map((f) => FoodItem.fromJson(Map<String, dynamic>.from(f)))
        .toList();
  }

  @override
  Future<AIAnalysis> analyzeFoodImage(
    Uint8List image, {
    bool reference = false,
    String referenceDescription = '',
  }) async => AIAnalysis.fromJson(
    await request('POST', '/analyze', {
      'image': base64Encode(image),
      'reference': reference,
      'referenceDescription': referenceDescription,
    }),
  );
  @override
  Future<AIAnalysis> estimatePortion(
    Uint8List image,
    String referenceDescription,
  ) => analyzeFoodImage(
    image,
    reference: true,
    referenceDescription: referenceDescription,
  );
  @override
  Future<ChatReply> chat(
    String message,
    DateTime localDay, {
    String? requestId,
  }) async {
    await prepareHistory();
    final start = dayStart(localDay),
        end = DateTime(localDay.year, localDay.month, localDay.day + 1);
    final j = await request('POST', '/chat', {
      'message': message,
      'requestId': requestId ?? const Uuid().v4(),
      'timeZone': await timeZone,
      'start': start.toUtc().toIso8601String(),
      'end': end.toUtc().toIso8601String(),
    });
    return ChatReply(
      j['text'] as String,
      j['proposal'] == null ? null : Map<String, dynamic>.from(j['proposal']),
    );
  }

  @override
  Future<ChatReply> generateMealSuggestion(DateTime localDay) => chat(
    'Suggest a dinner based on my recorded nutrition, remaining estimated calories and preferences. Respect allergies and explain uncertainty.',
    localDay,
  );
  @override
  Future<String> generateNutritionSummary(DateTime start, DateTime end) async {
    await prepareHistory();
    return (await request('POST', '/summary', {
      'startDate': dayKey(start),
      'endDate': dayKey(end),
    }))['text'];
  }

  Future<void> clearChat() async {
    await request('DELETE', '/chat');
  }

  Future<void> deleteAccount() async {
    await request('DELETE', '/account', {'confirmation': 'DELETE'});
  }
}
