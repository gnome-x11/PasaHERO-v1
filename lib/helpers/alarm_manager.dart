import 'dart:async';
import 'dart:math';
import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:transit/pages/account_settings_page.dart';
import 'package:vibration/vibration.dart';
import '../models/alarm_state.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

Function(LatLng)? onAlarmTriggered;

class AlarmManager {
  final activeAlarms = <LatLng, bool>{};
  AudioPlayer? _audioPlayer;
  bool isAlarmActive = false;
  Timer? _checkTimer;
  LatLng? lastPosition;
  double? alarmRadius;
  String? alarmSoundPath;
  VibrationPattern? vibrationPattern;
  bool vibrationEnabled = true;
  bool _isDisposed = false;
  Timer? _vibrationTimer;
  bool isAlarmAcknowledged = false;

  final List<AlarmState> alarms = [];

  bool isAcknowledged(LatLng point) {
    final alarm = alarms.firstWhere((a) => a.point == point,
        orElse: () => AlarmState(point: point, radius: 0));
    return alarm.isAcknowledged;
  }

  Future<void> initialize() async {
    if (_isDisposed) return;

    _audioPlayer?.dispose();
    _audioPlayer = AudioPlayer();

    final prefs = await SharedPreferences.getInstance();
    alarmRadius = prefs.getDouble('alarmRadius') ?? 200.0;
    vibrationEnabled = prefs.getBool('isVibrationEnabled') ?? true;

    final soundName = prefs.getString('selectedSound') ?? "Default Alarm";
    alarmSoundPath = AlarmConstants.availableAlarmSounds
        .firstWhere((sound) => sound.name == soundName,
            orElse: () => AlarmConstants.availableAlarmSounds[0])
        .assetPath;

    final vibrationName = prefs.getString('selectedVibration') ?? "Default";
    vibrationPattern = VibrationConstants.availableVibrationPatterns.firstWhere(
        (vib) => vib.name == vibrationName,
        orElse: () => VibrationConstants.availableVibrationPatterns[0]);
  }

  void setAlarms(List<LatLng> getOffPoints, {double? radius}) {
    alarms.clear();
    for (final point in getOffPoints) {
      activeAlarms[point] = false;
    }
    radius = radius ?? radius;
    alarms.addAll(getOffPoints.map((point) => AlarmState(
          point: point,
          radius: radius ?? alarmRadius ?? 50.0,
        )));
  }

  void startMonitoring() {
    if (_isDisposed) return;

    _checkTimer?.cancel();
    _checkTimer = Timer.periodic(const Duration(seconds: 3), (timer) {
      if (_isDisposed) {
        timer.cancel();
        return;
      }
      if (lastPosition != null) {
        _checkAlarms(lastPosition!);
      }
    });
  }

  void stopMonitoring() {
    _checkTimer?.cancel();
    _stopAlarm();
  }

  void updatePosition(LatLng position) {
    if (_isDisposed) return;
    lastPosition = position;
    _checkAlarms(position);
  }

  void _checkAlarms(LatLng position) {
    if (_isDisposed) return;

    bool shouldTrigger = false;

    for (var alarm in alarms) {
      if (!alarm.isAcknowledged) {
        final distance = _calculateDistance(position, alarm.point);
        alarm.isTriggered = distance <= alarm.radius;

        if (alarm.isTriggered) {
          shouldTrigger = true;
          WidgetsBinding.instance.addPostFrameCallback((_) {
            onAlarmTriggered?.call(alarm.point);
          });
        }
      }
    }

    if (shouldTrigger && !isAlarmActive) {
      triggerAlarm();
    } else if (!shouldTrigger && isAlarmActive) {
      _stopAlarm();
    }
  }

  void triggerAlarm() {
    if (_isDisposed || _audioPlayer == null) return;
    if (isAlarmActive) return;

    isAlarmActive = true;

    _audioPlayer!.play(AssetSource(alarmSoundPath!));
    _audioPlayer!.setReleaseMode(ReleaseMode.loop);

    if (vibrationEnabled && vibrationPattern != null) {
      _vibrationTimer = Timer.periodic(
        Duration(
            milliseconds: vibrationPattern!.pattern.reduce((a, b) => a + b)),
        (_) {
          Vibration.vibrate(pattern: vibrationPattern!.pattern);
        },
      );
      Vibration.vibrate(pattern: vibrationPattern!.pattern);
    }
  }

  void acknowledgeAlarm(LatLng point) {
    if (_isDisposed) return;

    final alarm = alarms.firstWhere(
      (a) => a.point == point,
      orElse: () => AlarmState(point: point, radius: 0),
    );

    alarm.isAcknowledged = true;
    alarm.isTriggered = false;

    _audioPlayer?.setReleaseMode(ReleaseMode.release);
    _audioPlayer?.stop();
    Vibration.cancel();
    isAlarmActive = false;
    activeAlarms[point] = true;
    _vibrationTimer?.cancel();
    _vibrationTimer = null;
  }

  void dispose() {
    if (_isDisposed) return;
    _isDisposed = true;

    _checkTimer?.cancel();
    _checkTimer = null;

    _audioPlayer?.stop();
    _audioPlayer?.dispose();
    _audioPlayer = null;

    Vibration.cancel();
    activeAlarms.clear();
    isAlarmActive = false;
  }

  void _stopAlarm() {
    if (_isDisposed || !isAlarmActive) return;

    isAlarmActive = false;
    _audioPlayer?.setReleaseMode(ReleaseMode.release);
    _audioPlayer?.stop();
    Vibration.cancel();
    _vibrationTimer?.cancel();
    _vibrationTimer = null;
  }

  double _calculateDistance(LatLng point1, LatLng point2) {
    const double R = 6371e3;
    double lat1 = point1.latitude * pi / 180;
    double lat2 = point2.latitude * pi / 180;
    double deltaLat = (point2.latitude - point1.latitude) * pi / 180;
    double deltaLng = (point2.longitude - point1.longitude) * pi / 180;

    double a = sin(deltaLat / 2) * sin(deltaLat / 2) +
        cos(lat1) * cos(lat2) * sin(deltaLng / 2) * sin(deltaLng / 2);
    double c = 2 * atan2(sqrt(a), sqrt(1 - a));

    return R * c;
  }
}
