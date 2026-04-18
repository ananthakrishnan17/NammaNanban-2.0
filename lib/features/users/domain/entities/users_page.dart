import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../../../../core/supabase/supabase_auth_service.dart';
import '../../../../core/theme/app_theme.dart';
import '../../domain/entities/app_user.dart';

class UsersPage extends StatefulWidget {
  const UsersPage({super.key});
  @override State<UsersPage> createState() => _UsersPageState();
}

class _UsersPageState extends State<UsersPage> {
  late Future<bool> _canAddMoreFuture;
  late Future<int> _maxUsersFuture;
  AppUser? _currentUser;

  @override
  void initState() {
    super.initState();
    _currentUser = context.read<UserBloc>().currentUser;
    _canAddMoreFuture = SupabaseAuthService.instance.canAddMoreUsers();
    _maxUsersFuture = SupabaseAuthService.instance.getMaxAllowedUsers();
    context.read<UserBloc>().add(LoadCloudUsers());
  }

  void _refreshLimitFutures() {
    setState(() {
      _canAddMoreFuture = SupabaseAuthService.instance.canAddMoreUsers();
      _maxUsersFuture = SupabaseAuthService.instance.getMaxAllowedUsers();
    });
  }

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<UserBloc, UserState>(
      listenWhen: (_, curr) => curr is UserListLoaded,
      listener: (_, __) => _refreshLimitFutures(),
      builder: (context, state) {
        final isAdmin = _currentUser?.isAdmin == true;
        final users = state is UserListLoaded ? state.users : <AppUser>[];

        return Scaffold(
          appBar: AppBar(
            title: const Text('User Management'),
            actions: [
              FutureBuilder<int>(
                future: _maxUsersFuture,
                builder: (_, snap) {
                  if (!snap.hasData) return const SizedBox.shrink();
                  return Padding(
                    padding: EdgeInsets.only(right: 16.w),
                    child: Center(
                      child: Text(
                        '${users.length} / ${snap.data} users',
                        style: AppTheme.caption.copyWith(fontWeight: FontWeight.w600),
                      ),
                    ),
                  );
                },
              ),
            ],
          ),
          floatingActionButton: isAdmin
              ? FutureBuilder<bool>(
                  future: _canAddMoreFuture,
                  builder: (_, snap) {
                    final canAdd = snap.data ?? false;
                    return FloatingActionButton.extended(
                      onPressed: canAdd
                          ? () => _showUserForm(context, null)
                          : () {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text(
                                    'User limit reached for your license. Cannot add more users.',
                                    style: TextStyle(fontFamily: 'Poppins', fontSize: 13.sp),
                                  ),
                                  backgroundColor: AppTheme.danger,
                                  behavior: SnackBarBehavior.floating,
                                ),
                              );
                            },
                      backgroundColor: canAdd ? AppTheme.primary : AppTheme.textSecondary,
                      icon: Icon(canAdd ? Icons.person_add : Icons.person_off, color: Colors.white),
                      label: Text(
                        canAdd ? 'Add User' : 'Limit Reached',
                        style: const TextStyle(color: Colors.white),
                      ),
                    );
                  },
                )
              : null,
          body: _buildBody(context, state, users, isAdmin),
        );
      },
    );
  }

  Widget _buildBody(BuildContext context, UserState state, List<AppUser> users, bool isAdmin) {
    if (state is UserLoading) return const Center(child: CircularProgressIndicator());

    if (users.isEmpty) {
      return Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
        Text('👥', style: TextStyle(fontSize: 56.sp)),
        SizedBox(height: 16.h),
        Text('No users yet', style: AppTheme.heading2),
        SizedBox(height: 8.h),
        Text(isAdmin ? 'Tap + to create your first user' : 'No users available', style: AppTheme.caption),
      ]));
    }

    return ListView.separated(
      padding: EdgeInsets.all(14.w),
      itemCount: users.length,
      separatorBuilder: (_, __) => SizedBox(height: 10.h),
      itemBuilder: (ctx, i) => _userTile(ctx, users[i]),
    );
  }

  Widget _userTile(BuildContext ctx, AppUser user) {
    final currentUser = ctx.read<UserBloc>().currentUser;
    final isCurrentUser = currentUser?.username == user.username;
    final isAdmin = currentUser?.isAdmin == true;

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16.r),
        border: Border.all(
          color: isCurrentUser ? AppTheme.primary.withOpacity(0.4) : AppTheme.divider,
          width: isCurrentUser ? 1.5 : 1,
        ),
      ),
      child: Padding(
        padding: EdgeInsets.all(14.w),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          // Header row
          Row(children: [
            // Avatar
            Container(
              width: 46.w, height: 46.h,
              decoration: BoxDecoration(
                color: user.isAdmin ? AppTheme.primary.withOpacity(0.12) : AppTheme.secondary.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: Center(child: Text(user.username[0].toUpperCase(),
                  style: TextStyle(fontSize: 20.sp, fontWeight: FontWeight.w700, color: user.isAdmin ? AppTheme.primary : AppTheme.secondary, fontFamily: 'Poppins'))),
            ),
            SizedBox(width: 12.w),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Row(children: [
                  Text(user.username, style: AppTheme.heading3),
                  SizedBox(width: 6.w),
                  if (isCurrentUser) Container(
                    padding: EdgeInsets.symmetric(horizontal: 6.w, vertical: 2.h),
                    decoration: BoxDecoration(color: AppTheme.primary.withOpacity(0.12), borderRadius: BorderRadius.circular(4.r)),
                    child: Text('You', style: TextStyle(fontSize: 9.sp, color: AppTheme.primary, fontWeight: FontWeight.w600, fontFamily: 'Poppins')),
                  ),
                ]),
                Row(children: [
                  Text('${user.role.emoji} ${user.role.label}', style: AppTheme.caption),
                  SizedBox(width: 8.w),
                  Container(
                    padding: EdgeInsets.symmetric(horizontal: 6.w, vertical: 2.h),
                    decoration: BoxDecoration(
                      color: user.isActive ? AppTheme.accent.withOpacity(0.1) : AppTheme.danger.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(4.r),
                    ),
                    child: Text(user.isActive ? 'Active' : 'Inactive',
                        style: TextStyle(fontSize: 10.sp, color: user.isActive ? AppTheme.accent : AppTheme.danger, fontWeight: FontWeight.w600, fontFamily: 'Poppins')),
                  ),
                ]),
              ]),
            ),
            // Actions menu (admin only)
            if (isAdmin)
              PopupMenuButton<String>(
                onSelected: (v) async {
                  if (v == 'edit') _showUserForm(ctx, user);
                  if (v == 'toggle') {
                    final updated = user.copyWith(isActive: !user.isActive);
                    await SupabaseAuthService.instance.updateCloudUser(updated);
                    if (ctx.mounted) ctx.read<UserBloc>().add(LoadCloudUsers());
                  }
                  if (v == 'delete' && !isCurrentUser) _confirmDelete(ctx, user);
                  if (v == 'change_pin') _showChangePinDialog(ctx, user);
                },
                itemBuilder: (_) => [
                  const PopupMenuItem(value: 'edit', child: Row(children: [Icon(Icons.edit, size: 16), SizedBox(width: 8), Text('Edit Permissions')])),
                  const PopupMenuItem(value: 'change_pin', child: Row(children: [Icon(Icons.pin, size: 16), SizedBox(width: 8), Text('Change PIN')])),
                  PopupMenuItem(value: 'toggle', child: Row(children: [
                    Icon(user.isActive ? Icons.block : Icons.check_circle, size: 16),
                    SizedBox(width: 8), Text(user.isActive ? 'Deactivate' : 'Activate'),
                  ])),
                  if (!isCurrentUser) const PopupMenuItem(value: 'delete',
                      child: Row(children: [Icon(Icons.delete, size: 16, color: AppTheme.danger), SizedBox(width: 8), Text('Delete', style: TextStyle(color: AppTheme.danger))])),
                ],
              ),
          ]),

          // Permissions chips (only for non-admin)
          if (!user.isAdmin) ...[
            SizedBox(height: 10.h),
            Divider(height: 1, color: AppTheme.divider),
            SizedBox(height: 8.h),
            Text('Permissions', style: AppTheme.caption.copyWith(fontWeight: FontWeight.w600)),
            SizedBox(height: 6.h),
            Wrap(spacing: 6.w, runSpacing: 6.h, children: _permChips(user.permissions)),
          ] else ...[
            SizedBox(height: 6.h),
            Text('Full access to all features', style: AppTheme.caption.copyWith(color: AppTheme.primary)),
          ],
        ]),
      ),
    );
  }

  List<Widget> _permChips(UserPermissions p) {
    final perms = [
      (p.canBill, '🧾 Billing'),
      (p.canViewDashboard, '📊 Dashboard'),
      (p.canViewReports, '📈 Reports'),
      (p.canManageProducts, '📦 Products'),
      (p.canManageMasters, '📚 Masters'),
      (p.canViewExpenses, '💸 Expenses'),
      (p.canManagePurchase, '🛒 Purchase'),
    ];
    return perms.map((perm) => Container(
      padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 3.h),
      decoration: BoxDecoration(
        color: perm.$1 ? AppTheme.accent.withOpacity(0.1) : AppTheme.surface,
        borderRadius: BorderRadius.circular(6.r),
        border: Border.all(color: perm.$1 ? AppTheme.accent.withOpacity(0.4) : AppTheme.divider),
      ),
      child: Text(perm.$2, style: TextStyle(
        fontSize: 10.sp, fontFamily: 'Poppins',
        color: perm.$1 ? AppTheme.accent : AppTheme.textSecondary,
        fontWeight: perm.$1 ? FontWeight.w600 : FontWeight.w400,
      )),
    )).toList();
  }

  // ── Create / Edit User Form ────────────────────────────────────────────────
  void _showUserForm(BuildContext ctx, AppUser? existing) {
    final usernameCtrl = TextEditingController(text: existing?.username ?? '');
    final pinCtrl = TextEditingController();
    final confirmPinCtrl = TextEditingController();
    UserRole role = existing?.role ?? UserRole.user;
    UserPermissions perms = existing?.permissions ?? UserPermissions.defaultUser();
    String? pinError;
    String? saveError;
    bool isSaving = false;
    final isEditing = existing != null;

    showModalBottomSheet(
      context: ctx, isScrollControlled: true, backgroundColor: Colors.transparent,
      builder: (_) => StatefulBuilder(builder: (sCtx, setSt) => Container(
        height: MediaQuery.of(ctx).size.height * 0.88,
        padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.vertical(top: Radius.circular(24.r))),
        child: Column(children: [
          SizedBox(height: 12.h),
          Container(width: 40.w, height: 4.h, decoration: BoxDecoration(color: AppTheme.divider, borderRadius: BorderRadius.circular(2.r))),
          SizedBox(height: 12.h),
          Padding(padding: EdgeInsets.symmetric(horizontal: 20.w), child: Text(isEditing ? 'Edit User' : 'Create User', style: AppTheme.heading2)),
          SizedBox(height: 4.h),
          Expanded(
            child: SingleChildScrollView(
              padding: EdgeInsets.symmetric(horizontal: 20.w),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                SizedBox(height: 12.h),

                // Username
                TextField(controller: usernameCtrl, enabled: !isEditing,
                    decoration: const InputDecoration(labelText: 'Username *', prefixIcon: Icon(Icons.person))),
                SizedBox(height: 10.h),

                // PIN (only for new users)
                if (!isEditing) ...[
                  TextField(controller: pinCtrl, keyboardType: TextInputType.number, maxLength: 4,
                      obscureText: true,
                      decoration: const InputDecoration(labelText: 'PIN (4 digits) *', prefixIcon: Icon(Icons.lock))),
                  TextField(controller: confirmPinCtrl, keyboardType: TextInputType.number, maxLength: 4,
                      obscureText: true,
                      decoration: InputDecoration(
                        labelText: 'Confirm PIN *', prefixIcon: const Icon(Icons.lock_outline),
                        errorText: pinError,
                      )),
                  SizedBox(height: 6.h),
                ],

                // Role selector
                _sec('Role'),
                Row(children: UserRole.values.map((r) {
                  final sel = role == r;
                  return Expanded(child: GestureDetector(
                    onTap: () => setSt(() { role = r; if (r == UserRole.admin) perms = UserPermissions.admin(); else perms = UserPermissions.defaultUser(); }),
                    child: AnimatedContainer(duration: const Duration(milliseconds: 200),
                      margin: EdgeInsets.only(right: r == UserRole.admin ? 8.w : 0),
                      padding: EdgeInsets.symmetric(vertical: 12.h),
                      decoration: BoxDecoration(
                          color: sel ? (r == UserRole.admin ? AppTheme.primary : AppTheme.secondary) : AppTheme.surface,
                          borderRadius: BorderRadius.circular(12.r),
                          border: Border.all(color: sel ? (r == UserRole.admin ? AppTheme.primary : AppTheme.secondary) : AppTheme.divider)),
                      child: Column(children: [
                        Text(r.emoji, style: TextStyle(fontSize: 20.sp)),
                        SizedBox(height: 4.h),
                        Text(r.label, style: TextStyle(fontSize: 13.sp, fontWeight: FontWeight.w600, color: sel ? Colors.white : AppTheme.textPrimary, fontFamily: 'Poppins')),
                      ]),
                    ),
                  ));
                }).toList()),
                SizedBox(height: 16.h),

                // Permissions (only for user role)
                if (role == UserRole.user) ...[
                  _sec('Permissions'),
                  Text('Choose what this user can access:', style: AppTheme.caption),
                  SizedBox(height: 10.h),
                  ..._permToggles(perms, (updated) => setSt(() => perms = updated)),
                ] else ...[
                  Container(padding: EdgeInsets.all(12.w),
                      decoration: BoxDecoration(color: AppTheme.primary.withOpacity(0.08), borderRadius: BorderRadius.circular(10.r)),
                      child: Row(children: [
                        const Icon(Icons.info_outline, color: AppTheme.primary, size: 18),
                        SizedBox(width: 8.w),
                        Expanded(child: Text('Admin has full access to all features automatically.', style: AppTheme.caption.copyWith(color: AppTheme.primary))),
                      ])),
                ],

                if (saveError != null) ...[
                  SizedBox(height: 10.h),
                  Container(
                    padding: EdgeInsets.all(10.w),
                    decoration: BoxDecoration(color: AppTheme.danger.withOpacity(0.1), borderRadius: BorderRadius.circular(8.r), border: Border.all(color: AppTheme.danger.withOpacity(0.4))),
                    child: Text(saveError!, style: TextStyle(color: AppTheme.danger, fontSize: 12.sp, fontFamily: 'Poppins')),
                  ),
                ],

                SizedBox(height: 24.h),

                // Save button
                ElevatedButton(
                  onPressed: isSaving ? null : () async {
                    if (usernameCtrl.text.trim().isEmpty) return;
                    if (!isEditing) {
                      if (pinCtrl.text.length != 4) { setSt(() => pinError = 'PIN must be 4 digits'); return; }
                      if (pinCtrl.text != confirmPinCtrl.text) { setSt(() => pinError = 'PINs do not match'); return; }
                    }

                    final now = DateTime.now();

                    if (!isEditing) {
                      setSt(() { isSaving = true; saveError = null; });
                      final newUser = AppUser(
                        id: null,
                        username: usernameCtrl.text.trim(),
                        pin: pinCtrl.text,
                        role: role,
                        permissions: perms,
                        isActive: true,
                        createdAt: now,
                        updatedAt: now,
                      );
                      final result = await SupabaseAuthService.instance.createCloudUser(newUser);
                      if (!result.success) {
                        setSt(() { saveError = result.error; isSaving = false; });
                        return;
                      }
                      if (ctx.mounted) {
                        ctx.read<UserBloc>().add(LoadCloudUsers());
                        Navigator.pop(ctx);
                      }
                    } else {
                      final user = AppUser(
                        id: existing.id,
                        username: usernameCtrl.text.trim(),
                        pin: existing.pin,
                        role: role,
                        permissions: perms,
                        isActive: existing.isActive,
                        createdAt: existing.createdAt,
                        updatedAt: now,
                      );
                      setSt(() { isSaving = true; saveError = null; });
                      final cloudUpdated = await SupabaseAuthService.instance.updateCloudUser(user);
                      if (!cloudUpdated) {
                        setSt(() { saveError = 'Failed to update user in cloud. Please try again.'; isSaving = false; });
                        return;
                      }
                      if (ctx.mounted) {
                        ctx.read<UserBloc>().add(LoadCloudUsers());
                        Navigator.pop(ctx);
                      }
                    }
                  },
                  child: isSaving
                      ? SizedBox(width: 20.w, height: 20.h, child: const CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                      : Text(isEditing ? 'Update User' : 'Create User'),
                ),
                SizedBox(height: 20.h),
              ]),
            ),
          ),
        ]),
      )),
    );
  }

  List<Widget> _permToggles(UserPermissions p, void Function(UserPermissions) onChange) {
    final toggles = [
      ('🧾 Billing', 'Can create bills', p.canBill, (v) => p.copyWith(canBill: v)),
      ('📊 Dashboard', 'Can view dashboard', p.canViewDashboard, (v) => p.copyWith(canViewDashboard: v)),
      ('📈 Reports', 'Can view sales reports', p.canViewReports, (v) => p.copyWith(canViewReports: v)),
      ('📦 Products', 'Can add/edit products', p.canManageProducts, (v) => p.copyWith(canManageProducts: v)),
      ('📚 Masters', 'Can manage category/brand/customer', p.canManageMasters, (v) => p.copyWith(canManageMasters: v)),
      ('💸 Expenses', 'Can view & add expenses', p.canViewExpenses, (v) => p.copyWith(canViewExpenses: v)),
      ('🛒 Purchase', 'Can create purchase entries', p.canManagePurchase, (v) => p.copyWith(canManagePurchase: v)),
    ];

    return toggles.map((t) => Container(
      margin: EdgeInsets.only(bottom: 8.h),
      padding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 6.h),
      decoration: BoxDecoration(
        color: t.$3 ? AppTheme.accent.withOpacity(0.05) : Colors.white,
        borderRadius: BorderRadius.circular(10.r),
        border: Border.all(color: t.$3 ? AppTheme.accent.withOpacity(0.3) : AppTheme.divider),
      ),
      child: Row(children: [
        Text(t.$1.split(' ')[0], style: TextStyle(fontSize: 18.sp)),
        SizedBox(width: 10.w),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(t.$1.substring(3), style: AppTheme.body.copyWith(fontWeight: FontWeight.w500)),
          Text(t.$2, style: AppTheme.caption),
        ])),
        Switch(value: t.$3, onChanged: (v) => onChange(t.$4(v) as UserPermissions), activeColor: AppTheme.accent),
      ]),
    )).toList();
  }

  Widget _sec(String l) => Padding(padding: EdgeInsets.only(bottom: 8.h), child: Text(l, style: AppTheme.heading3.copyWith(color: AppTheme.primary)));

  void _confirmDelete(BuildContext ctx, AppUser user) => showDialog(
    context: ctx, builder: (_) => AlertDialog(
    title: const Text('Delete User?'),
    content: Text('Delete "${user.username}"? This cannot be undone.'),
    actions: [
      TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
      TextButton(
        onPressed: () async {
          Navigator.pop(ctx);
          final deleted = await SupabaseAuthService.instance.deleteCloudUser(user.username);
          if (deleted && ctx.mounted) {
            ctx.read<UserBloc>().add(LoadCloudUsers());
          } else if (!deleted && ctx.mounted) {
            ScaffoldMessenger.of(ctx).showSnackBar(
              const SnackBar(content: Text('Failed to delete user. Please try again.'), backgroundColor: AppTheme.danger),
            );
          }
        },
        child: const Text('Delete', style: TextStyle(color: AppTheme.danger)),
      ),
    ],
  ),
  );

  void _showChangePinDialog(BuildContext ctx, AppUser user) {
    final ctrl = TextEditingController();
    final confirmCtrl = TextEditingController();
    showDialog(
      context: ctx, builder: (_) => AlertDialog(
      title: Text('Change PIN — ${user.username}'),
      content: Column(mainAxisSize: MainAxisSize.min, children: [
        TextField(controller: ctrl, keyboardType: TextInputType.number, maxLength: 4, obscureText: true, decoration: const InputDecoration(labelText: 'New PIN (4 digits)')),
        TextField(controller: confirmCtrl, keyboardType: TextInputType.number, maxLength: 4, obscureText: true, decoration: const InputDecoration(labelText: 'Confirm PIN')),
      ]),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
        ElevatedButton(
          onPressed: () async {
            if (ctrl.text.length == 4 && ctrl.text == confirmCtrl.text) {
              // Update in Supabase first
              final changed = await SupabaseAuthService.instance.changeUserPin(user.username, ctrl.text);
              if (!ctx.mounted) return;
              if (changed) {
                // Update locally only if cloud succeeded (repo hashes it)
                ctx.read<UserBloc>().add(UpdateUser(user.copyWith(pin: ctrl.text)));
                Navigator.pop(ctx);
                ScaffoldMessenger.of(ctx).showSnackBar(const SnackBar(content: Text('PIN changed!'), backgroundColor: AppTheme.accent));
              } else {
                ScaffoldMessenger.of(ctx).showSnackBar(const SnackBar(content: Text('Failed to change PIN. Please try again.'), backgroundColor: AppTheme.danger));
              }
            }
          },
          child: const Text('Change'),
        ),
      ],
    ),
    );
  }
}