// lib/services/notification_service.dart
import 'dart:async';
import 'dart:io';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest_all.dart' as tz;
import 'package:timezone/timezone.dart' as tz;

class NotiService {
  NotiService._();
  static final NotiService I = NotiService._();

  final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();

  /// 알림 탭 이벤트 스트림
  final StreamController<String?> onTap = StreamController<String?>.broadcast();

  static const AndroidNotificationDetails _androidDetails =
      AndroidNotificationDetails(
    'channel_main',
    'Main Notifications',
    channelDescription: '기본 알림 채널',
    importance: Importance.max,
    priority: Priority.high,
    playSound: true,
    enableVibration: true,
  );

  static const NotificationDetails _details =
      NotificationDetails(android: _androidDetails);

  /// 초기화 (main.dart에서 앱 시작 전에 호출)
  Future<void> init() async {
    tz.initializeTimeZones();

    const settings = InitializationSettings(
      android: AndroidInitializationSettings('@mipmap/ic_launcher'),
      iOS: DarwinInitializationSettings(),
    );

    if (Platform.isAndroid) {
      await _plugin
          .resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin>()
          ?.requestNotificationsPermission();
    }

    await _plugin.initialize(
      settings,
      onDidReceiveNotificationResponse: (r) => onTap.add(r.payload),
      onDidReceiveBackgroundNotificationResponse: notificationTapBackground,
    );

    final details = await _plugin.getNotificationAppLaunchDetails();
    if ((details?.didNotificationLaunchApp ?? false) &&
        details?.notificationResponse?.payload != null) {
      onTap.add(details!.notificationResponse!.payload);
    }
  }

  /// 즉시 알림
  Future<void> showNow({
    required String title,
    required String body,
    String? payload,
  }) =>
      _plugin.show(0, title, body, _details, payload: payload);

  /// n초 뒤 알림
  Future<void> showAfter({
    required Duration after,
    required String title,
    required String body,
    String? payload,
  }) =>
      _plugin.zonedSchedule(
        1,
        title,
        body,
        tz.TZDateTime.now(tz.local).add(after),
        _details,
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
        payload: payload,
      );

  /// 주기 알림 (예: 매 1분)
  Future<void> showPeriodic({
    required String title,
    required String body,
    String? payload,
    RepeatInterval interval = RepeatInterval.everyMinute,
  }) =>
      _plugin.periodicallyShow(
        2,
        title,
        body,
        interval,
        _details,
        payload: payload,
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      );

  Future<void> cancel(int id) => _plugin.cancel(id);
  Future<void> cancelAll() => _plugin.cancelAll();
}

/// 백그라운드 알림 탭 콜백
@pragma('vm:entry-point')
void notificationTapBackground(NotificationResponse r) {
  // 백그라운드 진입점 - 최소 작업만
}
