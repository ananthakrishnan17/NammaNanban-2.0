import 'dart:async';
import 'package:connectivity_plus/connectivity_plus.dart';

/// Monitors network connectivity and fires callbacks when the network is
/// restored so pending sync items can be processed.
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
    final results = await _connectivity.checkConnectivity();
    _isOnline = _isConnected(results);

    _subscription = _connectivity.onConnectivityChanged.listen((results) {
      final wasOnline = _isOnline;
      _isOnline = _isConnected(results);
      if (!wasOnline && _isOnline) {
        // Network just restored — notify listeners
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

  bool _isConnected(List<ConnectivityResult> results) =>
      results.any((r) => r != ConnectivityResult.none);
}
