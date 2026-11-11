import 'dart:io';

import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

final FlutterLocalNotificationsPlugin _plugin = FlutterLocalNotificationsPlugin();
bool _ready = false;
const _id = 7001;

bool get supported => Platform.isIOS || Platform.isAndroid;

Future<void> _init() async {
  if (_ready) return;
  tzdata.initializeTimeZones();
  tz.setLocalLocation(tz.getLocation('Europe/Istanbul'));
  const settings = InitializationSettings(
    iOS: DarwinInitializationSettings(requestAlertPermission: false, requestBadgePermission: false, requestSoundPermission: false),
    android: AndroidInitializationSettings('@mipmap/ic_launcher'),
  );
  await _plugin.initialize(settings);
  _ready = true;
}

Future<bool> schedule(int hour) async {
  if (!supported) return false;
  await _init();
  bool? granted = true;
  if (Platform.isIOS) {
    granted = await _plugin.resolvePlatformSpecificImplementation<IOSFlutterLocalNotificationsPlugin>()?.requestPermissions(alert: true, badge: false, sound: true);
  } else if (Platform.isAndroid) {
    granted = await _plugin.resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()?.requestNotificationsPermission();
  }
  if (granted != true) return false;
  final now = tz.TZDateTime.now(tz.local);
  var at = tz.TZDateTime(tz.local, now.year, now.month, now.day, hour);
  if (!at.isAfter(now)) at = at.add(const Duration(days: 1));
  await _plugin.cancel(_id);
  await _plugin.zonedSchedule(
    _id,
    'Lingora',
    'Günlük İngilizce pratiğin seni bekliyor. Serini korumak için birkaç dakika yeter.',
    at,
    const NotificationDetails(
      iOS: DarwinNotificationDetails(),
      android: AndroidNotificationDetails('daily', 'Günlük hatırlatma', importance: Importance.defaultImportance),
    ),
    androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
    matchDateTimeComponents: DateTimeComponents.time,
  );
  return true;
}

Future<void> cancel() async {
  if (!supported) return;
  await _init();
  await _plugin.cancel(_id);
}
