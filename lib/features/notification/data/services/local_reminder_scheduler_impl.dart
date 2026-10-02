import 'dart:convert';

import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:timezone/data/latest.dart' as tz_data;
import 'package:timezone/timezone.dart' as tz;

import '../../domain/services/local_reminder_scheduler.dart';

/// [LocalReminderScheduler] implementation using
/// `flutter_local_notifications` for OS-level scheduling and
/// `shared_preferences` for the persistent local reminder registry.
class LocalReminderSchedulerImpl implements LocalReminderScheduler {
  static const _registryKey = 'local_reminder_registry_v1';

  static const _androidChannelId = 'reminders';
  static const _androidChannelName = 'Rappels';

  final FlutterLocalNotificationsPlugin _plugin;
  final SharedPreferences _prefs;

  bool _timezoneInitialized = false;

  LocalReminderSchedulerImpl({
    required FlutterLocalNotificationsPlugin plugin,
    required SharedPreferences prefs,
  })  : _plugin = plugin,
        _prefs = prefs;

  /// Initializes timezone data and the local notification plugin.
  ///
  /// This should be called once during application startup on
  /// supported native platforms, before [requestPermission] or
  /// any scheduling call.
  @override
  Future<void> initialize() async {
    if (!_timezoneInitialized) {
      tz_data.initializeTimeZones();

      // Single-timezone target market.
      // Cameroon uses UTC+1 and does not observe DST.
      tz.setLocalLocation(
        tz.getLocation('Africa/Douala'),
      );

      _timezoneInitialized = true;
    }

    const androidSettings =
        AndroidInitializationSettings('@mipmap/ic_launcher');

    const iosSettings = DarwinInitializationSettings();

    const initSettings = InitializationSettings(
      android: androidSettings,
      iOS: iosSettings,
    );

    await _plugin.initialize(initSettings);

    final androidPlugin = _plugin.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();

    await androidPlugin?.createNotificationChannel(
      const AndroidNotificationChannel(
        _androidChannelId,
        _androidChannelName,
        description: 'Rappels de reservations et de taches',
        importance: Importance.high,
      ),
    );
  }

  @override
  Future<bool> requestPermission() async {
    final androidPlugin = _plugin.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();

    final iosPlugin = _plugin.resolvePlatformSpecificImplementation<
        IOSFlutterLocalNotificationsPlugin>();

    final androidGranted =
        await androidPlugin?.requestNotificationsPermission();

    final iosGranted = await iosPlugin?.requestPermissions(
      alert: true,
      badge: true,
      sound: true,
    );

    // A platform-specific plugin resolves to null on platforms where
    // it does not apply. Treat that platform as granted because there
    // is no native notification permission to request there.
    return (androidGranted ?? true) && (iosGranted ?? true);
  }

  @override
  Future<void> syncReminder({
    required String entityId,
    required DateTime scheduledFor,
    required String title,
    required String body,
  }) async {
    final registry = _readRegistry();

    final existing = registry[entityId];

    final scheduledForIso = scheduledFor.toIso8601String();

    if (existing != null && existing['scheduledFor'] == scheduledForIso) {
      // Already scheduled for exactly this time.
      // This makes repeated synchronization idempotent.
      return;
    }

    final notificationId = _stableNotificationId(entityId);

    if (existing != null) {
      await _plugin.cancel(notificationId);
    }

    await _plugin.zonedSchedule(
      notificationId,
      title,
      body,
      tz.TZDateTime.from(
        scheduledFor,
        tz.local,
      ),
      const NotificationDetails(
        android: AndroidNotificationDetails(
          _androidChannelId,
          _androidChannelName,
        ),
        iOS: DarwinNotificationDetails(),
      ),
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      uiLocalNotificationDateInterpretation:
          UILocalNotificationDateInterpretation.absoluteTime,
    );

    registry[entityId] = {
      'scheduledFor': scheduledForIso,
      'notificationId': notificationId,
    };

    await _writeRegistry(registry);
  }

  @override
  Future<void> cancelReminder(String entityId) async {
    final registry = _readRegistry();

    final existing = registry[entityId];

    if (existing == null) {
      return;
    }

    await _plugin.cancel(
      _stableNotificationId(entityId),
    );

    registry.remove(entityId);

    await _writeRegistry(registry);
  }

  /// Produces a deterministic notification ID from the entity ID.
  ///
  /// `flutter_local_notifications` requires an integer notification ID.
  /// The modulo operation keeps the value within the positive 32-bit
  /// integer range expected by Android.
  int _stableNotificationId(String entityId) {
    return entityId.hashCode.abs() % 2147483647;
  }

  Map<String, Map<String, dynamic>> _readRegistry() {
    final raw = _prefs.getString(_registryKey);

    if (raw == null || raw.isEmpty) {
      return {};
    }

    final decoded = jsonDecode(raw) as Map<String, dynamic>;

    return decoded.map(
      (key, value) => MapEntry(
        key,
        value as Map<String, dynamic>,
      ),
    );
  }

  Future<void> _writeRegistry(
    Map<String, Map<String, dynamic>> registry,
  ) async {
    await _prefs.setString(
      _registryKey,
      jsonEncode(registry),
    );
  }
}
