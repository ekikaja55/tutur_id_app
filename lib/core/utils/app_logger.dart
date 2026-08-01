import 'dart:developer' as dev;
import 'package:flutter/foundation.dart';

class AppLogger {
  static const String _defaultTag = 'APP';

  static void i(String message, {String tag = _defaultTag}) {
    _log('[INFO] $message', name: tag);
  }

  static void s(String message, {String tag = _defaultTag}) {
    _log('[SUCCESS] $message', name: tag);
  }

  static void w(String message, {String tag = _defaultTag}) {
    _log('[WARNING] $message', name: tag);
  }

  static void e(
    String message, {
    Object? error,
    StackTrace? stackTrace,
    String tag = _defaultTag,
  }) {
    _log('[ERROR] $message', name: tag, error: error, stackTrace: stackTrace);
  }

  static void net(String message, {String tag = 'NETWORK'}) {
    _log('[REST_API] $message', name: tag);
  }

  static void _log(
    String message, {
    required String name,
    Object? error,
    StackTrace? stackTrace,
  }) {
    if (kDebugMode) {
      dev.log(message, name: name, error: error, stackTrace: stackTrace);
    }
  }
}
