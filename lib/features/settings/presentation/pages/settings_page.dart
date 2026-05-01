import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:image_picker/image_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../../core/l10n/app_localizations.dart';
import '../../../../core/supabase/supabase_auth_service.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../auth/presentation/pages/login_screen.dart';
import '../../../auth/presentation/pages/set_pin_screen.dart';
import '../../../backup/services/backup_service.dart';
import '../../../day_close/day_close_page.dart';
import '../../../masters/presentation/pages/masters_page.dart';
import '../../../printer/presentation/pages/printer_settings_page.dart';
import '../../../purchase/presentation/pages/add_purchase_page.dart';
import '../../../purchase_return/purchase_return_page.dart';
import '../../../sale_return/presentation/pages/sale_return_page.dart';
import '../../../subscription/services/subscription_service.dart';
import '../../../subscription/presentation/pages/subscription_lock_screen.dart';
import '../../../users/domain/entities/app_user.dart';
import '../../../users/domain/entities/users_page.dart';
import 'language_settings_page.dart';
import 'sync_status_page.dart';

class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});
  @override State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  String _shopName='', _shopAddress='', _shopPhone='', _logoPath='';
  bool _isBackingUp=false, _isRestoring=false;
  int _daysLeft=0;
  SubscriptionStatus _subStatus = SubscriptionStatus.active;

  bool _logoFileExists = false;

  @override void initState() { super.initState(); _load(); }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    final status = await SubscriptionService.instance.getStatus();
    final days = await SubscriptionService.instance.getDaysLeft();
    if (mounted) setState(() {
      _shopName = prefs.getString('shop_name') ?? '';
      _shopAddress = prefs.getString('shop_address') ?? '';
      _shopPhone = prefs.getString('shop_phone') ?? '';
      _logoPath = prefs.getString('logo_path') ?? '';
      _logoFileExists = _logoPath.isNotEmpty && File(_logoPath).existsSync();
      _subStatus = status; _daysLeft = days;
    });
  }

  @override
  Widget build(BuildContext context) {
    final lang = AppLocalizations.instance;
    final currentUser = context.read<UserBloc>().currentUser;
    final isAdmin = currentUser?.isAdmin == true;
    return Scaffold(
      appBar: AppBar(title: Text(lang.t('settings')),
          actions: [IconButton(onPressed: () => _logout(context), icon: const Icon(Icons.logout, color: AppTheme.danger), tooltip: lang.t('logout'))]),
      body: SingleChildScrollView(
        padding: EdgeInsets.all(16.w),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [

          // Subscription
          _buildSubCard(),
          SizedBox(height: 16.h),

          // Shop Info
          _head('🏪  ${lang.t("shop_info")}'),
          _card([
            if (_logoFileExists) ...[
              Padding(
                padding: EdgeInsets.symmetric(vertical: 10.h),
                child: Row(children: [
                  CircleAvatar(backgroundImage: FileImage(File(_logoPath)), radius: 28.r),
                  SizedBox(width: 10.w),
                  Text('Shop Logo', style: AppTheme.caption),
                ]),
              ),
              _div(),
            ],
            _info('Shop Name', _shopName.isEmpty ? 'Not set' : _shopName),
            _div(), _info('Address', _shopAddress.isEmpty ? 'Not set' : _shopAddress),
            _div(), _info('Phone', _shopPhone.isEmpty ? 'Not set' : _shopPhone),
            _div(), _tile(Icons.edit, AppTheme.primary, 'Edit Shop Info', null, null, () => _editShop(context)),
          ]),
          SizedBox(height: 16.h),

          // Masters (NEW)
          _head('📚  Masters'),
          _card([
            _tile(Icons.category, AppTheme.primary, 'Category / Brand / Unit', 'Manage product masters',null,
                    () => Navigator.push(context, MaterialPageRoute(builder: (_) => const MastersPage()))),
            _div(),
            _tile(Icons.people, const Color(0xFF2196F3), 'Customer Master', 'Manage customers', null,
                    () => Navigator.push(context, MaterialPageRoute(builder: (_) => const MastersPage()))),
            _div(),
            _tile(Icons.local_shipping, AppTheme.secondary, 'Supplier Master', 'Manage suppliers', null,
                    () => Navigator.push(context, MaterialPageRoute(builder: (_) => const MastersPage()))),
          ]),
          SizedBox(height: 16.h),

          // Transactions (NEW)
          _head('📋  Transactions'),
          _card([
            _tile(Icons.shopping_cart, AppTheme.accent, 'Purchase Entry', 'Add purchase, update stock', null,
                    () => Navigator.push(context, MaterialPageRoute(builder: (_) => const AddPurchasePage()))),
            _div(),
            _tile(Icons.assignment_return, AppTheme.danger, 'Sale Return / Exchange', 'Return or exchange bills', null,
                    () => Navigator.push(context, MaterialPageRoute(builder: (_) => const SaleReturnPage()))),
            _div(),
            _tile(Icons.keyboard_return, AppTheme.warning, 'Purchase Return', 'Return items to supplier', null,
                    () => Navigator.push(context, MaterialPageRoute(builder: (_) => const PurchaseReturnPage()))),
            _div(),
            _tile(Icons.nightlight_round, AppTheme.primary, 'Day Close (EOD)', 'Close the day & reconcile cash', null,
                    () => Navigator.push(context, MaterialPageRoute(builder: (_) => const DayClosePage()))),
          ]),
          SizedBox(height: 16.h),

          // Sync Monitor (admin only)
          if (isAdmin) ...[
            _head('🔄  Sync'),
            _card([
              _tile(Icons.cloud_sync, const Color(0xFF2196F3), 'Sync Monitor', 'View pending/failed sync items', null,
                      () => Navigator.push(context, MaterialPageRoute(builder: (_) => const SyncStatusPage()))),
            ]),
            SizedBox(height: 16.h),
          ],

          // Language (NEW)
          _head('🌐  Language'),
          _card([
            _tile(Icons.language, const Color(0xFF9C27B0), lang.t('language'),
                'Current: ${AppLocalizations.instance.current.nativeName}', null,
                    () => Navigator.push(context, MaterialPageRoute(builder: (_) => const LanguageSettingsPage())).then((_) => setState(() {}))),
          ]),
          SizedBox(height: 16.h),

          // Printer
          _head('🖨️  ${lang.t("printer")}'),
          _card([_tile(Icons.bluetooth, AppTheme.primary, 'Bluetooth Printer Setup', 'Connect & test thermal printer', null,
                  () => Navigator.push(context, MaterialPageRoute(builder: (_) => const PrinterSettingsPage())))]),
          SizedBox(height: 16.h),

          // User Management (admin only)
          if (isAdmin) ...[
            _head('👥  User Management'),
            FutureBuilder<({int current, int max})>(
              future: _loadUserStats(),
              builder: (_, snap) {
                final current = snap.data?.current ?? 0;
                final max = snap.data?.max ?? 0;
                return _card([
                  _tile(
                    Icons.manage_accounts,
                    AppTheme.primary,
                    'Manage Users',
                    snap.hasData ? '$current / $max users' : 'Loading...',
                    null,
                    () => Navigator.push(context, MaterialPageRoute(builder: (_) => const UsersPage())).then((_) => setState(() {})),
                  ),
                ]);
              },
            ),
            SizedBox(height: 16.h),
          ],

          // Security
          _head('🔐  Security'),
          _card([
            _tile(Icons.pin, AppTheme.secondary, lang.t('change_pin'), '4-digit login PIN', null, () => _changePinSheet(context)),
            _div(),
            _tile(Icons.logout, AppTheme.danger, lang.t('logout'), 'Lock app', null, () => _logout(context)),
          ]),
          SizedBox(height: 16.h),

          // Backup
          _head('☁️  ${lang.t("backup")}'),
          _card([
            _tile(Icons.backup, AppTheme.accent, 'Backup to Google Drive', null,
                _isBackingUp ? const SizedBox(width:20,height:20,child:CircularProgressIndicator(strokeWidth:2)) : null,
                _isBackingUp ? null : () => _backup(context)),
            _div(),
            _tile(Icons.restore, AppTheme.warning, 'Restore from Google Drive', null,
                _isRestoring ? const SizedBox(width:20,height:20,child:CircularProgressIndicator(strokeWidth:2)) : null,
                _isRestoring ? null : () => _restore(context)),
          ]),
          SizedBox(height: 16.h),

          _head('ℹ️  About'),
          _card([_info('Version', '2.0.0'), _div(), _tile(Icons.delete_forever, AppTheme.danger, 'Clear All Data', null, null, () {})]),
          SizedBox(height: 60.h),
        ]),
      ),
    );
  }

  Widget _buildSubCard() {
    final isExpired = _subStatus.isLocked;
    final isSoon = _subStatus.needsReminder;
    Color c = isExpired ? AppTheme.danger : isSoon ? AppTheme.warning : AppTheme.accent;
    String label = isExpired ? '🔒 Expired' : isSoon ? '⏰ Expiring Soon' : '✅ Active';
    String sub = isExpired ? 'Renew to unlock billing' : '$_daysLeft days remaining';
    return Container(
      padding: EdgeInsets.all(16.w),
      decoration: BoxDecoration(color: c.withOpacity(0.08), borderRadius: BorderRadius.circular(16.r), border: Border.all(color: c.withOpacity(0.3))),
      child: Row(children: [
        Icon(isExpired ? Icons.lock : isSoon ? Icons.warning_amber_rounded : Icons.verified, color: c, size: 28.sp),
        SizedBox(width: 12.w),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(AppLocalizations.instance.t('subscription'), style: AppTheme.caption),
          Text(label, style: TextStyle(fontSize: 15.sp, fontWeight: FontWeight.w700, color: c, fontFamily: 'Poppins')),
          Text(sub, style: AppTheme.caption),
        ])),
        TextButton(
          onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => SubscriptionLockScreen(status: _subStatus))).then((_) => _load()),
          style: TextButton.styleFrom(backgroundColor: c.withOpacity(0.1), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8.r))),
          child: Text(isExpired ? 'Renew' : 'Manage', style: TextStyle(color: c, fontWeight: FontWeight.w600)),
        ),
      ]),
    );
  }

  Widget _head(String t) => Padding(padding: EdgeInsets.only(bottom: 8.h), child: Text(t, style: AppTheme.heading3));
  Widget _card(List<Widget> ch) => Container(decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(14.r), border: Border.all(color: AppTheme.divider)), child: Padding(padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 4.h), child: Column(children: ch)));
  Widget _div() => Divider(height: 0, color: AppTheme.divider);
  Widget _info(String l, String v) => Padding(padding: EdgeInsets.symmetric(vertical: 10.h), child: Row(children: [Text(l, style: AppTheme.caption), SizedBox(width: 8.w), Expanded(child: Text(v, style: AppTheme.body, textAlign: TextAlign.right, maxLines: 1, overflow: TextOverflow.ellipsis))]));
  Widget _tile(IconData icon, Color ic, String title, String? sub, Widget? trailing, VoidCallback? onTap) => ListTile(contentPadding: EdgeInsets.zero,
      leading: Container(width: 36.w, height: 36.h, decoration: BoxDecoration(color: ic.withOpacity(0.1), borderRadius: BorderRadius.circular(8.r)), child: Icon(icon, color: ic, size: 18.sp)),
      title: Text(title, style: AppTheme.body), subtitle: sub != null ? Text(sub, style: AppTheme.caption) : null,
      trailing: trailing ?? Icon(Icons.chevron_right, color: AppTheme.textSecondary, size: 18.sp), onTap: onTap);

  Future<({int current, int max})> _loadUserStats() async {
    final (users, max) = await (
      SupabaseAuthService.instance.fetchCloudUsers(),
      SupabaseAuthService.instance.getMaxAllowedUsers(),
    ).wait;
    return (current: users.length, max: max);
  }

  void _logout(BuildContext ctx) => showDialog(context: ctx, builder: (_) => AlertDialog(
    title: const Text('Logout?'), content: const Text('Return to PIN screen.'),
    actions: [TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
      ElevatedButton(onPressed: () { Navigator.pop(ctx); Navigator.pushAndRemoveUntil(ctx, MaterialPageRoute(builder: (_) => const LoginScreen()), (_) => false); }, style: ElevatedButton.styleFrom(backgroundColor: AppTheme.danger), child: const Text('Logout'))],
  ));

  void _changePinSheet(BuildContext ctx) => showModalBottomSheet(context: ctx, isScrollControlled: true, backgroundColor: Colors.transparent,
      builder: (_) => Container(padding: EdgeInsets.only(left: 20.w, right: 20.w, top: 24.h, bottom: MediaQuery.of(ctx).viewInsets.bottom + 20.h),
          decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.vertical(top: Radius.circular(24.r))),
          child: SetPinScreen(onPinSet: () { Navigator.pop(ctx); ScaffoldMessenger.of(ctx).showSnackBar(const SnackBar(content: Text('PIN updated! ✅'), backgroundColor: AppTheme.accent)); })));

  void _editShop(BuildContext ctx) async {
    final nc=TextEditingController(text: _shopName), ac=TextEditingController(text: _shopAddress), pc=TextEditingController(text: _shopPhone);
    final prefs = await SharedPreferences.getInstance();
    String? logoPath = prefs.getString('logo_path');
    if (!mounted) return;

    Future<void> pickLogo(StateSetter setSt) async {
      final picked = await ImagePicker().pickImage(source: ImageSource.gallery, maxWidth: 512, maxHeight: 512);
      if (picked != null) setSt(() => logoPath = picked.path);
    }

    bool logoExists(String? path) => path != null && path.isNotEmpty && File(path).existsSync();

    showModalBottomSheet(context: ctx, isScrollControlled: true, backgroundColor: Colors.transparent,
        builder: (_) => StatefulBuilder(
          builder: (sheetCtx, setSt) => Container(padding: EdgeInsets.only(left: 20.w, right: 20.w, top: 20.h, bottom: MediaQuery.of(ctx).viewInsets.bottom + 20.h),
              decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.vertical(top: Radius.circular(24.r))),
              child: SingleChildScrollView(child: Column(mainAxisSize: MainAxisSize.min, children: [
                Text('Edit Shop Info', style: AppTheme.heading2), SizedBox(height: 16.h),
                // Logo picker
                Center(
                  child: Column(children: [
                    GestureDetector(
                      onTap: () => pickLogo(setSt),
                      child: logoExists(logoPath)
                          ? CircleAvatar(backgroundImage: FileImage(File(logoPath!)), radius: 40.r)
                          : CircleAvatar(radius: 40.r, child: Icon(Icons.store, size: 32.sp)),
                    ),
                    TextButton.icon(
                      onPressed: () => pickLogo(setSt),
                      icon: const Icon(Icons.camera_alt),
                      label: const Text('Change Logo'),
                    ),
                  ]),
                ),
                SizedBox(height: 8.h),
                TextField(controller: nc, decoration: const InputDecoration(labelText: 'Shop Name')), SizedBox(height: 10.h),
                TextField(controller: ac, decoration: const InputDecoration(labelText: 'Address'), maxLines: 2), SizedBox(height: 10.h),
                TextField(controller: pc, keyboardType: TextInputType.phone, decoration: const InputDecoration(labelText: 'Phone')),
                SizedBox(height: 16.h),
                ElevatedButton(onPressed: () async {
                  final p = await SharedPreferences.getInstance();
                  await p.setString('shop_name', nc.text.trim()); await p.setString('shop_address', ac.text.trim()); await p.setString('shop_phone', pc.text.trim());
                  await p.setString('logo_path', logoPath ?? '');
                  await _load(); if (mounted) Navigator.pop(ctx);
                }, child: const Text('Save')),
              ])))));
  }

  Future<void> _backup(BuildContext ctx) async {
    setState(() => _isBackingUp = true);
    final ok = await BackupService.instance.backupToGoogleDrive();
    setState(() => _isBackingUp = false);
    if (!mounted) return;
    ScaffoldMessenger.of(ctx).showSnackBar(SnackBar(content: Text(ok ? 'Backup successful! ✅' : 'Backup failed.'), backgroundColor: ok ? AppTheme.accent : AppTheme.danger));
  }

  Future<void> _restore(BuildContext ctx) async {
    final c = await showDialog<bool>(context: ctx, builder: (_) => AlertDialog(title: const Text('Restore?'), content: const Text('Replaces ALL data. Cannot undo!'),
        actions: [TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')), ElevatedButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Restore'))]));
    if (c != true) return;
    setState(() => _isRestoring = true);
    final ok = await BackupService.instance.restoreFromGoogleDrive();
    setState(() => _isRestoring = false);
    if (!mounted) return;
    ScaffoldMessenger.of(ctx).showSnackBar(SnackBar(content: Text(ok ? 'Restore done! Restart app.' : 'Restore failed.'), backgroundColor: ok ? AppTheme.accent : AppTheme.danger));
  }
}