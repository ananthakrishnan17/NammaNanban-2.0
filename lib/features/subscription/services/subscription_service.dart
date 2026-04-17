import 'package:shared_preferences/shared_preferences.dart';
import '../../../core/supabase/supabase_auth_service.dart';

class SubscriptionService {
  static final SubscriptionService instance = SubscriptionService._();
  SubscriptionService._();

  Future<SubscriptionStatus> getStatus() async {
    final cached = await SupabaseAuthService.instance.getCachedLicense();
    if (cached == null || !cached.success) return SubscriptionStatus.notActivated;
    final daysLeft = cached.daysLeft ?? 0;
    if (daysLeft < 0) return SubscriptionStatus.expired;
    if (daysLeft <= 2) return SubscriptionStatus.expiringSoon;
    return SubscriptionStatus.active;
  }

  Future<int> getDaysLeft() async {
    final cached = await SupabaseAuthService.instance.getCachedLicense();
    return cached?.daysLeft ?? 0;
  }

  Future<String?> getPlanName() async {
    final plan = await SupabaseAuthService.instance.currentPlan;
    return plan.label;
  }

  Future<bool> reVerifyOnline() async {
    final prefs = await SharedPreferences.getInstance();
    final savedKey = prefs.getString('sb_license_key');
    if (savedKey == null) return false;
    final result = await SupabaseAuthService.instance.verifyLicense(savedKey);
    return result.success;
  }

  Future<ActivateResult> activateWithKey(String licenseKey) async {
    final result = await SupabaseAuthService.instance.verifyLicense(licenseKey);
    if (result.success) {
      return ActivateResult(
        success: true,
        message: 'License activated! ${result.plan?.label ?? ''} plan — ${result.daysLeft} days remaining.',
        plan: result.plan?.label, daysLeft: result.daysLeft,
      );
    }
    return ActivateResult(success: false, message: result.errorMessage ?? 'Activation failed.');
  }

  Future<void> clearSubscription() async {
    final prefs = await SharedPreferences.getInstance();
    for (final k in ['sb_license_id','sb_license_key','sb_plan','sb_expires_at','sb_company_name']) {
      await prefs.remove(k);
    }
  }
}

class ActivateResult {
  final bool success; final String message; final String? plan; final int? daysLeft;
  const ActivateResult({required this.success, required this.message, this.plan, this.daysLeft});
}

enum SubscriptionStatus { notActivated, active, expiringSoon, expired }

extension SubscriptionStatusExt on SubscriptionStatus {
  bool get isLocked => this == SubscriptionStatus.expired || this == SubscriptionStatus.notActivated;
  bool get needsReminder => this == SubscriptionStatus.expiringSoon;
}