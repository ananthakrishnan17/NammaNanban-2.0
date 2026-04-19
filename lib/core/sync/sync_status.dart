/// Status of a single sync queue item
enum SyncStatus {
  pending,
  syncing,
  synced,
  failed;

  String get value => name;

  static SyncStatus fromString(String? s) {
    return SyncStatus.values.firstWhere(
      (e) => e.value == s,
      orElse: () => SyncStatus.pending,
    );
  }
}

/// Operation type for a sync queue entry
enum SyncOperation {
  create,
  update,
  delete;

  String get value => name;

  static SyncOperation fromString(String? s) {
    return SyncOperation.values.firstWhere(
      (e) => e.value == s,
      orElse: () => SyncOperation.create,
    );
  }
}
