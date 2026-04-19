import '../../features/license/domain/entities/license.dart';
import '../../features/license/domain/repositories/license_repository.dart';
import '../supabase/supabase_config.dart';
import 'sync_queue.dart';
import 'sync_queue_repository.dart';
import 'sync_status.dart';

/// Processes pending sync queue items by uploading them to Supabase.
/// Only runs for Online license users.
class SyncWorker {
  static final SyncWorker instance = SyncWorker._();
  SyncWorker._();

  bool _isRunning = false;

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

      final payload = {...item.payload, 'license_id': licenseId};

      switch (item.operation) {
        case SyncOperation.create:
          await SupabaseClientHelper.table(item.tableName)
              .upsert(payload, onConflict: 'id');
        case SyncOperation.update:
          await SupabaseClientHelper.table(item.tableName)
              .upsert(payload, onConflict: 'id');
        case SyncOperation.delete:
          final recordId = item.recordId;
          await SupabaseClientHelper.table(item.tableName)
              .delete()
              .eq('id', recordId);
      }

      await SyncQueueRepository.instance.updateStatus(id, SyncStatus.synced);
    } catch (_) {
      await SyncQueueRepository.instance.updateStatus(
        id,
        SyncStatus.failed,
        retryCount: (item.retryCount) + 1,
      );
    }
  }
}
