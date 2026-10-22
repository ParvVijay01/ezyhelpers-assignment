import 'package:flutter/foundation.dart';
import 'package:logging/logging.dart';

void setupLogging() {
  Logger.root.level = kReleaseMode ? Level.WARNING : Level.ALL;

  Logger.root.onRecord.listen((record) {
    final buffer = StringBuffer(
      '${record.time.toIso8601String()} '
      '[${record.level.name}] ${record.loggerName}: ${record.message}',
    );
    if (record.error != null) buffer.write('\n  error: ${record.error}');
    if (record.stackTrace != null) buffer.write('\n${record.stackTrace}');
    debugPrint(buffer.toString());
  });
}
