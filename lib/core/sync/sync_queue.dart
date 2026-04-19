import 'dart:convert';

import 'sync_status.dart';

/// Represents a single entry in the sync queue
class SyncQueueItem {
  final int? id;
  final String tableName;
  final String recordId;
  final SyncOperation operation;
  final Map<String, dynamic> payload;
  final SyncStatus status;
  final DateTime createdAt;
  final int retryCount;

  const SyncQueueItem({
    this.id,
    required this.tableName,
    required this.recordId,
    required this.operation,
    required this.payload,
    required this.status,
    required this.createdAt,
    this.retryCount = 0,
  });

  Map<String, dynamic> toMap() => {
        if (id != null) 'id': id,
        'table_name': tableName,
        'record_id': recordId,
        'operation': operation.value,
        'payload': jsonEncode(payload),
        'status': status.value,
        'created_at': createdAt.toIso8601String(),
        'retry_count': retryCount,
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
      );

  SyncQueueItem copyWith({SyncStatus? status, int? retryCount}) => SyncQueueItem(
        id: id,
        tableName: tableName,
        recordId: recordId,
        operation: operation,
        payload: payload,
        status: status ?? this.status,
        createdAt: createdAt,
        retryCount: retryCount ?? this.retryCount,
      );
}
