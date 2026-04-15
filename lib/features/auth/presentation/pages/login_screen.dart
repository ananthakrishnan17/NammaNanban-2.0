import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../subscription/services/subscription_service.dart';
import '../../../subscription/presentation/pages/subscription_lock_screen.dart';
import '../../../shell/presentation/pages/main_shell.dart';
import '../../../users/domain/entities/app_user.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});
  @override State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> with TickerProviderStateMixin {
  AppUser? _selectedUser;
  List<AppUser> _users = [];
  bool _isLoading = true;
  String _shopName = '';

  String _enteredPin = '';
  bool _isPinWrong = false;
  late AnimationController _shakeCtrl;
  late Animation<double> _shakeAnim;

  @override
  void initState() {
    super.initState();
    _shakeCtrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 400));
    _shakeAnim = Tween<double>(begin: 0, end: 12).chain(CurveTween(curve: Curves.elasticIn)).animate(_shakeCtrl);
    _loadData();
  }

  @override void dispose() { _shakeCtrl.dispose(); super.dispose(); }

  Future<void> _loadData() async {
    final prefs = await SharedPreferences.getInstance();
    final bloc = context.read<UserBloc>();
    bloc.add(LoadUsers());
    await Future.delayed(const Duration(milliseconds: 500));
    final state = bloc.state;
    List<AppUser> users = state is UserListLoaded ? state.users.where((u) => u.isActive).toList() : [];

    if (users.isEmpty) {
      // Legacy: create admin from shop_pin
      final pin = prefs.getString('shop_pin') ?? '0000';
      users = [AppUser(id: 0, username: 'Admin', pin: pin, role: UserRole.admin, permissions: UserPermissions.admin(), createdAt: DateTime.now(), updatedAt: DateTime.now())];
    }
    setState(() { _users = users; _shopName = prefs.getString('shop_name') ?? 'Shop POS'; _isLoading = false; });
  }

  void _onKey(String d) {
    if (_enteredPin.length >= 4) return;
    setState(() { _enteredPin += d; _isPinWrong = false; });
    if (_enteredPin.length == 4) _verifyPin();
  }

  void _onDelete() { if (_enteredPin.isNotEmpty) setState(() => _enteredPin = _enteredPin.substring(0, _enteredPin.length - 1)); }

  Future<void> _verifyPin() async {
    final user = _selectedUser!;
    if (_enteredPin == user.pin) {
      final status = await SubscriptionService.instance.getStatus();
      if (!mounted) return;
      context.read<UserBloc>().currentUser = user;
      if (status.isLocked) {
        Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => SubscriptionLockScreen(status: status)));
      } else {
        Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const MainShell()));
      }
    } else {
      setState(() { _isPinWrong = true; _enteredPin = ''; });
      _shakeCtrl.forward(from: 0);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) return const Scaffold(backgroundColor: Color(0xFF2D3250), body: Center(child: CircularProgressIndicator(color: Colors.white)));
    return Scaffold(
      backgroundColor: const Color(0xFF2D3250),
      body: SafeArea(child: _selectedUser == null ? _buildUserSelect() : _buildPinEntry()),
    );
  }

  Widget _buildUserSelect() => SingleChildScrollView(
    padding: EdgeInsets.symmetric(horizontal: 24.w),
    child: Column(children: [
      SizedBox(height: 48.h),
      Container(width: 72.w, height: 72.h,
          decoration: BoxDecoration(color: AppTheme.primary, borderRadius: BorderRadius.circular(20.r)),
          child: Icon(Icons.point_of_sale, color: Colors.white, size: 40.sp)),
      SizedBox(height: 12.h),
      Text(_shopName, style: TextStyle(fontSize: 22.sp, fontWeight: FontWeight.w700, color: Colors.white, fontFamily: 'Poppins')),
      SizedBox(height: 4.h),
      Text('Who is billing today?', style: TextStyle(fontSize: 14.sp, color: Colors.white60, fontFamily: 'Poppins')),
      SizedBox(height: 32.h),
      GridView.builder(
        shrinkWrap: true, physics: const NeverScrollableScrollPhysics(),
        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: _users.length == 1 ? 1 : (_users.length == 2 ? 2 : 2),
            crossAxisSpacing: 12.w, mainAxisSpacing: 12.h,
            childAspectRatio: _users.length == 1 ? 2.8 : 1.4),
        itemCount: _users.length,
        itemBuilder: (_, i) => _userCard(_users[i]),
      ),
      SizedBox(height: 40.h),
    ]),
  );

  Widget _userCard(AppUser user) => GestureDetector(
    onTap: () => setState(() { _selectedUser = user; _enteredPin = ''; _isPinWrong = false; }),
    child: Container(
      decoration: BoxDecoration(color: Colors.white.withOpacity(0.08), borderRadius: BorderRadius.circular(16.r), border: Border.all(color: Colors.white.withOpacity(0.15))),
      child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
        Container(width: 52.w, height: 52.h,
            decoration: BoxDecoration(color: user.isAdmin ? AppTheme.primary.withOpacity(0.3) : Colors.white.withOpacity(0.12), shape: BoxShape.circle,
                border: Border.all(color: user.isAdmin ? AppTheme.primary : Colors.white.withOpacity(0.25), width: 2)),
            child: Center(child: Text(user.username[0].toUpperCase(),
                style: TextStyle(fontSize: 22.sp, fontWeight: FontWeight.w700, color: Colors.white, fontFamily: 'Poppins')))),
        SizedBox(height: 8.h),
        Text(user.username, style: TextStyle(fontSize: 14.sp, fontWeight: FontWeight.w600, color: Colors.white, fontFamily: 'Poppins')),
        SizedBox(height: 3.h),
        Text('${user.role.emoji} ${user.role.label}', style: TextStyle(fontSize: 11.sp, color: Colors.white54, fontFamily: 'Poppins')),
      ]),
    ),
  );

  Widget _buildPinEntry() {
    final user = _selectedUser!;
    return Column(children: [
      SizedBox(height: 24.h),
      Padding(padding: EdgeInsets.symmetric(horizontal: 24.w),
          child: Row(children: [
            GestureDetector(onTap: () => setState(() { _selectedUser = null; _enteredPin = ''; _isPinWrong = false; }),
                child: Container(width: 36.w, height: 36.h,
                    decoration: BoxDecoration(color: Colors.white.withOpacity(0.1), shape: BoxShape.circle),
                    child: Icon(Icons.arrow_back, color: Colors.white, size: 18.sp))),
            const Spacer(),
          ])),
      SizedBox(height: 28.h),
      Container(width: 68.w, height: 68.h,
          decoration: BoxDecoration(color: user.isAdmin ? AppTheme.primary : Colors.white.withOpacity(0.12), shape: BoxShape.circle,
              border: Border.all(color: Colors.white.withOpacity(0.3), width: 2)),
          child: Center(child: Text(user.username[0].toUpperCase(),
              style: TextStyle(fontSize: 28.sp, fontWeight: FontWeight.w700, color: Colors.white, fontFamily: 'Poppins')))),
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
            offset: Offset(_isPinWrong ? _shakeAnim.value * ((_shakeCtrl.value * 10).toInt() % 2 == 0 ? 1 : -1) : 0, 0), child: child),
        child: Row(mainAxisAlignment: MainAxisAlignment.center, children: List.generate(4, (i) {
          final filled = i < _enteredPin.length;
          return AnimatedContainer(duration: const Duration(milliseconds: 150),
              margin: EdgeInsets.symmetric(horizontal: 10.w), width: 18.w, height: 18.h,
              decoration: BoxDecoration(shape: BoxShape.circle,
                  color: _isPinWrong ? AppTheme.danger : filled ? AppTheme.primary : Colors.white.withOpacity(0.2),
                  border: Border.all(color: _isPinWrong ? AppTheme.danger : filled ? AppTheme.primary : Colors.white.withOpacity(0.35), width: 2)));
        })),
      ),
      if (_isPinWrong) ...[SizedBox(height: 10.h), Text('Wrong PIN. Try again.', style: TextStyle(color: AppTheme.danger, fontSize: 13.sp, fontFamily: 'Poppins'))],
      const Spacer(),
      Padding(
        padding: EdgeInsets.symmetric(horizontal: 48.w),
        child: Column(children: [
          _row(['1','2','3']), SizedBox(height: 12.h),
          _row(['4','5','6']), SizedBox(height: 12.h),
          _row(['7','8','9']), SizedBox(height: 12.h),
          Row(mainAxisAlignment: MainAxisAlignment.spaceEvenly, children: [
            SizedBox(width: 72.w),
            _num('0'),
            GestureDetector(onTap: _onDelete,
                child: Container(width: 72.w, height: 72.h,
                    decoration: BoxDecoration(color: Colors.white.withOpacity(0.07), shape: BoxShape.circle),
                    child: Icon(Icons.backspace_outlined, color: Colors.white60, size: 22.sp))),
          ]),
        ]),
      ),
      SizedBox(height: 36.h),
    ]);
  }

  Widget _row(List<String> d) => Row(mainAxisAlignment: MainAxisAlignment.spaceEvenly, children: d.map(_num).toList());
  Widget _num(String d) => GestureDetector(onTap: () => _onKey(d),
      child: Container(width: 72.w, height: 72.h,
          decoration: BoxDecoration(color: Colors.white.withOpacity(0.1), shape: BoxShape.circle, border: Border.all(color: Colors.white.withOpacity(0.12))),
          child: Center(child: Text(d, style: TextStyle(fontSize: 24.sp, fontWeight: FontWeight.w600, color: Colors.white, fontFamily: 'Poppins')))));
}