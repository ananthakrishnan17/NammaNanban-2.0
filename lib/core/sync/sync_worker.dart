import 'package:flutter/foundation.dart';

import '../../features/license/domain/repositories/license_repository.dart';
import '../supabase/supabase_config.dart';
import 'sync_queue.dart';
import 'sync_queue_repository.dart';
import 'sync_status.dart';

/// Processes pending sync queue items by uploading them to Supabase.
/// Runs for any valid license (online or offline).
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
    if (_isRunning) {
      debugPrint('[SyncWorker] already running — skipped');
      return;
    }
    _isRunning = true;
    debugPrint('[SyncWorker] started');
    try {
      final license = await licenseRepository.getCachedLicense();
      if (license == null || !license.isValid) {
        debugPrint('[SyncWorker] no valid license — aborting');
        return;
      }
      debugPrint('[SyncWorker] license ok — '
          'id=${license.id} type=${license.licenseType.value}');

      final pending = await SyncQueueRepository.instance.getPending();
      debugPrint('[SyncWorker] ${pending.length} item(s) pending');
      int synced = 0;
      int failed = 0;
      int skipped = 0;
      for (final item in pending) {
        // Skip items that have permanently exhausted their retries.
        // They remain in the queue as "failed" so the user can see them.
        if (item.retryCount >= _maxRetries) {
          debugPrint('[SyncWorker] skipping ${item.tableName}/${item.recordId} '
              '(retries exhausted: ${item.retryCount}/$_maxRetries)');
          skipped++;
          continue;
        }
        final ok = await _processItem(item, license.id);
        if (ok) synced++; else failed++;
      }
      await SyncQueueRepository.instance.deleteSynced();
      debugPrint('[SyncWorker] done — synced=$synced failed=$failed skipped=$skipped');
    } finally {
      _isRunning = false;
    }
  }

  Future<bool> _processItem(SyncQueueItem item, String licenseId) async {
    final id = item.id!;
    try {
      debugPrint('[SyncWorker] syncing ${item.tableName}/${item.recordId} '
          '(attempt ${item.retryCount + 1}/$_maxRetries)');
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
      debugPrint('[SyncWorker] ✓ synced ${item.tableName}/${item.recordId}');
      return true;
    } catch (e) {
      debugPrint('[SyncWorker] ✗ failed ${item.tableName}/${item.recordId} '
          '(retry ${item.retryCount + 1}/$_maxRetries): $e');
      // Increment retryCount.  If it reaches _maxRetries the item will be
      // skipped on the next run but kept in the queue as "failed" for
      // visibility.  Re-enqueueing the record (e.g. after a user edit) resets
      // the count so the item gets a fresh set of attempts.
      await SyncQueueRepository.instance.updateStatus(
        id,
        SyncStatus.failed,
        retryCount: item.retryCount + 1,
      );
      return false;
    }
  }

  /// Returns the composite conflict key for upsert based on [tableName].
  ///
  /// The key must match a UNIQUE constraint defined in the Supabase schema.
  /// Using a composite key that includes `license_id` prevents cross-tenant
  /// conflicts when multiple businesses share the same Supabase project.
  ///
  /// Supabase schema requirements per table:
  ///   bills_sync        — UNIQUE(license_id, local_bill_id)
  ///   products_sync     — UNIQUE(license_id, local_product_id)
  ///   expenses_sync     — UNIQUE(license_id, local_expense_id)
  ///   purchases_sync    — UNIQUE(license_id, local_purchase_id)
  ///   transactions_sync — UNIQUE(license_id, local_tx_id)
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
      case 'transactions_sync':
        return 'license_id, local_tx_id';
      default:
        return 'id';
    }
  }
}
