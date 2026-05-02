import 'dart:async';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/foundation.dart';

/// Monitors network connectivity and fires callbacks when the network is
/// restored so pending sync items can be processed.
///
/// NOTE: Uses the connectivity_plus v5 API where both [Connectivity.checkConnectivity]
/// and [Connectivity.onConnectivityChanged] return [List<ConnectivityResult>] instead
/// of a single [ConnectivityResult]. The old single-value comparison caused
/// [isOnline] to always read `false` (the default) because the stream subscription
/// type was wrong and the initial check compared a List to an enum value.
class ConnectivityService {
  static final ConnectivityService instance = ConnectivityService._();
  ConnectivityService._();

  final Connectivity _connectivity = Connectivity();
  bool _isOnline = false;
  StreamSubscription<List<ConnectivityResult>>? _subscription;

  bool get isOnline => _isOnline;

  final List<void Function()> _onRestoreCallbacks = [];

  /// Start monitoring. Should be called once at app startup.
  Future<void> init() async {
    // connectivity_plus v5+: checkConnectivity() returns List<ConnectivityResult>
    final results = await _connectivity.checkConnectivity();
    _isOnline = _resultsAreOnline(results);
    debugPrint('[ConnectivityService] init — results=$results isOnline=$_isOnline');

    // connectivity_plus v5+: onConnectivityChanged emits List<ConnectivityResult>
    _subscription = _connectivity.onConnectivityChanged.listen((results) {
      final wasOnline = _isOnline;
      _isOnline = _resultsAreOnline(results);
      debugPrint('[ConnectivityService] changed — results=$results isOnline=$_isOnline');
      if (!wasOnline && _isOnline) {
        debugPrint('[ConnectivityService] network restored — '
            'triggering ${_onRestoreCallbacks.length} callback(s)');
        for (final cb in _onRestoreCallbacks) {
          cb();
        }
      }
    });
  }

  /// Returns true when at least one active connection is not [ConnectivityResult.none].
  bool _resultsAreOnline(List<ConnectivityResult> results) {
    return results.any((r) => r != ConnectivityResult.none);
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