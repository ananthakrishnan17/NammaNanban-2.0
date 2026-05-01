import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:intl/intl.dart';

import '../../../../core/database/database_helper.dart';
import '../../../../core/sync/sync_queue.dart';
import '../../../../core/sync/sync_status.dart';
import '../../../../core/theme/app_theme.dart';

/// Sync Monitor — shows the sync_queue table contents with status breakdown.
/// Only visible to admin users (enforced in SettingsPage).
class SyncStatusPage extends StatefulWidget {
  const SyncStatusPage({super.key});

  @override
  State<SyncStatusPage> createState() => _SyncStatusPageState();
}

class _SyncStatusPageState extends State<SyncStatusPage> {
  List<SyncQueueItem> _items = [];
  bool _isLoading = false;
  String _filter = 'all'; // all, pending, failed, synced

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _isLoading = true);
    try {
      final db = await DatabaseHelper.instance.database;
      final rows = await db.query('sync_queue', orderBy: 'created_at DESC', limit: 200);
      setState(() => _items = rows.map(SyncQueueItem.fromMap).toList());
    } catch (_) {}
    setState(() => _isLoading = false);
  }

  Future<void> _clearSynced() async {
    try {
      final db = await DatabaseHelper.instance.database;
      await db.delete('sync_queue', where: "status = 'synced'");
      _load();
    } catch (_) {}
  }

  List<SyncQueueItem> get _filtered {
    if (_filter == 'all') return _items;
    return _items.where((i) => i.status.value == _filter).toList();
  }

  @override
  Widget build(BuildContext context) {
    final pending = _items.where((i) => i.status == SyncStatus.pending).length;
    final failed = _items.where((i) => i.status == SyncStatus.failed).length;
    final synced = _items.where((i) => i.status == SyncStatus.synced).length;

    return Scaffold(
      backgroundColor: AppTheme.surface,
      appBar: AppBar(
        title: const Text('Sync Monitor'),
        actions: [
          IconButton(
            icon: const Icon(Icons.delete_sweep),
            tooltip: 'Clear synced',
            onPressed: synced > 0 ? _clearSynced : null,
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _load,
          ),
        ],
      ),
      body: Column(
        children: [
          // Summary cards
          Container(
            color: Colors.white,
            padding: EdgeInsets.all(16.w),
            child: Row(children: [
              _statChip('Pending', pending, AppTheme.warning),
              SizedBox(width: 10.w),
              _statChip('Failed', failed, AppTheme.danger),
              SizedBox(width: 10.w),
              _statChip('Synced', synced, AppTheme.accent),
            ]),
          ),

          // Filter chips
          Container(
            color: Colors.white,
            padding: EdgeInsets.fromLTRB(16.w, 0, 16.w, 10.h),
            child: Row(children: [
              for (final f in ['all', 'pending', 'failed', 'synced'])
                GestureDetector(
                  onTap: () => setState(() => _filter = f),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 180),
                    margin: EdgeInsets.only(right: 8.w),
                    padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 5.h),
                    decoration: BoxDecoration(
                      color: _filter == f ? AppTheme.primary : AppTheme.surface,
                      borderRadius: BorderRadius.circular(20.r),
                      border: Border.all(
                          color: _filter == f ? AppTheme.primary : AppTheme.divider),
                    ),
                    child: Text(
                      f[0].toUpperCase() + f.substring(1),
                      style: TextStyle(
                        fontSize: 12.sp,
                        fontWeight: FontWeight.w600,
                        fontFamily: 'Poppins',
                        color: _filter == f ? Colors.white : AppTheme.textSecondary,
                      ),
                    ),
                  ),
                ),
            ]),
          ),

          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _filtered.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.cloud_done, size: 48.sp, color: AppTheme.accent),
                            SizedBox(height: 10.h),
                            Text('No items', style: AppTheme.caption),
                          ],
                        ),
                      )
                    : ListView.separated(
                        padding: EdgeInsets.all(16.w),
                        itemCount: _filtered.length,
                        separatorBuilder: (_, __) => SizedBox(height: 8.h),
                        itemBuilder: (_, i) {
                          final item = _filtered[i];
                          return Container(
                            padding: EdgeInsets.all(12.w),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(10.r),
                              border: Border.all(color: _statusColor(item.status).withOpacity(0.3)),
                            ),
                            child: Row(children: [
                              Container(
                                width: 8.w,
                                height: 8.w,
                                margin: EdgeInsets.only(right: 10.w),
                                decoration: BoxDecoration(
                                  color: _statusColor(item.status),
                                  shape: BoxShape.circle,
                                ),
                              ),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      '${item.tableName} • ${item.operation.value}',
                                      style: AppTheme.body.copyWith(fontWeight: FontWeight.w600),
                                    ),
                                    Text(
                                      'ID: ${item.recordId}  •  ${_fmtDate(item.createdAt)}',
                                      style: AppTheme.caption,
                                    ),
                                    if (item.retryCount > 0)
                                      Text('Retries: ${item.retryCount}',
                                          style: AppTheme.caption
                                              .copyWith(color: AppTheme.danger)),
                                  ],
                                ),
                              ),
                              Container(
                                padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 3.h),
                                decoration: BoxDecoration(
                                  color: _statusColor(item.status).withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(6.r),
                                ),
                                child: Text(
                                  item.status.value.toUpperCase(),
                                  style: TextStyle(
                                    fontSize: 10.sp,
                                    fontWeight: FontWeight.w700,
                                    fontFamily: 'Poppins',
                                    color: _statusColor(item.status),
                                  ),
                                ),
                              ),
                            ]),
                          );
                        },
                      ),
          ),
        ],
      ),
    );
  }

  Color _statusColor(SyncStatus s) {
    switch (s) {
      case SyncStatus.pending: return AppTheme.warning;
      case SyncStatus.failed: return AppTheme.danger;
      case SyncStatus.synced: return AppTheme.accent;
      case SyncStatus.syncing: return AppTheme.primary;
    }
  }

  Widget _statChip(String label, int count, Color color) => Expanded(
    child: Container(
      padding: EdgeInsets.symmetric(vertical: 10.h),
      decoration: BoxDecoration(
        color: color.withOpacity(0.08),
        borderRadius: BorderRadius.circular(10.r),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Column(children: [
        Text('$count', style: TextStyle(fontSize: 18.sp, fontWeight: FontWeight.w700,
            color: color, fontFamily: 'Poppins')),
        Text(label, style: AppTheme.caption),
      ]),
    ),
  );

  String _fmtDate(DateTime d) => DateFormat('dd MMM HH:mm').format(d);
}
