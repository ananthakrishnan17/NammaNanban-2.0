import 'dart:async';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/foundation.dart';

/// Monitors network connectivity and fires callbacks when the network is
/// restored so pending sync items can be processed.
class ConnectivityService {
  static final ConnectivityService instance = ConnectivityService._();
  ConnectivityService._();

  final Connectivity _connectivity = Connectivity();
  bool _isOnline = false;

  // Changed from List<ConnectivityResult> to ConnectivityResult
  StreamSubscription<ConnectivityResult>? _subscription;

  bool get isOnline => _isOnline;

  final List<void Function()> _onRestoreCallbacks = [];

  /// Start monitoring. Should be called once at app startup.
  Future<void> init() async {
    // Older API: checkConnectivity() returns a single ConnectivityResult
    final result = await _connectivity.checkConnectivity();
    _isOnline = result != ConnectivityResult.none;
    debugPrint('[ConnectivityService] init — result=$result isOnline=$_isOnline');

    // Older API: onConnectivityChanged emits a single ConnectivityResult
    _subscription = _connectivity.onConnectivityChanged.listen((result) {
      final wasOnline = _isOnline;
      _isOnline = result != ConnectivityResult.none;
      debugPrint('[ConnectivityService] changed — result=$result isOnline=$_isOnline');

      if (!wasOnline && _isOnline) {
        debugPrint('[ConnectivityService] network restored — '
            'triggering ${_onRestoreCallbacks.length} callback(s)');
        for (final cb in _onRestoreCallbacks) {
          cb();
        }
      }
    });
  }

  /// Register a callback to be called when network is restored.
  void onNetworkRestored(void Function() callback) {
    _onRestoreCallbacks.add(callback);
  }

  /// Cancel the connectivity subscription. Call on app teardown if needed.
  void dispose() {
    _subscription?.cancel();
    _subscription = null;
    _onRestoreCallbacks.clear();
  }
}