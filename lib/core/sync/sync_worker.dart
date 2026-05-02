import 'package:flutter/foundation.dart';

import '../../features/license/domain/entities/license.dart';
import '../../features/license/domain/repositories/license_repository.dart';
import '../supabase/supabase_config.dart';
import 'sync_queue.dart';
import 'sync_queue_repository.dart';
import 'sync_status.dart';

/// Processes pending sync queue items by uploading them to Supabase.
/// Only runs for Online license users.
///
/// ## Retry mechanism
/// Each item carries a [SyncQueueItem.retryCount]. If processing fails the
/// count is incremented.  Items that have reached [_maxRetries] are skipped
/// on every subsequent worker run (they remain visible as "failed" in the UI
/// so the user can take action).  Because [SyncQueueRepository.enqueue] resets
/// the count to 0 whenever the same record is re-enqueued, a user edit while
/// the app is offline effectively re-activates a previously exhausted item
/// without any extra logic here.
///
/// ## Idempotency
/// Every write to Supabase uses `upsert` with a composite conflict key
/// (see [_conflictKey]).  This means sending the same payload twice produces
/// exactly one row on the server — it is safe to retry any item without risk
/// of duplicates.
///
/// ## Last-write-wins (LWW)
/// The payload forwarded to Supabase contains an `updated_at` timestamp that
/// was set on the device at the moment the change was made (see
/// [SyncService.enqueue]).  A Supabase trigger can use this value to reject
/// incoming upserts that are older than the server's current row, ensuring
/// only the most-recent write survives when two devices race to sync the same
/// record.  The local queue processes items in `updated_at` order (oldest
/// first) so earlier writes are always submitted before newer ones.
class SyncWorker {
  static final SyncWorker instance = SyncWorker._();
  SyncWorker._();

  bool _isRunning = false;

  /// Maximum number of upload attempts per queue item before it is marked
  /// permanently failed and skipped.  The item can be re-activated by
  /// re-enqueueing the same record (which resets the count).
  static const int _maxRetries = 5;

  /// Run the worker. Safe to call multiple times — only one run at a time.
  Future<void> run(LicenseRepository licenseRepository) async {
    if (_isRunning) return;
    _isRunning = true;
    try {
      final license = await licenseRepository.getCachedLicense();
      if (license == null || !license.isValid) return;
      // Only sync for online license
      if (license.licenseType != LicenseType.online) return;

      final pending = await SyncQueueRepository.instance.getPending();
      for (final item in pending) {
        // Skip items that have permanently exhausted their retries.
        // They remain in the queue as "failed" so the user can see them.
        if (item.retryCount >= _maxRetries) continue;
        await _processItem(item, license.id);
      }
      await SyncQueueRepository.instance.deleteSynced();
    } finally {
      _isRunning = false;
    }
  }

  Future<void> _processItem(SyncQueueItem item, String licenseId) async {
    final id = item.id!;
    try {
      await SyncQueueRepository.instance.updateStatus(id, SyncStatus.syncing);

      // Merge license_id into the payload last so it cannot be overridden by
      // caller-supplied data.  The payload already contains `updated_at` and
      // `device_id` stamped at enqueue time — forwarding them unchanged
      // preserves the original LWW timestamp on the server.
      final payload = {...item.payload, 'license_id': licenseId};

      // Determine the correct composite conflict key per table.
      // This key tells Supabase which columns to use when deciding whether an
      // incoming row is a duplicate.  Using a composite key that includes
      // license_id prevents cross-tenant collisions when multiple shops share
      // the same Supabase project.
      final onConflict = _conflictKey(item.tableName);

      switch (item.operation) {
        case SyncOperation.create:
          // upsert is used even for creates so that a retry after a partial
          // failure does not produce duplicate rows (idempotent create).
          await SupabaseClientHelper.table(item.tableName)
              .upsert(payload, onConflict: onConflict);
        case SyncOperation.update:
          // upsert handles update: if the row exists it is overwritten; if it
          // was never synced it is created.  The server-side updated_at trigger
          // will reject the write if a newer version already exists (LWW).
          await SupabaseClientHelper.table(item.tableName)
              .upsert(payload, onConflict: onConflict);
        case SyncOperation.delete:
          final recordId = item.recordId;
          await SupabaseClientHelper.table(item.tableName)
              .delete()
              .eq('id', recordId);
      }

      await SyncQueueRepository.instance.updateStatus(id, SyncStatus.synced);
    } catch (e) {
      debugPrint('[SyncWorker] Failed to sync item ${item.id} '
          '(${item.tableName}/${item.recordId}): $e');
      // Increment retryCount.  If it reaches _maxRetries the item will be
      // skipped on the next run but kept in the queue as "failed" for
      // visibility.  Re-enqueueing the record (e.g. after a user edit) resets
      // the count so the item gets a fresh set of attempts.
      await SyncQueueRepository.instance.updateStatus(
        id,
        SyncStatus.failed,
        retryCount: item.retryCount + 1,
      );
    }
  }

  /// Returns the composite conflict key for upsert based on [tableName].
  ///
  /// The key must match a UNIQUE constraint defined in the Supabase schema.
  /// Using a composite key that includes `license_id` prevents cross-tenant
  /// conflicts when multiple businesses share the same Supabase project.
  String _conflictKey(String tableName) {
    switch (tableName) {
      case 'bills_sync':
        return 'license_id, local_bill_id';
      case 'products_sync':
        return 'license_id, local_product_id';
      case 'expenses_sync':
        return 'license_id, local_expense_id';
      case 'purchases_sync':
        return 'license_id, local_purchase_id';
      default:
        return 'id';
    }
  }
}
