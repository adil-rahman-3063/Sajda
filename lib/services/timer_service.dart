import 'dart:async';
import 'package:flutter/material.dart';

class TimerService extends ChangeNotifier {
  Timer? _timer;
  Duration _remainingTime = Duration.zero;
  String _targetPrayer = '';

  Duration get remainingTime => _remainingTime;
  String get targetPrayer => _targetPrayer;

  void startCountdown(DateTime targetTime, String prayerName) {
    _timer?.cancel();
    _targetPrayer = prayerName;
    _remainingTime = targetTime.difference(DateTime.now());

    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_remainingTime.inSeconds > 0) {
        _remainingTime = _remainingTime - const Duration(seconds: 1);
        notifyListeners();
      } else {
        _timer?.cancel();
        // Trigger notification or callback
      }
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }
}
