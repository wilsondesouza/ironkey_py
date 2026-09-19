import 'dart:async';
import 'package:flutter/material.dart';

class AutoLockService with WidgetsBindingObserver {
  static final AutoLockService _instance = AutoLockService._internal();
  factory AutoLockService() => _instance;
  AutoLockService._internal();

  int timeoutSeconds = 300;
  bool lockOnBackground = false;
  VoidCallback? onLockTriggered;

  bool _isTemporarilyPaused = false;
  DateTime _lastActivity = DateTime.now();
  Timer? _timer;
  bool _isObserverRegistered = false;

  void pauseAutoLock() {
    _isTemporarilyPaused = true;
  }

  void resumeAutoLock() {
    _isTemporarilyPaused = false;
    recordActivity();
  }

  void start({required VoidCallback onLock, int timeoutSec = 300, bool lockOnBg = false}) {
    onLockTriggered = onLock;
    timeoutSeconds = timeoutSec;
    lockOnBackground = lockOnBg;
    _lastActivity = DateTime.now();
    _isTemporarilyPaused = false;

    if (!_isObserverRegistered) {
      WidgetsBinding.instance.addObserver(this);
      _isObserverRegistered = true;
    }
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 10), (_) => _checkTimeout());
  }

  void stop() {
    _timer?.cancel();
    if (_isObserverRegistered) {
      WidgetsBinding.instance.removeObserver(this);
      _isObserverRegistered = false;
    }
  }

  void recordActivity() {
    _lastActivity = DateTime.now();
  }

  void _checkTimeout() {
    if (_isTemporarilyPaused || timeoutSeconds <= 0) return;
    final diff = DateTime.now().difference(_lastActivity).inSeconds;
    if (diff >= timeoutSeconds) {
      triggerLock();
    }
  }

  void triggerLock() {
    if (_isTemporarilyPaused) return;
    onLockTriggered?.call();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (_isTemporarilyPaused) return;
    if (lockOnBackground && (state == AppLifecycleState.paused || state == AppLifecycleState.detached)) {
      triggerLock();
    }
  }
}
