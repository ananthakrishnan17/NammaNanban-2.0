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
///
/// ## Conflict resolution
/// Each enqueued change is enriched with two fields before it is forwarded to
/// [SyncQueueRepository.enqueue]:
///
/// * `updated_at` — ISO-8601 wall-clock timestamp of the write on this device.
///   The Supabase schema uses this for last-write-wins (LWW): a server-side
///   trigger rejects incoming upserts whose `updated_at` is older than the
///   existing row's value, so the most recent edit always wins regardless of
///   which device syncs first.
///
/// * `device_id` — stable identifier of this device, stored both as a
///   first-class column in sync_queue and inside the payload forwarded to
///   Supabase, enabling multi-device conflict auditing.
///
/// The [SyncQueueRepository] ensures there is at most one pending row per
/// (table_name, record_id) at any time, so rapid offline edits do not pile up
/// into duplicate sync requests.
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
  ///
  /// The payload is automatically enriched with [device_id] and [updated_at]
  /// so that Supabase can perform last-write-wins conflict resolution.
  /// ⚠️  Requires Supabase schema to have `device_id` and `updated_at` columns
  ///     on the target table (see supabase/schema.sql migration v12).
  Future<void> enqueue({
    required String tableName,
    required String recordId,
    required SyncOperation operation,
    required Map<String, dynamic> payload,
  }) async {
    final license = await _licenseRepository?.getCachedLicense();
    if (license == null) {
      debugPrint('[SyncService] enqueue skipped ($tableName/$recordId): '
          'no cached license — activate a license first');
      return;
    }
    if (license.licenseType != LicenseType.online) {
      debugPrint('[SyncService] enqueue skipped ($tableName/$recordId): '
          'license is ${license.licenseType.value} — only online licenses sync to cloud');
      return;
    }

    final now = DateTime.now().toIso8601String();

    // Enrich payload with device context for last-write-wins conflict resolution.
    // updated_at lets the Supabase upsert determine which write is newer.
    // device_id helps trace which device originated the change.
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
      // Also stored as a first-class column for diagnostics without decoding
      // the payload JSON.
      deviceId: license.deviceId,
    );
    debugPrint('[SyncService] enqueued $tableName/$recordId (${operation.value})');

    // Try to sync immediately if online
    if (ConnectivityService.instance.isOnline) {
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
    if (!ConnectivityService.instance.isOnline) return;
    await SyncWorker.instance.run(_licenseRepository!);
  }

  /// Returns how many items are pending sync.
  Future<int> pendingCount() => SyncQueueRepository.instance.pendingCount();
}
