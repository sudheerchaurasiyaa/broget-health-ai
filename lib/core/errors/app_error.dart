import 'dart:async';
import 'package:firebase_core/firebase_core.dart';

class AppError implements Exception {
  const AppError(this.code);
  final String code;
}

String friendlyError(Object error) {
  final code = error is AppError
      ? error.code
      : error is FirebaseException
      ? error.code
      : '';
  if (error is TimeoutException) {
    return 'This is taking longer than expected. Check your connection and try again.';
  }
  return switch (code) {
    'operation-not-allowed' =>
      'Email/password sign-in is not enabled yet. Please contact support.',
    'invalid-api-key' || 'app-not-authorized' || 'configuration-not-found' =>
      'Sign-in needs an application configuration update. Please contact support.',
    'unauthorized-domain' =>
      'Sign-in is not configured for this website address yet.',
    'user-disabled' =>
      'This account has been disabled. Please contact support.',
    'reports-indexing' =>
      'Your older records are being organized. Please retry to continue; no meals have been lost.',
    'assistant-request-in-progress' =>
      'Your previous message is still being processed. Please wait before retrying.',
    'request-conflict' =>
      'This request has already been used. Start a new message and try again.',
    'assistant-unavailable' || 'assistant-busy' =>
      'Health Broget Assistant is busy right now. Please wait a moment and try again.',
    'assistant-model-unavailable' ||
    'assistant-configuration-error' ||
    'assistant-request-rejected' =>
      'The assistant needs a service configuration update. Please try again after the service is updated.',
    'assistant-timeout' =>
      'The assistant took too long to respond. Please try again.',
    'assistant-content-blocked' =>
      'The assistant could not respond to this request. Try a different nutrition question or food photo.',
    'photo-storage-unavailable' =>
      'Photo storage is coming soon. You can save your meal without a photo.',
    'invalid-credential' ||
    'wrong-password' ||
    'user-not-found' => 'The email or password is incorrect.',
    'email-already-in-use' =>
      'An account already uses this email. Try signing in.',
    'weak-password' => 'Use at least 12 characters for your password.',
    'invalid-email' => 'Enter a valid email address.',
    'too-many-requests' || 'rate-limited' =>
      'You have made several requests. Please wait a little before trying again.',
    'network-request-failed' ||
    'unavailable' ||
    'timeout' => 'Unable to connect. Check your internet connection and retry.',
    'permission-denied' || 'unauthorized' =>
      'You do not have access to this information. Try signing in again.',
    'verify-email' =>
      'Verify your email before using the assistant or food search.',
    'sign-in-required' => 'Your session has expired. Please sign in again.',
    'requires-recent-login' || 'recent-login-required' =>
      'For your security, sign in again before deleting your account.',
    'assistant-not-configured' =>
      'The assistant is not connected yet. You can still log meals manually.',
    'nutrition-not-configured' =>
      'Nutrition search is not connected yet. You can enter values from a food label manually.',
    'nutrition-unavailable' =>
      'Nutrition search is temporarily unavailable. Try again or enter a food label.',
    'invalid-analysis' =>
      'We could not read a reliable food estimate. Try a clearer photo or enter your meal manually.',
    'invalid-image' => 'Choose a readable JPEG, PNG or WebP photograph.',
    'image-too-large' =>
      'Choose an image smaller than 10 MB and 16 megapixels.',
    'range-too-large' =>
      'There are too many meals in this range. Choose a shorter period.',
    'invalid-input' =>
      'Some information is invalid. Check your entries and try again.',
    'account-deleting' =>
      'Account deletion is in progress. Open settings to retry deletion.',
    _ =>
      'We could not complete that action. Check your connection and try again.',
  };
}
