import 'dart:async';

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/widgets.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:immich_mobile/domain/models/store.model.dart';
import 'package:immich_mobile/entities/store.entity.dart';
import 'package:immich_mobile/services/api.service.dart';
import 'package:immich_mobile/utils/bootstrap.dart';
import 'package:logging/logging.dart';
import 'package:openapi/api.dart';
import 'package:workmanager/workmanager.dart';

const String aiMemoryCheckTaskName = 'app.immich.album-generator.memory-check';
const String _aiMemoryChannelId = 'immich_ai_memories';
const int _maxNotificationsPerFire = 3;

/// Top-level entry point for the Workmanager background isolate.
///
/// Annotated with `vm:entry-point` so tree-shaking keeps it; required by the
/// `workmanager` plugin which invokes it from native code via a separate
/// FlutterEngine.
@pragma('vm:entry-point')
void aiMemoryBackgroundDispatcher() {
  Workmanager().executeTask((task, inputData) async {
    if (task != aiMemoryCheckTaskName) {
      return true;
    }
    final log = Logger('AiMemoryBackgroundDispatcher');
    try {
      WidgetsFlutterBinding.ensureInitialized();
      await EasyLocalization.ensureInitialized();
      await Bootstrap.initDomain(listenStoreUpdates: false, shouldBufferLogs: false);

      final endpoint = Store.tryGet(StoreKey.serverEndpoint);
      final token = Store.tryGet(StoreKey.accessToken);
      if (endpoint == null || endpoint.isEmpty || token == null || token.isEmpty) {
        log.fine('No endpoint/token cached — skipping AI memory check');
        return true;
      }

      final api = ApiService();
      api.setEndpoint(endpoint);
      await api.updateHeaders();

      final now = DateTime.now().toUtc();
      final memories = await api.memoriesApi.searchMemories(type: MemoryType.aiStory, for_: now);
      if (memories == null || memories.isEmpty) {
        return true;
      }

      final lastNotifiedIso = Store.tryGet(StoreKey.lastAiMemoryNotifiedAt);
      DateTime? lastNotifiedAt;
      if (lastNotifiedIso != null && lastNotifiedIso.isNotEmpty) {
        lastNotifiedAt = DateTime.tryParse(lastNotifiedIso)?.toUtc();
      }

      final cutoff = lastNotifiedAt;
      final fresh = memories
          .where((m) => cutoff == null || m.createdAt.toUtc().isAfter(cutoff))
          .toList()
        ..sort((a, b) => a.createdAt.compareTo(b.createdAt));

      if (fresh.isEmpty) {
        return true;
      }

      await _initNotifications();

      // Fire at most _maxNotificationsPerFire to avoid spamming after a
      // long offline gap; the rest are still visible inside the app.
      final toNotify = fresh.length <= _maxNotificationsPerFire
          ? fresh
          : fresh.sublist(fresh.length - _maxNotificationsPerFire);

      for (final memory in toNotify) {
        await _showMemoryNotification(memory);
      }

      final newest = fresh.last.createdAt.toUtc();
      await Store.put(StoreKey.lastAiMemoryNotifiedAt, newest.toIso8601String());

      log.info('Notified for ${toNotify.length} new AI memories (newest: $newest)');
      return true;
    } catch (e, stack) {
      log.warning('AI memory background check failed', e, stack);
      // Returning true so WorkManager doesn't aggressively retry — the next
      // periodic fire will catch up.
      return true;
    }
  });
}

Future<void> _initNotifications() async {
  await FlutterLocalNotificationsPlugin().initialize(
    const InitializationSettings(
      android: AndroidInitializationSettings('@drawable/notification_icon'),
      iOS: DarwinInitializationSettings(),
    ),
  );
}

Future<void> _showMemoryNotification(MemoryResponseDto memory) async {
  final id = memory.id.hashCode & 0x7FFFFFFF;
  final title = _extractMemoryTitle(memory);
  const androidDetails = AndroidNotificationDetails(
    _aiMemoryChannelId,
    'AI memories',
    channelDescription: 'New AI-generated memories are ready to view',
    importance: Importance.defaultImportance,
    priority: Priority.defaultPriority,
  );
  const iosDetails = DarwinNotificationDetails();
  await FlutterLocalNotificationsPlugin().show(
    id,
    title.isEmpty ? 'New AI memory' : title,
    'A fresh AI-generated memory is waiting for you',
    const NotificationDetails(android: androidDetails, iOS: iosDetails),
    payload: 'memory:${memory.id}',
  );
}

String _extractMemoryTitle(MemoryResponseDto memory) {
  try {
    // ignore: invalid_use_of_internal_member
    final raw = memory.data.toJson();
    final title = raw['title'];
    if (title is String && title.isNotEmpty) {
      return title;
    }
  } catch (_) {
    // fall through to default
  }
  return '';
}

/// Schedules the periodic AI memory check. Idempotent — calling it again
/// replaces any prior registration so the user's most recent settings win.
Future<void> registerAiMemoryBackgroundCheck({Duration frequency = const Duration(hours: 4)}) async {
  if (kIsWeb) {
    return;
  }
  // Workmanager enforces a 15-minute minimum on Android and is throttled
  // further on iOS — anything < 15min is silently clamped.
  await Workmanager().registerPeriodicTask(
    aiMemoryCheckTaskName,
    aiMemoryCheckTaskName,
    frequency: frequency,
    existingWorkPolicy: ExistingPeriodicWorkPolicy.replace,
    constraints: Constraints(networkType: NetworkType.connected),
    initialDelay: const Duration(minutes: 15),
  );
}

Future<void> unregisterAiMemoryBackgroundCheck() async {
  if (kIsWeb) {
    return;
  }
  await Workmanager().cancelByUniqueName(aiMemoryCheckTaskName);
}

/// Initializes Workmanager. Safe to call multiple times.
Future<void> ensureAiMemoryWorkmanagerInitialized() async {
  if (kIsWeb) {
    return;
  }
  await Workmanager().initialize(aiMemoryBackgroundDispatcher);
}
