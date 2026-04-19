import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../../../../core/theme/app_theme.dart';
import '../../domain/entities/license.dart';
import '../bloc/license_bloc.dart';
import '../bloc/license_event.dart';
import '../bloc/license_state.dart';
import '../widgets/mobile_number_input.dart';

/// Screen shown when no valid license is found.
/// Allows the user to enter their registered mobile number and select the
/// license type (offline/online) to activate the app.
class LicenseActivationPage extends StatefulWidget {
  /// Called when a valid license is confirmed so the caller can navigate away.
  final VoidCallback onActivated;

  const LicenseActivationPage({super.key, required this.onActivated});

  @override
  State<LicenseActivationPage> createState() => _LicenseActivationPageState();
}

class _LicenseActivationPageState extends State<LicenseActivationPage> {
  final _mobileCtrl = TextEditingController();
  LicenseType _selectedType = LicenseType.offline;
  String? _mobileError;

  @override
  void dispose() {
    _mobileCtrl.dispose();
    super.dispose();
  }

  Future<String> _getDeviceId() async {
    final info = DeviceInfoPlugin();
    try {
      final android = await info.androidInfo;
      return android.id;
    } catch (_) {
      try {
        final ios = await info.iosInfo;
        return ios.identifierForVendor ?? 'unknown';
      } catch (_) {
        return 'unknown';
      }
    }
  }

  void _onActivate() {
    final mobile = _mobileCtrl.text.trim();
    final error = validateMobileNumber(mobile);
    if (error != null) {
      setState(() => _mobileError = error);
      return;
    }
    setState(() => _mobileError = null);

    _getDeviceId().then((deviceId) {
      if (!mounted) return;
      context.read<LicenseBloc>().add(ActivateLicenseRequested(
            mobileNumber: mobile,
            licenseType: _selectedType,
            deviceId: deviceId,
          ));
    });
  }

  @override
  Widget build(BuildContext context) {
    return BlocListener<LicenseBloc, LicenseState>(
      listener: (context, state) {
        if (state is LicenseActivated || state is LicenseValid) {
          widget.onActivated();
        }
        if (state is LicenseError) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(state.message),
              backgroundColor: AppTheme.danger,
            ),
          );
        }
      },
      child: Scaffold(
        backgroundColor: const Color(0xFF2D3250),
        body: SafeArea(
          child: BlocBuilder<LicenseBloc, LicenseState>(
            builder: (context, state) {
              final isLoading = state is LicenseLoading;
              return SingleChildScrollView(
                padding: EdgeInsets.symmetric(horizontal: 24.w),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    SizedBox(height: 64.h),
                    // Logo
                    Container(
                      width: 72.w,
                      height: 72.h,
                      decoration: BoxDecoration(
                        color: AppTheme.primary,
                        borderRadius: BorderRadius.circular(20.r),
                      ),
                      child: Icon(Icons.point_of_sale,
                          color: Colors.white, size: 40.sp),
                    ),
                    SizedBox(height: 16.h),
                    Text(
                      'Activate Your License',
                      style: TextStyle(
                        fontSize: 22.sp,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                        fontFamily: 'Poppins',
                      ),
                      textAlign: TextAlign.center,
                    ),
                    SizedBox(height: 8.h),
                    Text(
                      'Enter the mobile number registered with your license',
                      style: TextStyle(
                        fontSize: 13.sp,
                        color: Colors.white60,
                        fontFamily: 'Poppins',
                      ),
                      textAlign: TextAlign.center,
                    ),
                    SizedBox(height: 40.h),
                    // Form card
                    Container(
                      padding: EdgeInsets.all(24.w),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.06),
                        borderRadius: BorderRadius.circular(20.r),
                        border: Border.all(
                            color: Colors.white.withOpacity(0.12)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          MobileNumberInput(
                            controller: _mobileCtrl,
                            errorText: _mobileError,
                            enabled: !isLoading,
                            onChanged: (_) =>
                                setState(() => _mobileError = null),
                          ),
                          SizedBox(height: 24.h),
                          // License type selector
                          Text(
                            'License Type',
                            style: TextStyle(
                              fontSize: 13.sp,
                              fontWeight: FontWeight.w600,
                              color: Colors.white70,
                              fontFamily: 'Poppins',
                            ),
                          ),
                          SizedBox(height: 10.h),
                          Row(
                            children: [
                              _typeCard(LicenseType.offline, Icons.wifi_off,
                                  'Offline', 'Local DB + Drive backup'),
                              SizedBox(width: 12.w),
                              _typeCard(LicenseType.online, Icons.cloud_sync,
                                  'Online', 'Auto Supabase sync'),
                            ],
                          ),
                          SizedBox(height: 24.h),
                          // Info about selected type
                          _infoCard(_selectedType),
                          SizedBox(height: 24.h),
                          // Activate button
                          ElevatedButton(
                            onPressed: isLoading ? null : _onActivate,
                            style: ElevatedButton.styleFrom(
                              minimumSize: Size(double.infinity, 50.h),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12.r),
                              ),
                            ),
                            child: isLoading
                                ? const CircularProgressIndicator(
                                    color: Colors.white)
                                : const Text('Activate License'),
                          ),
                        ],
                      ),
                    ),
                    SizedBox(height: 24.h),
                    Text(
                      'Contact us to get your license:\n📞 Support',
                      style: TextStyle(
                        fontSize: 12.sp,
                        color: Colors.white38,
                        fontFamily: 'Poppins',
                      ),
                      textAlign: TextAlign.center,
                    ),
                    SizedBox(height: 32.h),
                  ],
                ),
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _typeCard(
    LicenseType type,
    IconData icon,
    String title,
    String subtitle,
  ) {
    final selected = _selectedType == type;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _selectedType = type),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: EdgeInsets.all(12.w),
          decoration: BoxDecoration(
            color: selected
                ? AppTheme.primary.withOpacity(0.25)
                : Colors.white.withOpacity(0.05),
            borderRadius: BorderRadius.circular(12.r),
            border: Border.all(
              color:
                  selected ? AppTheme.primary : Colors.white.withOpacity(0.15),
              width: selected ? 2 : 1,
            ),
          ),
          child: Column(
            children: [
              Icon(icon,
                  color: selected ? AppTheme.primary : Colors.white54,
                  size: 24.sp),
              SizedBox(height: 6.h),
              Text(
                title,
                style: TextStyle(
                  fontSize: 13.sp,
                  fontWeight: FontWeight.w600,
                  color: selected ? Colors.white : Colors.white70,
                  fontFamily: 'Poppins',
                ),
              ),
              SizedBox(height: 2.h),
              Text(
                subtitle,
                style: TextStyle(
                  fontSize: 10.sp,
                  color: Colors.white38,
                  fontFamily: 'Poppins',
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _infoCard(LicenseType type) {
    final isOnline = type == LicenseType.online;
    final points = isOnline
        ? [
            '✅ Billing works offline & online',
            '☁️ Auto sync to Supabase when connected',
            '🔄 Sync queue — no data loss on reconnect',
            '🚫 No data loss even during network outage',
          ]
        : [
            '✅ Works fully offline after login',
            '💾 All data stored locally',
            '📂 Google Drive backup available',
            '🔒 Supabase used only for login & license',
          ];

    return Container(
      padding: EdgeInsets.all(12.w),
      decoration: BoxDecoration(
        color: (isOnline ? Colors.blue : Colors.green).withOpacity(0.1),
        borderRadius: BorderRadius.circular(10.r),
        border: Border.all(
          color: (isOnline ? Colors.blue : Colors.green).withOpacity(0.3),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: points
            .map(
              (p) => Padding(
                padding: EdgeInsets.only(bottom: 4.h),
                child: Text(
                  p,
                  style: TextStyle(
                    fontSize: 11.sp,
                    color: Colors.white70,
                    fontFamily: 'Poppins',
                  ),
                ),
              ),
            )
            .toList(),
      ),
    );
  }
}
