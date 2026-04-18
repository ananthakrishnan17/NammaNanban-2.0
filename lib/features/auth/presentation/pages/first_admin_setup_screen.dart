import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../../../../core/supabase/supabase_auth_service.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../shell/presentation/pages/main_shell.dart';
import '../../../users/domain/entities/app_user.dart';

class FirstAdminSetupScreen extends StatefulWidget {
  const FirstAdminSetupScreen({super.key});

  @override
  State<FirstAdminSetupScreen> createState() => _FirstAdminSetupScreenState();
}

class _FirstAdminSetupScreenState extends State<FirstAdminSetupScreen> {
  final _usernameCtrl = TextEditingController();
  final _pinCtrl = TextEditingController();
  final _confirmPinCtrl = TextEditingController();

  bool _isSaving = false;
  String? _error;
  String? _usernameError;
  String? _pinError;
  String? _companyName;

  @override
  void initState() {
    super.initState();
    _loadCompanyName();
  }

  Future<void> _loadCompanyName() async {
    final cached = await SupabaseAuthService.instance.getCachedLicense();
    if (mounted) {
      setState(() => _companyName = cached?.companyName);
    }
  }

  @override
  void dispose() {
    _usernameCtrl.dispose();
    _pinCtrl.dispose();
    _confirmPinCtrl.dispose();
    super.dispose();
  }

  Future<void> _createAdmin() async {
    setState(() { _error = null; _usernameError = null; _pinError = null; });

    final username = _usernameCtrl.text.trim();
    final pin = _pinCtrl.text;
    final confirmPin = _confirmPinCtrl.text;

    if (username.isEmpty) {
      setState(() => _usernameError = 'Username is required');
      return;
    }
    if (pin.length != 4) {
      setState(() => _pinError = 'PIN must be exactly 4 digits');
      return;
    }
    if (pin != confirmPin) {
      setState(() => _pinError = 'PINs do not match');
      return;
    }

    setState(() => _isSaving = true);

    final now = DateTime.now();
    final user = AppUser(
      id: null,
      username: username,
      pin: pin,
      role: UserRole.admin,
      permissions: UserPermissions.admin(),
      isActive: true,
      createdAt: now,
      updatedAt: now,
    );

    final result = await SupabaseAuthService.instance.createCloudUser(user);
    if (!mounted) return;

    if (!result.success) {
      setState(() { _error = result.error; _isSaving = false; });
      return;
    }

    // Auto-login after creation
    final verified = await SupabaseAuthService.instance.verifyUserPin(username, pin);
    if (!mounted) return;

    if (verified != null) {
      context.read<UserBloc>().currentUser = verified;
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const MainShell()),
      );
    } else {
      setState(() { _error = 'Account created but login failed. Please restart the app.'; _isSaving = false; });
    }
  }

  @override
  Widget build(BuildContext context) {
    final company = _companyName ?? 'your shop';

    return Scaffold(
      backgroundColor: const Color(0xFF2D3250),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: EdgeInsets.symmetric(horizontal: 24.w),
          child: Column(crossAxisAlignment: CrossAxisAlignment.center, children: [
            SizedBox(height: 48.h),
            Container(
              width: 72.w, height: 72.h,
              decoration: BoxDecoration(color: AppTheme.primary, borderRadius: BorderRadius.circular(20.r)),
              child: Icon(Icons.admin_panel_settings, color: Colors.white, size: 38.sp),
            ),
            SizedBox(height: 16.h),
            Text('Setup First Admin',
                style: TextStyle(fontSize: 22.sp, fontWeight: FontWeight.w700, color: Colors.white, fontFamily: 'Poppins'),
                textAlign: TextAlign.center),
            SizedBox(height: 6.h),
            Text(
              'You are the first user for $company.\nCreate your admin account to get started.',
              style: TextStyle(fontSize: 13.sp, color: Colors.white60, fontFamily: 'Poppins', height: 1.5),
              textAlign: TextAlign.center,
            ),
            SizedBox(height: 36.h),
            Container(
              padding: EdgeInsets.all(24.w),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.06),
                borderRadius: BorderRadius.circular(20.r),
                border: Border.all(color: Colors.white.withOpacity(0.12)),
              ),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                // Username
                _label('Username'),
                SizedBox(height: 6.h),
                TextField(
                  controller: _usernameCtrl,
                  style: TextStyle(color: Colors.white, fontFamily: 'Poppins', fontSize: 14.sp),
                  decoration: _inputDeco(
                    hint: 'e.g. Admin',
                    icon: Icons.person_outline,
                    errorText: _usernameError,
                  ),
                  onChanged: (_) => setState(() => _usernameError = null),
                ),
                SizedBox(height: 14.h),

                // PIN
                _label('PIN (4 digits)'),
                SizedBox(height: 6.h),
                TextField(
                  controller: _pinCtrl,
                  keyboardType: TextInputType.number,
                  maxLength: 4,
                  obscureText: true,
                  style: TextStyle(color: Colors.white, fontFamily: 'Poppins', fontSize: 14.sp),
                  decoration: _inputDeco(
                    hint: '••••',
                    icon: Icons.lock_outline,
                    errorText: _pinError,
                  ),
                  onChanged: (_) => setState(() => _pinError = null),
                ),
                SizedBox(height: 14.h),

                // Confirm PIN
                _label('Confirm PIN'),
                SizedBox(height: 6.h),
                TextField(
                  controller: _confirmPinCtrl,
                  keyboardType: TextInputType.number,
                  maxLength: 4,
                  obscureText: true,
                  style: TextStyle(color: Colors.white, fontFamily: 'Poppins', fontSize: 14.sp),
                  decoration: _inputDeco(
                    hint: '••••',
                    icon: Icons.lock_outline,
                    errorText: _pinError != null && _confirmPinCtrl.text.isNotEmpty ? _pinError : null,
                  ),
                  onChanged: (_) => setState(() => _pinError = null),
                ),

                if (_error != null) ...[
                  SizedBox(height: 10.h),
                  Container(
                    padding: EdgeInsets.all(10.w),
                    decoration: BoxDecoration(
                      color: AppTheme.danger.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(8.r),
                      border: Border.all(color: AppTheme.danger.withOpacity(0.4)),
                    ),
                    child: Row(children: [
                      Icon(Icons.error_outline, color: AppTheme.danger, size: 16.sp),
                      SizedBox(width: 8.w),
                      Expanded(child: Text(_error!, style: TextStyle(color: AppTheme.danger, fontSize: 12.sp, fontFamily: 'Poppins'))),
                    ]),
                  ),
                ],

                SizedBox(height: 20.h),
                ElevatedButton(
                  onPressed: _isSaving ? null : _createAdmin,
                  style: ElevatedButton.styleFrom(minimumSize: Size(double.infinity, 50.h)),
                  child: _isSaving
                      ? SizedBox(width: 20.w, height: 20.h, child: const CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                      : const Text('Create Admin Account'),
                ),
              ]),
            ),
            SizedBox(height: 32.h),
          ]),
        ),
      ),
    );
  }

  Widget _label(String text) => Text(
    text,
    style: TextStyle(fontSize: 12.sp, fontWeight: FontWeight.w600, color: Colors.white60, fontFamily: 'Poppins'),
  );

  InputDecoration _inputDeco({required String hint, required IconData icon, String? errorText}) {
    return InputDecoration(
      hintText: hint,
      hintStyle: TextStyle(color: Colors.white30, fontFamily: 'Poppins', fontSize: 14.sp),
      prefixIcon: Icon(icon, color: Colors.white54, size: 20.sp),
      filled: true,
      fillColor: Colors.white.withOpacity(0.08),
      counterStyle: const TextStyle(color: Colors.transparent, height: 0),
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
      errorText: errorText,
      errorStyle: TextStyle(color: AppTheme.danger, fontSize: 11.sp, fontFamily: 'Poppins'),
    );
  }
}
