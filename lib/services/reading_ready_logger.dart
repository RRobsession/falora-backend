import 'package:falora/config/reading_delay_config.dart';
import 'package:flutter/foundation.dart';

/// Gönderim / hazırlık sayacı debug logları.
class ReadingReadyLogger {
  static void submitCreated(String id) {
    debugPrint('SUBMIT_CREATED id=$id');
  }

  static void readyAtSet(String id, DateTime readyAt) {
    debugPrint('READY_AT_SET id=$id readyAt=${readyAt.toIso8601String()}');
  }

  static void countdownStart(String id) {
    debugPrint('COUNTDOWN_START id=$id');
  }

  static void countdownTick(String id, Duration remaining) {
    debugPrint(
      'COUNTDOWN_TICK id=$id remaining=${formatReadingCountdown(remaining)}',
    );
  }

  static void countdownDone(String id) {
    debugPrint('COUNTDOWN_DONE id=$id');
  }

  static void resultReadyLockedUntilReadyAt(String id) {
    debugPrint('RESULT_READY_LOCKED_UNTIL_READY_AT id=$id');
  }

  static void resultOpenBlockedRemainingTime(String id, Duration remaining) {
    debugPrint(
      'RESULT_OPEN_BLOCKED_REMAINING_TIME id=$id '
      'remaining=${formatReadingCountdown(remaining)}',
    );
  }

  static void resultOpenAllowed(String id) {
    debugPrint('RESULT_OPEN_ALLOWED id=$id');
  }
}
