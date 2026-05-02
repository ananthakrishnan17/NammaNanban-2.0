import 'package:flutter/foundation.dart';

import '../../features/license/domain/repositories/license_repository.dart';
import 'sync_queue.dart';
import 'sync_queue_repository.dart';
import 'sync_status.dart';
import 'sync_worker.dart';
import 'connectivity_service.dart';

/// Main sync orchestrator.
///
/// Any valid license (online or offline) may enqueue changes — the license
/// type no longer blocks sync. Data is queued locally on every write and
/// uploaded to Supabase whenever a network connection is available.
///
/// ## Sync decision logic
/// 1. A cached license must exist (needed for `device_id` / `license.id`).
/// 2. `ConnectivityService.isOnline` must be true **at the time of the
///    immediate-fire trigger**. Items queued while offline are uploaded later
///    when the network is restored via the [ConnectivityService.onNetworkRestored]
///    callback registered in [init].
///
/// ## Conflict resolution
/// Each enqueued change is enriched with two fields before it is forwarded to
/// [SyncQueueRepository.enqueue]:
///
/// * `updated_at` — ISO-8601 wall-clock timestamp of the write on this device.
///   The Supabase schema uses this for last-write-wins (LWW).
///
/// * `device_id` — stable identifier of this device, forwarded to Supabase for
///   multi-device conflict auditing.
class SyncService {
  static final SyncService instance = SyncService._();
  SyncService._();

  LicenseRepository? _licenseRepository;

  void init(LicenseRepository licenseRepository) {
    _licenseRepository = licenseRepository;

    // When network is restored, run the sync worker
    ConnectivityService.instance.onNetworkRestored(() {
      debugPrint('[SyncService] network restored — running worker');
      _runWorker();
    });
  }

  /// Enqueue a create/update/delete for syncing.
  ///
  /// Requires only that a valid cached license exists. The license type
  /// (`online`/`offline`) no longer prevents enqueueing — all license types
  /// sync to Supabase when internet is available.
  ///
  /// The payload is automatically enriched with [device_id] and [updated_at]
  /// so that Supabase can perform last-write-wins conflict resolution.
  Future<void> enqueue({
    required String tableName,
    required String recordId,
    required SyncOperation operation,
    required Map<String, dynamic> payload,
  }) async {
    final isOnline = ConnectivityService.instance.isOnline;
    final license = await _licenseRepository?.getCachedLicense();

    debugPrint('[SyncService] enqueue check — '
        'table=$tableName id=$recordId '
        'isOnline=$isOnline '
        'licenseType=${license?.licenseType.value ?? "none"} '
        'licenseValid=${license?.isValid}');

    if (license == null) {
      debugPrint('[SyncService] enqueue skipped ($tableName/$recordId): '
          'no cached license — activate a license first');
      return;
    }

    final now = DateTime.now().toIso8601String();

    // Enrich payload with device context for last-write-wins conflict resolution.
    final enrichedPayload = {
      ...payload,
      'device_id': license.deviceId,
      'updated_at': now,
    };

    await SyncQueueRepository.instance.enqueue(
      tableName: tableName,
      recordId: recordId,
      operation: operation,
      payload: enrichedPayload,
      deviceId: license.deviceId,
    );
    debugPrint('[SyncService] ✓ enqueued $tableName/$recordId (${operation.value}) '
        '— licenseType=${license.licenseType.value}');

    // Try to sync immediately if online
    if (isOnline) {
      debugPrint('[SyncService] online — triggering worker for $tableName/$recordId');
      _runWorker();
    } else {
      debugPrint('[SyncService] offline — $tableName/$recordId queued, '
          'will sync when network restores');
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
    if (!ConnectivityService.instance.isOnline) {
      debugPrint('[SyncService] syncNow skipped — offline');
      return;
    }
    debugPrint('[SyncService] syncNow — running worker');
    await SyncWorker.instance.run(_licenseRepository!);
  }

  /// Returns how many items are pending sync.
  Future<int> pendingCount() => SyncQueueRepository.instance.pendingCount();
}
