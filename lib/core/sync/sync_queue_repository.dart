
import 'dart:convert';

import '../database/database_helper.dart';
import 'sync_queue.dart';
import 'sync_status.dart';

/// Manages the local sync_queue SQLite table.
class SyncQueueRepository {
  static final SyncQueueRepository instance = SyncQueueRepository._();
  SyncQueueRepository._();

  Future<void> enqueue({
    required String tableName,
    required String recordId,
    required SyncOperation operation,
    required Map<String, dynamic> payload,
  }) async {
    final db = await DatabaseHelper.instance.database;
    final now = DateTime.now().toIso8601String();

    // Dedup: if a pending/failed entry already exists for this record, update
    // its payload and reset it to pending instead of inserting a duplicate.
    // This prevents accumulating multiple rows for the same record on retries.
    final existing = await db.query(
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
      await db.update(
        'sync_queue',
        {
          'payload': jsonEncode(payload),
          'operation': operation.value,
          'status': SyncStatus.pending.value,
          'retry_count': 0,
          'updated_at': now,
        },
        where: 'id = ?',
        whereArgs: [existing.first['id']],
      );
      return;
    }

    final item = SyncQueueItem(
      tableName: tableName,
      recordId: recordId,
      operation: operation,
      payload: payload,
      status: SyncStatus.pending,
      createdAt: DateTime.now(),
    );
    await db.insert('sync_queue', {
      ...item.toMap(),
      'updated_at': now,
    });
  }

  Future<List<SyncQueueItem>> getPending() async {
    final db = await DatabaseHelper.instance.database;
    final rows = await db.query(
      'sync_queue',
      where: "status = ? OR status = ?",
      whereArgs: [SyncStatus.pending.value, SyncStatus.failed.value],
      orderBy: 'created_at ASC',
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
