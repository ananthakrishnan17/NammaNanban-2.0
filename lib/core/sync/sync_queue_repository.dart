
import 'dart:convert';

import '../database/database_helper.dart';
import 'sync_queue.dart';
import 'sync_status.dart';

/// Manages the local sync_queue SQLite table.
///
/// ## Conflict resolution strategy
/// This repository enforces three properties needed for a correct
/// offline-first sync system:
///
/// 1. **Deduplication at enqueue time** — only one pending/failed row exists
///    per (table_name, record_id) pair.  A new call with the same pair updates
///    the existing row in-place inside a SQLite transaction, ensuring the
///    *latest* payload is always what gets sent to the server.
///
/// 2. **Last-write-wins (LWW) via `updated_at`** — the timestamp recorded in
///    each row reflects when the local change was made.  The sync worker
///    embeds this timestamp in the Supabase payload so the server can apply
///    LWW: a row is only overwritten on the server if the incoming
///    `updated_at` is ≥ the server's current `updated_at`.
///
/// 3. **Device traceability via `device_id`** — every row captures the
///    originating device ID so that multi-device conflicts can be audited and
///    replayed if necessary.
class SyncQueueRepository {
  static final SyncQueueRepository instance = SyncQueueRepository._();
  SyncQueueRepository._();

  /// Add or refresh a pending sync item.
  ///
  /// If a pending/failed row for the same (table_name, record_id) already
  /// exists it is updated in-place (payload refreshed, status reset to
  /// pending, retry_count zeroed). This prevents duplicate rows and ensures
  /// the server always receives the most recent payload — a key property for
  /// last-write-wins correctness.
  ///
  /// [deviceId] is stored as a dedicated column so it is available for
  /// diagnostics even before the payload is decoded.
  Future<void> enqueue({
    required String tableName,
    required String recordId,
    required SyncOperation operation,
    required Map<String, dynamic> payload,
    String? deviceId,
  }) async {
    final db = await DatabaseHelper.instance.database;
    final now = DateTime.now().toIso8601String();

    // Atomic check-and-upsert: wrap in a transaction so that two concurrent
    // enqueue calls for the same record cannot both pass the duplicate check
    // and insert separate rows.
    await db.transaction((txn) async {
      final existing = await txn.query(
        'sync_queue',
        where: 'table_name = ? AND record_id = ? AND (status = ? OR status = ?)',
        whereArgs: [
          tableName,
          recordId,
          SyncStatus.pending.value,
          SyncStatus.failed.value,
        ],
        limit: 1,
      );

      if (existing.isNotEmpty) {
        // Update payload + reset to pending so the latest data is synced.
        // Resetting retry_count ensures the refreshed item gets a full
        // round of retries, preventing silent stale-data failures.
        await txn.update(
          'sync_queue',
          {
            'payload': jsonEncode(payload),
            'operation': operation.value,
            'status': SyncStatus.pending.value,
            'retry_count': 0,
            // Bump updated_at so last-write-wins comparison on the server
            // always sees the newest timestamp for this record.
            'updated_at': now,
            if (deviceId != null) 'device_id': deviceId,
          },
          where: 'id = ?',
          whereArgs: [existing.first['id']],
        );
      } else {
        final item = SyncQueueItem(
          tableName: tableName,
          recordId: recordId,
          operation: operation,
          payload: payload,
          status: SyncStatus.pending,
          createdAt: DateTime.now(),
          deviceId: deviceId,
        );
        await txn.insert('sync_queue', {
          ...item.toMap(),
          'updated_at': now,
        });
      }
    });
  }

  /// Returns all pending and failed items ordered by [updated_at] ascending.
  ///
  /// Ordering by [updated_at] rather than [created_at] ensures that items
  /// which have been refreshed (e.g. edited while offline) are processed with
  /// their correct chronological position relative to other writes, which is
  /// important for tables that rely on event ordering.
  Future<List<SyncQueueItem>> getPending() async {
    final db = await DatabaseHelper.instance.database;
    final rows = await db.query(
      'sync_queue',
      where: "status = ? OR status = ?",
      whereArgs: [SyncStatus.pending.value, SyncStatus.failed.value],
      orderBy: 'updated_at ASC',
    );
    return rows.map(SyncQueueItem.fromMap).toList();
  }

  Future<void> updateStatus(int id, SyncStatus status,
      {int? retryCount}) async {
    final db = await DatabaseHelper.instance.database;
    await db.update(
      'sync_queue',
      {
        'status': status.value,
        if (retryCount != null) 'retry_count': retryCount,
        // Stamp the time so last-write-wins comparisons are accurate
        'updated_at': DateTime.now().toIso8601String(),
      },
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<void> deleteSynced() async {
    final db = await DatabaseHelper.instance.database;
    await db.delete(
      'sync_queue',
      where: "status = ?",
      whereArgs: [SyncStatus.synced.value],
    );
  }

  Future<int> pendingCount() async {
    final db = await DatabaseHelper.instance.database;
    final result = await db.rawQuery(
      "SELECT COUNT(*) as count FROM sync_queue WHERE status = ? OR status = ?",
      [SyncStatus.pending.value, SyncStatus.failed.value],
    );
    return (result.first['count'] as int?) ?? 0;
  }
}
