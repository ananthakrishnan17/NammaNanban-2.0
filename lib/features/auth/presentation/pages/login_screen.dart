import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../../../../core/supabase/supabase_auth_service.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../subscription/services/subscription_service.dart';
import '../../../subscription/presentation/pages/subscription_lock_screen.dart';
import '../../../shell/presentation/pages/main_shell.dart';
import '../../../users/domain/entities/app_user.dart';
import 'first_admin_setup_screen.dart';

enum LoginStep { licenseEntry, userSelect, pinEntry }

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});
  @override State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> with TickerProviderStateMixin {
  LoginStep _step = LoginStep.licenseEntry;
  bool _isLoading = true;

  // Step 0 — License entry
  final _licenseCtrl = TextEditingController();
  String? _licenseError;
  LicenseVerifyResult? _cachedLicense;

  // Step 1 — User select
  List<AppUser> _users = [];

  // Step 2 — PIN entry
  AppUser? _selectedUser;
  String _enteredPin = '';
  bool _isPinWrong = false;
  late AnimationController _shakeCtrl;
  late Animation<double> _shakeAnim;

  @override
  void initState() {
    super.initState();
    _shakeCtrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 400));
    _shakeAnim = Tween<double>(begin: 0, end: 12).chain(CurveTween(curve: Curves.elasticIn)).animate(_shakeCtrl);
    _init();
  }

  @override
  void dispose() {
    _shakeCtrl.dispose();
    _licenseCtrl.dispose();
    super.dispose();
  }

  Future<void> _init() async {
    final cached = await SupabaseAuthService.instance.getCachedLicense();
    if (cached != null && cached.success && !cached.isExpired) {
      _cachedLicense = cached;
      await _loadUsersForLicense();
    } else {
      setState(() { _step = LoginStep.licenseEntry; _isLoading = false; });
    }
  }

  Future<void> _verifyLicense(String key) async {
    if (key.trim().isEmpty) {
      setState(() => _licenseError = 'Please enter a license key');
      return;
    }
    setState(() { _isLoading = true; _licenseError = null; });
    final result = await SupabaseAuthService.instance.verifyLicense(key);
    if (result.success) {
      _cachedLicense = result;
      await _loadUsersForLicense();
    } else {
      setState(() { _licenseError = result.errorMessage; _isLoading = false; });
    }
  }

  Future<void> _loadUsersForLicense() async {
    setState(() => _isLoading = true);
    final users = await SupabaseAuthService.instance.fetchCloudUsers();
    if (!mounted) return;
    if (users.isEmpty) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const FirstAdminSetupScreen()),
      );
      return;
    }
    setState(() {
      _users = users.where((u) => u.isActive).toList();
      _step = LoginStep.userSelect;
      _isLoading = false;
    });
  }

  void _onKey(String d) {
    if (_enteredPin.length >= 4) return;
    setState(() { _enteredPin += d; _isPinWrong = false; });
    if (_enteredPin.length == 4) _verifyPin();
  }

  void _onDelete() {
    if (_enteredPin.isNotEmpty) {
      setState(() => _enteredPin = _enteredPin.substring(0, _enteredPin.length - 1));
    }
  }

  Future<void> _verifyPin() async {
    final user = _selectedUser!;
    final verified = await SupabaseAuthService.instance.verifyUserPin(user.username, _enteredPin);
    if (!mounted) return;
    if (verified != null) {
      context.read<UserBloc>().currentUser = verified;
      final status = await SubscriptionService.instance.getStatus();
      if (!mounted) return;
      if (status.isLocked) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => SubscriptionLockScreen(status: status)),
        );
      } else {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => const MainShell()),
        );
      }
    } else {
      setState(() { _isPinWrong = true; _enteredPin = ''; });
      _shakeCtrl.forward(from: 0);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        backgroundColor: Color(0xFF2D3250),
        body: Center(child: CircularProgressIndicator(color: Colors.white)),
      );
    }
    return Scaffold(
      backgroundColor: const Color(0xFF2D3250),
      body: SafeArea(child: _buildStep()),
    );
  }

  Widget _buildStep() {
    switch (_step) {
      case LoginStep.licenseEntry: return _buildLicenseEntry();
      case LoginStep.userSelect: return _buildUserSelect();
      case LoginStep.pinEntry: return _buildPinEntry();
    }
  }

  // ── Step 0: License Key Entry ─────────────────────────────────────────────

  Widget _buildLicenseEntry() => SingleChildScrollView(
    padding: EdgeInsets.symmetric(horizontal: 24.w),
    child: Column(crossAxisAlignment: CrossAxisAlignment.center, children: [
      SizedBox(height: 64.h),
      Container(
        width: 72.w, height: 72.h,
        decoration: BoxDecoration(color: AppTheme.primary, borderRadius: BorderRadius.circular(20.r)),
        child: Icon(Icons.point_of_sale, color: Colors.white, size: 40.sp),
      ),
      SizedBox(height: 16.h),
      Text('Welcome to Shop POS',
          style: TextStyle(fontSize: 22.sp, fontWeight: FontWeight.w700, color: Colors.white, fontFamily: 'Poppins'),
          textAlign: TextAlign.center),
      SizedBox(height: 8.h),
      Text('Enter your license key to continue',
          style: TextStyle(fontSize: 14.sp, color: Colors.white60, fontFamily: 'Poppins'),
          textAlign: TextAlign.center),
      SizedBox(height: 40.h),
      Container(
        padding: EdgeInsets.all(24.w),
        decoration: BoxDecoration(color: Colors.white.withOpacity(0.06), borderRadius: BorderRadius.circular(20.r), border: Border.all(color: Colors.white.withOpacity(0.12))),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('License Key', style: TextStyle(fontSize: 13.sp, fontWeight: FontWeight.w600, color: Colors.white70, fontFamily: 'Poppins')),
          SizedBox(height: 8.h),
          TextField(
            controller: _licenseCtrl,
            textCapitalization: TextCapitalization.characters,
            style: TextStyle(color: Colors.white, fontFamily: 'Poppins', fontSize: 14.sp, letterSpacing: 1.2),
            decoration: InputDecoration(
              hintText: 'SHOP-XXXX-XXXX-XXXX',
              hintStyle: TextStyle(color: Colors.white30, fontFamily: 'Poppins', fontSize: 14.sp),
              prefixIcon: Icon(Icons.vpn_key_outlined, color: Colors.white54, size: 20.sp),
              filled: true,
              fillColor: Colors.white.withOpacity(0.08),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12.r),
                borderSide: BorderSide(color: Colors.white.withOpacity(0.2)),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12.r),
                borderSide: BorderSide(color: Colors.white.withOpacity(0.2)),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12.r),
                borderSide: BorderSide(color: AppTheme.primary, width: 1.5),
              ),
              errorText: _licenseError,
              errorStyle: TextStyle(color: AppTheme.danger, fontSize: 11.sp, fontFamily: 'Poppins'),
            ),
            onChanged: (_) => setState(() => _licenseError = null),
          ),
          SizedBox(height: 16.h),
          ElevatedButton(
            onPressed: () => _verifyLicense(_licenseCtrl.text.trim()),
            style: ElevatedButton.styleFrom(minimumSize: Size(double.infinity, 50.h)),
            child: const Text('Verify License'),
          ),
        ]),
      ),
      SizedBox(height: 24.h),
      Text('Contact us for your license key', style: TextStyle(fontSize: 12.sp, color: Colors.white38, fontFamily: 'Poppins')),
    ]),
  );

  // ── Step 1: User Select ───────────────────────────────────────────────────

  Widget _buildUserSelect() {
    final company = _cachedLicense?.companyName ?? 'Shop POS';
    return SingleChildScrollView(
      padding: EdgeInsets.symmetric(horizontal: 24.w),
      child: Column(children: [
        SizedBox(height: 48.h),
        Container(
          width: 72.w, height: 72.h,
          decoration: BoxDecoration(color: AppTheme.primary, borderRadius: BorderRadius.circular(20.r)),
          child: Icon(Icons.point_of_sale, color: Colors.white, size: 40.sp),
        ),
        SizedBox(height: 12.h),
        Text(company, style: TextStyle(fontSize: 22.sp, fontWeight: FontWeight.w700, color: Colors.white, fontFamily: 'Poppins')),
        SizedBox(height: 4.h),
        Text('Who is billing today?', style: TextStyle(fontSize: 14.sp, color: Colors.white60, fontFamily: 'Poppins')),
        SizedBox(height: 32.h),
        GridView.builder(
          shrinkWrap: true, physics: const NeverScrollableScrollPhysics(),
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: _users.length == 1 ? 1 : 2,
            crossAxisSpacing: 12.w, mainAxisSpacing: 12.h,
            childAspectRatio: _users.length == 1 ? 2.8 : 1.4,
          ),
          itemCount: _users.length,
          itemBuilder: (_, i) => _userCard(_users[i]),
        ),
        SizedBox(height: 32.h),
        // Change License button
        TextButton.icon(
          onPressed: () => setState(() {
            _step = LoginStep.licenseEntry;
            _licenseError = null;
            _licenseCtrl.clear();
          }),
          icon: Icon(Icons.swap_horiz, color: Colors.white54, size: 16.sp),
          label: Text('Change License', style: TextStyle(color: Colors.white54, fontSize: 13.sp, fontFamily: 'Poppins')),
        ),
        SizedBox(height: 24.h),
      ]),
    );
  }

  Widget _userCard(AppUser user) => GestureDetector(
    onTap: () => setState(() { _selectedUser = user; _step = LoginStep.pinEntry; _enteredPin = ''; _isPinWrong = false; }),
    child: Container(
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.08),
        borderRadius: BorderRadius.circular(16.r),
        border: Border.all(color: Colors.white.withOpacity(0.15)),
      ),
      child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
        Container(
          width: 52.w, height: 52.h,
          decoration: BoxDecoration(
            color: user.isAdmin ? AppTheme.primary.withOpacity(0.3) : Colors.white.withOpacity(0.12),
            shape: BoxShape.circle,
            border: Border.all(color: user.isAdmin ? AppTheme.primary : Colors.white.withOpacity(0.25), width: 2),
          ),
          child: Center(child: Text(user.username[0].toUpperCase(),
              style: TextStyle(fontSize: 22.sp, fontWeight: FontWeight.w700, color: Colors.white, fontFamily: 'Poppins'))),
        ),
        SizedBox(height: 8.h),
        Text(user.username, style: TextStyle(fontSize: 14.sp, fontWeight: FontWeight.w600, color: Colors.white, fontFamily: 'Poppins')),
        SizedBox(height: 3.h),
        Text('${user.role.emoji} ${user.role.label}', style: TextStyle(fontSize: 11.sp, color: Colors.white54, fontFamily: 'Poppins')),
      ]),
    ),
  );

  // ── Step 2: PIN Entry ─────────────────────────────────────────────────────

  Widget _buildPinEntry() {
    final user = _selectedUser!;
    return Column(children: [
      SizedBox(height: 24.h),
      Padding(
        padding: EdgeInsets.symmetric(horizontal: 24.w),
        child: Row(children: [
          GestureDetector(
            onTap: () => setState(() { _selectedUser = null; _step = LoginStep.userSelect; _enteredPin = ''; _isPinWrong = false; }),
            child: Container(
              width: 36.w, height: 36.h,
              decoration: BoxDecoration(color: Colors.white.withOpacity(0.1), shape: BoxShape.circle),
              child: Icon(Icons.arrow_back, color: Colors.white, size: 18.sp),
            ),
          ),
          const Spacer(),
        ]),
      ),
      SizedBox(height: 28.h),
      Container(
        width: 68.w, height: 68.h,
        decoration: BoxDecoration(
          color: user.isAdmin ? AppTheme.primary : Colors.white.withOpacity(0.12),
          shape: BoxShape.circle,
          border: Border.all(color: Colors.white.withOpacity(0.3), width: 2),
        ),
        child: Center(child: Text(user.username[0].toUpperCase(),
            style: TextStyle(fontSize: 28.sp, fontWeight: FontWeight.w700, color: Colors.white, fontFamily: 'Poppins'))),
      ),
      SizedBox(height: 10.h),
      Text(user.username, style: TextStyle(fontSize: 20.sp, fontWeight: FontWeight.w700, color: Colors.white, fontFamily: 'Poppins')),
      SizedBox(height: 3.h),
      Text('${user.role.emoji} ${user.role.label}', style: TextStyle(fontSize: 12.sp, color: Colors.white54, fontFamily: 'Poppins')),
      SizedBox(height: 6.h),
      Text('Enter PIN', style: TextStyle(fontSize: 14.sp, color: Colors.white54, fontFamily: 'Poppins')),
      SizedBox(height: 28.h),
      // Dots
      AnimatedBuilder(
        animation: _shakeAnim,
        builder: (_, child) => Transform.translate(
          offset: Offset(_isPinWrong ? _shakeAnim.value * ((_shakeCtrl.value * 10).toInt() % 2 == 0 ? 1 : -1) : 0, 0),
          child: child,
        ),
        child: Row(mainAxisAlignment: MainAxisAlignment.center, children: List.generate(4, (i) {
          final filled = i < _enteredPin.length;
          return AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            margin: EdgeInsets.symmetric(horizontal: 10.w), width: 18.w, height: 18.h,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: _isPinWrong ? AppTheme.danger : filled ? AppTheme.primary : Colors.white.withOpacity(0.2),
              border: Border.all(color: _isPinWrong ? AppTheme.danger : filled ? AppTheme.primary : Colors.white.withOpacity(0.35), width: 2),
            ),
          );
        })),
      ),
      if (_isPinWrong) ...[
        SizedBox(height: 10.h),
        Text('Wrong PIN. Try again.', style: TextStyle(color: AppTheme.danger, fontSize: 13.sp, fontFamily: 'Poppins')),
      ],
      const Spacer(),
      Padding(
        padding: EdgeInsets.symmetric(horizontal: 48.w),
        child: Column(children: [
          _row(['1', '2', '3']), SizedBox(height: 12.h),
          _row(['4', '5', '6']), SizedBox(height: 12.h),
          _row(['7', '8', '9']), SizedBox(height: 12.h),
          Row(mainAxisAlignment: MainAxisAlignment.spaceEvenly, children: [
            SizedBox(width: 72.w),
            _num('0'),
            GestureDetector(
              onTap: _onDelete,
              child: Container(
                width: 72.w, height: 72.h,
                decoration: BoxDecoration(color: Colors.white.withOpacity(0.07), shape: BoxShape.circle),
                child: Icon(Icons.backspace_outlined, color: Colors.white60, size: 22.sp),
              ),
            ),
          ]),
        ]),
      ),
      SizedBox(height: 36.h),
    ]);
  }

  Widget _row(List<String> d) => Row(mainAxisAlignment: MainAxisAlignment.spaceEvenly, children: d.map(_num).toList());

  Widget _num(String d) => GestureDetector(
    onTap: () => _onKey(d),
    child: Container(
      width: 72.w, height: 72.h,
      decoration: BoxDecoration(color: Colors.white.withOpacity(0.1), shape: BoxShape.circle, border: Border.all(color: Colors.white.withOpacity(0.12))),
      child: Center(child: Text(d, style: TextStyle(fontSize: 24.sp, fontWeight: FontWeight.w600, color: Colors.white, fontFamily: 'Poppins'))),
    ),
  );
}