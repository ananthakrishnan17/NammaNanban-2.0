import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../supabase/supabase_config.dart';
import '../../features/users/domain/entities/app_user.dart';

/// Plans available
enum SupabasePlan { basic, standard }

extension SupabasePlanExt on SupabasePlan {
  String get value => name;
  String get label => name == 'basic' ? 'Basic' : 'Standard';
  int get maxUsers => name == 'basic' ? 2 : 6; // basic=1admin+1user, standard=1admin+5users
  int get maxAdmins => 1;
  int get maxRegularUsers => name == 'basic' ? 1 : 5;
  String get price => name == 'basic' ? '₹200/month' : '₹500/month';
}

/// Result of license verification
class LicenseVerifyResult {
  final bool success;
  final String? licenseId;
  final String? companyName;
  final SupabasePlan? plan;
  final DateTime? expiresAt;
  final String? errorMessage;
  final int? daysLeft;

  const LicenseVerifyResult({
    required this.success,
    this.licenseId,
    this.companyName,
    this.plan,
    this.expiresAt,
    this.errorMessage,
    this.daysLeft,
  });

  bool get isExpired => expiresAt != null && DateTime.now().isAfter(expiresAt!);
}

class SupabaseAuthService {
  static final SupabaseAuthService instance = SupabaseAuthService._();
  SupabaseAuthService._();

  // SharedPrefs keys
  static const _kLicenseId = 'sb_license_id';
  static const _kLicenseKey = 'sb_license_key';
  static const _kPlan = 'sb_plan';
  static const _kExpiresAt = 'sb_expires_at';
  static const _kCompanyName = 'sb_company_name';
  static const _kLastSync = 'sb_last_sync';

  // ── License Verification ──────────────────────────────────────────────────
  /// Verify license key against Supabase `licenses` table
  Future<LicenseVerifyResult> verifyLicense(String licenseKey) async {
    try {
      final db = SupabaseClientHelper.table('licenses');
      final response = await db
          .select()
          .eq('license_key', licenseKey.toUpperCase().trim())
          .eq('is_active', true)
          .maybeSingle();

      if (response == null) {
        return const LicenseVerifyResult(
            success: false, errorMessage: 'Invalid license key. Please check and try again.');
      }

      final expiresAt = DateTime.parse(response['expires_at'] as String);
      final now = DateTime.now();

      if (now.isAfter(expiresAt)) {
        return LicenseVerifyResult(
          success: false,
          errorMessage: 'License expired on ${_formatDate(expiresAt)}. Please renew.',
        );
      }

      final plan = response['plan'] == 'standard' ? SupabasePlan.standard : SupabasePlan.basic;
      final daysLeft = expiresAt.difference(now).inDays;
      final licenseId = response['id'] as String;

      // Save to local storage
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_kLicenseId, licenseId);
      await prefs.setString(_kLicenseKey, licenseKey.toUpperCase().trim());
      await prefs.setString(_kPlan, plan.value);
      await prefs.setString(_kExpiresAt, expiresAt.toIso8601String());
      await prefs.setString(_kCompanyName, response['company_name'] as String? ?? '');

      return LicenseVerifyResult(
        success: true,
        licenseId: licenseId,
        companyName: response['company_name'] as String?,
        plan: plan,
        expiresAt: expiresAt,
        daysLeft: daysLeft,
      );
    } catch (e) {
      return LicenseVerifyResult(
        success: false,
        errorMessage: 'Connection error. Check internet and try again.\n$e',
      );
    }
  }

  /// Get cached license info (offline)
  Future<LicenseVerifyResult?> getCachedLicense() async {
    final prefs = await SharedPreferences.getInstance();
    final licenseId = prefs.getString(_kLicenseId);
    if (licenseId == null) return null;

    final expiresStr = prefs.getString(_kExpiresAt);
    final expiresAt = expiresStr != null ? DateTime.tryParse(expiresStr) : null;
    final plan = prefs.getString(_kPlan) == 'standard' ? SupabasePlan.standard : SupabasePlan.basic;
    final daysLeft = expiresAt != null ? expiresAt.difference(DateTime.now()).inDays : 0;

    return LicenseVerifyResult(
      success: true,
      licenseId: licenseId,
      companyName: prefs.getString(_kCompanyName),
      plan: plan,
      expiresAt: expiresAt,
      daysLeft: daysLeft,
    );
  }

  Future<String?> get licenseId async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_kLicenseId);
  }

  Future<SupabasePlan> get currentPlan async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_kPlan) == 'standard' ? SupabasePlan.standard : SupabasePlan.basic;
  }

  // ── Cloud User Management ─────────────────────────────────────────────────
  /// Fetch all users for this license from Supabase
  Future<List<AppUser>> fetchCloudUsers() async {
    try {
      final lid = await licenseId;
      if (lid == null) return [];

      final rows = await SupabaseClientHelper.table('shop_users')
          .select()
          .eq('license_id', lid)
          .order('role', ascending: false);

      return (rows as List).map((r) => _mapCloudUser(r)).toList();
    } catch (e) {
      return [];
    }
  }

  /// Create a new user in Supabase (admin only)
  Future<({bool success, String? error})> createCloudUser(AppUser user) async {
    try {
      final lid = await licenseId;
      if (lid == null) return (success: false, error: 'No license found');

      // Check user limit for plan
      final plan = await currentPlan;
      final existingUsers = await fetchCloudUsers();
      if (existingUsers.length >= plan.maxUsers) {
        return (
        success: false,
        error: 'User limit reached for ${plan.label} plan (${plan.maxUsers} users max).\n'
            'Upgrade to ${plan == SupabasePlan.basic ? "Standard" : "Enterprise"} plan to add more users.',
        );
      }

      // Check admin limit
      final adminCount = existingUsers.where((u) => u.isAdmin).length;
      if (user.isAdmin && adminCount >= 1) {
        return (success: false, error: 'Only 1 Admin allowed per license.');
      }

      await SupabaseClientHelper.table('shop_users').insert({
        'license_id': lid,
        'username': user.username,
        'pin_hash': _hashPin(user.pin),
        'role': user.role.value,
        'can_bill': user.permissions.canBill,
        'can_view_reports': user.permissions.canViewReports,
        'can_manage_products': user.permissions.canManageProducts,
        'can_manage_masters': user.permissions.canManageMasters,
        'can_view_expenses': user.permissions.canViewExpenses,
        'can_manage_purchase': user.permissions.canManagePurchase,
        'can_view_dashboard': user.permissions.canViewDashboard,
        'is_active': user.isActive,
      });

      return (success: true, error: null);
    } catch (e) {
      final msg = e.toString();
      if (msg.contains('User limit reached')) {
        return (success: false, error: 'User limit reached for this plan. Upgrade to add more users.');
      }
      if (msg.contains('unique') || msg.contains('duplicate')) {
        return (success: false, error: 'Username "${user.username}" already exists.');
      }
      return (success: false, error: 'Error: $msg');
    }
  }

  /// Update user permissions in Supabase
  Future<bool> updateCloudUser(AppUser user) async {
    try {
      final lid = await licenseId;
      if (lid == null) return false;
      await SupabaseClientHelper.table('shop_users')
          .update({
        'can_bill': user.permissions.canBill,
        'can_view_reports': user.permissions.canViewReports,
        'can_manage_products': user.permissions.canManageProducts,
        'can_manage_masters': user.permissions.canManageMasters,
        'can_view_expenses': user.permissions.canViewExpenses,
        'can_manage_purchase': user.permissions.canManagePurchase,
        'can_view_dashboard': user.permissions.canViewDashboard,
        'is_active': user.isActive,
        'updated_at': DateTime.now().toIso8601String(),
      })
          .eq('license_id', lid)
          .eq('username', user.username);
      return true;
    } catch (e) {
      return false;
    }
  }

  /// Change user PIN (updates hash in Supabase)
  Future<bool> changeUserPin(String username, String newPin) async {
    try {
      final lid = await licenseId;
      if (lid == null) return false;
      await SupabaseClientHelper.table('shop_users')
          .update({
        'pin_hash': _hashPin(newPin),
        'updated_at': DateTime.now().toIso8601String(),
      })
          .eq('license_id', lid)
          .eq('username', username);
      return true;
    } catch (e) {
      return false;
    }
  }

  /// Delete user from Supabase
  Future<bool> deleteCloudUser(String username) async {
    try {
      final lid = await licenseId;
      if (lid == null) return false;
      await SupabaseClientHelper.table('shop_users')
          .delete()
          .eq('license_id', lid)
          .eq('username', username);
      return true;
    } catch (e) {
      return false;
    }
  }

  /// Verify a user's PIN against cloud (login)
  Future<AppUser?> verifyUserPin(String username, String pin) async {
    try {
      final lid = await licenseId;
      if (lid == null) return null;
      final rows = await SupabaseClientHelper.table('shop_users')
          .select()
          .eq('license_id', lid)
          .eq('username', username)
          .eq('pin_hash', _hashPin(pin))
          .eq('is_active', true)
          .maybeSingle();
      if (rows == null) return null;
      return _mapCloudUser(rows);
    } catch (e) {
      return null;
    }
  }

  // ── Plan Check ────────────────────────────────────────────────────────────
  Future<int> getMaxAllowedUsers() async {
    final plan = await currentPlan;
    return plan.maxUsers;
  }

  Future<bool> canAddMoreUsers() async {
    final lid = await licenseId;
    if (lid == null) return false;
    final plan = await currentPlan;
    final users = await fetchCloudUsers();
    return users.length < plan.maxUsers;
  }

  // ── Helpers ───────────────────────────────────────────────────────────────
  String _hashPin(String pin) {
    final bytes = utf8.encode(pin);
    return sha256.convert(bytes).toString();
  }

  AppUser _mapCloudUser(Map<String, dynamic> r) {
    final role = r['role'] == 'admin' ? UserRole.admin : UserRole.user;
    return AppUser(
      id: null, // cloud users don't have local id
      username: r['username'] as String,
      pin: '', // never return pin from cloud
      role: role,
      permissions: role == UserRole.admin
          ? UserPermissions.admin()
          : UserPermissions(
        canBill: r['can_bill'] as bool? ?? true,
        canViewReports: r['can_view_reports'] as bool? ?? false,
        canManageProducts: r['can_manage_products'] as bool? ?? false,
        canManageMasters: r['can_manage_masters'] as bool? ?? false,
        canViewExpenses: r['can_view_expenses'] as bool? ?? false,
        canManagePurchase: r['can_manage_purchase'] as bool? ?? false,
        canViewDashboard: r['can_view_dashboard'] as bool? ?? true,
      ),
      isActive: r['is_active'] as bool? ?? true,
      createdAt: DateTime.tryParse(r['created_at'] as String? ?? '') ?? DateTime.now(),
      updatedAt: DateTime.tryParse(r['updated_at'] as String? ?? '') ?? DateTime.now(),
    );
  }

  String _formatDate(DateTime dt) => '${dt.day}/${dt.month}/${dt.year}';
}