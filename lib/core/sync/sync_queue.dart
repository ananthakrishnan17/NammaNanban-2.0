import 'dart:convert';

import 'sync_status.dart';

/// Represents a single entry in the sync queue.
///
/// ## Conflict resolution — last-write-wins (LWW)
/// Each item carries [updatedAt] which is the wall-clock time on the originating
/// device at the moment the change was enqueued.  When the worker uploads the
/// item to Supabase it includes this timestamp in the payload so the server can
/// compare it against any existing row and keep only the most recent write.
///
/// [deviceId] identifies which device produced the change. It is stored both in
/// the local queue row (for diagnostics) and forwarded inside the Supabase
/// payload so multi-device conflicts can be audited.
///
/// ## Deduplication
/// The local [SyncQueueRepository.enqueue] call is wrapped in a SQLite
/// transaction that checks for an existing pending/failed row with the same
/// (table_name, record_id). If one is found the row is updated in-place rather
/// than inserting a duplicate — ensuring only one pending entry exists per
/// record at any time.
class SyncQueueItem {
  final int? id;
  final String tableName;
  final String recordId;
  final SyncOperation operation;
  final Map<String, dynamic> payload;
  final SyncStatus status;
  final DateTime createdAt;
  final int retryCount;

  /// Wall-clock time of the last local write — used for LWW conflict resolution.
  final DateTime updatedAt;

  /// Device identifier of the originating device — forwarded to Supabase for
  /// multi-device conflict auditing.
  final String? deviceId;

  SyncQueueItem({
    this.id,
    required this.tableName,
    required this.recordId,
    required this.operation,
    required this.payload,
    required this.status,
    required this.createdAt,
    this.retryCount = 0,
    DateTime? updatedAt,
    this.deviceId,
  }) : updatedAt = updatedAt ?? createdAt;

  Map<String, dynamic> toMap() => {
        if (id != null) 'id': id,
        'table_name': tableName,
        'record_id': recordId,
        'operation': operation.value,
        'payload': jsonEncode(payload),
        'status': status.value,
        'created_at': createdAt.toIso8601String(),
        'retry_count': retryCount,
        'updated_at': updatedAt.toIso8601String(),
        if (deviceId != null) 'device_id': deviceId,
      };

  factory SyncQueueItem.fromMap(Map<String, dynamic> m) => SyncQueueItem(
        id: m['id'] as int?,
        tableName: m['table_name'] as String,
        recordId: m['record_id'] as String,
        operation: SyncOperation.fromString(m['operation'] as String?),
        payload: jsonDecode(m['payload'] as String) as Map<String, dynamic>,
        status: SyncStatus.fromString(m['status'] as String?),
        createdAt: DateTime.parse(m['created_at'] as String),
        retryCount: m['retry_count'] as int? ?? 0,
        updatedAt: m['updated_at'] != null
            ? DateTime.parse(m['updated_at'] as String)
            : null,
        deviceId: m['device_id'] as String?,
      );

  SyncQueueItem copyWith({
    SyncStatus? status,
    int? retryCount,
    DateTime? updatedAt,
  }) =>
      SyncQueueItem(
        id: id,
        tableName: tableName,
        recordId: recordId,
        operation: operation,
        payload: payload,
        status: status ?? this.status,
        createdAt: createdAt,
        retryCount: retryCount ?? this.retryCount,
        updatedAt: updatedAt ?? this.updatedAt,
        deviceId: deviceId,
      );
}
