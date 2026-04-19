import '../../features/license/domain/entities/license.dart';
import '../../features/license/domain/repositories/license_repository.dart';
import 'sync_queue.dart';
import 'sync_queue_repository.dart';
import 'sync_status.dart';
import 'sync_worker.dart';
import 'connectivity_service.dart';

/// Main sync orchestrator.
///
/// - Offline license: no background sync — data stays local.
/// - Online license: enqueue changes and process on network availability.
class SyncService {
  static final SyncService instance = SyncService._();
  SyncService._();

  LicenseRepository? _licenseRepository;

  void init(LicenseRepository licenseRepository) {
    _licenseRepository = licenseRepository;

    // When network is restored, run the sync worker
    ConnectivityService.instance.onNetworkRestored(() {
      _runWorker();
    });
  }

  /// Enqueue a create/update/delete for syncing, but only for Online licenses.
  /// For Offline licenses this is a no-op (data stays local only).
  Future<void> enqueue({
    required String tableName,
    required String recordId,
    required SyncOperation operation,
    required Map<String, dynamic> payload,
  }) async {
    final license = await _licenseRepository?.getCachedLicense();
    if (license == null || license.licenseType != LicenseType.online) return;

    await SyncQueueRepository.instance.enqueue(
      tableName: tableName,
      recordId: recordId,
      operation: operation,
      payload: payload,
    );

    // Try to sync immediately if online
    if (ConnectivityService.instance.isOnline) {
      _runWorker();
    }
  }

  /// Run the worker in a fire-and-forget manner.
  void _runWorker() {
    if (_licenseRepository == null) return;
    SyncWorker.instance.run(_licenseRepository!);
  }

  /// Call on app foreground to catch up any pending items.
  Future<void> syncNow() async {
    if (_licenseRepository == null) return;
    if (!ConnectivityService.instance.isOnline) return;
    await SyncWorker.instance.run(_licenseRepository!);
  }

  /// Returns how many items are pending sync.
  Future<int> pendingCount() => SyncQueueRepository.instance.pendingCount();
}
