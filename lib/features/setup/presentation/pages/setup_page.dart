import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:image_picker/image_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:io';

import '../../../../core/theme/app_theme.dart';
import '../../../shell/presentation/pages/main_shell.dart';

class SetupPage extends StatefulWidget {
  const SetupPage({super.key});

  @override
  State<SetupPage> createState() => _SetupPageState();
}

class _SetupPageState extends State<SetupPage> {
  final _formKey = GlobalKey<FormState>();
  final _nameCtrl = TextEditingController();
  final _addressCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  final _thankYouCtrl = TextEditingController(text: 'Thank you for your visit! Come again!');
  String? _logoPath;
  int _currentStep = 0;
  bool _isSaving = false;

  @override
  void dispose() {
    _nameCtrl.dispose(); _addressCtrl.dispose();
    _phoneCtrl.dispose(); _thankYouCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickLogo() async {
    final picker = ImagePicker();
    final file = await picker.pickImage(source: ImageSource.gallery, maxWidth: 512, maxHeight: 512);
    if (file != null) setState(() => _logoPath = file.path);
  }

  Future<void> _saveSetup() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isSaving = true);

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('shop_name', _nameCtrl.text.trim());
    await prefs.setString('shop_address', _addressCtrl.text.trim());
    await prefs.setString('shop_phone', _phoneCtrl.text.trim());
    await prefs.setString('thank_you_msg', _thankYouCtrl.text.trim());
    if (_logoPath != null) await prefs.setString('logo_path', _logoPath!);
    await prefs.setBool('setup_done', true);

    if (!mounted) return;
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (_) => const MainShell()),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.surface,
      body: SafeArea(
        child: Form(
          key: _formKey,
          child: Column(
            children: [
              // Header
              Container(
                width: double.infinity,
                padding: EdgeInsets.all(24.w),
                color: Colors.white,
                child: Column(
                  children: [
                    Container(
                      width: 64.w,
                      height: 64.h,
                      decoration: BoxDecoration(
                        color: AppTheme.primary,
                        borderRadius: BorderRadius.circular(16.r),
                      ),
                      child: Icon(Icons.point_of_sale, color: Colors.white, size: 36.sp),
                    ),
                    SizedBox(height: 12.h),
                    Text('Setup Your Shop', style: AppTheme.heading1),
                    SizedBox(height: 4.h),
                    Text('Let\'s get you started in 2 minutes!', style: AppTheme.caption),
                  ],
                ),
              ),

              // Step indicator
              Padding(
                padding: EdgeInsets.symmetric(vertical: 16.h, horizontal: 24.w),
                child: Row(
                  children: [
                    _stepDot(0, 'Shop Info'),
                    Expanded(child: Container(height: 2, color: _currentStep > 0 ? AppTheme.primary : AppTheme.divider)),
                    _stepDot(1, 'Bill Template'),
                  ],
                ),
              ),

              Expanded(
                child: SingleChildScrollView(
                  padding: EdgeInsets.all(20.w),
                  child: _currentStep == 0 ? _buildStep1() : _buildStep2(),
                ),
              ),

              // Bottom Buttons
              Container(
                color: Colors.white,
                padding: EdgeInsets.all(16.w),
                child: Row(
                  children: [
                    if (_currentStep > 0)
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () => setState(() => _currentStep--),
                          style: OutlinedButton.styleFrom(minimumSize: Size(0, 48.h)),
                          child: const Text('Back'),
                        ),
                      ),
                    if (_currentStep > 0) SizedBox(width: 12.w),
                    Expanded(
                      flex: 2,
                      child: ElevatedButton(
                        onPressed: _isSaving
                            ? null
                            : () {
                          if (_currentStep == 0) {
                            if (_formKey.currentState!.validate()) {
                              setState(() => _currentStep = 1);
                            }
                          } else {
                            _saveSetup();
                          }
                        },
                        style: ElevatedButton.styleFrom(minimumSize: Size(0, 48.h)),
                        child: _isSaving
                            ? const CircularProgressIndicator(color: Colors.white)
                            : Text(_currentStep == 0 ? 'Next' : 'Start Billing! 🚀'),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStep1() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Shop Information', style: AppTheme.heading2),
        SizedBox(height: 4.h),
        Text('This will appear on your bills', style: AppTheme.caption),
        SizedBox(height: 20.h),
        TextFormField(
          controller: _nameCtrl,
          decoration: InputDecoration(
            labelText: 'Shop Name *',
            hintText: 'e.g. Ramu Tea Stall',
            prefixIcon: const Icon(Icons.store),
          ),
          validator: (v) => v!.trim().isEmpty ? 'Shop name is required' : null,
          textCapitalization: TextCapitalization.words,
        ),
        SizedBox(height: 12.h),
        TextFormField(
          controller: _addressCtrl,
          decoration: InputDecoration(
            labelText: 'Address',
            hintText: 'e.g. 12, Main Street, Chennai',
            prefixIcon: const Icon(Icons.location_on),
          ),
          maxLines: 2,
        ),
        SizedBox(height: 12.h),
        TextFormField(
          controller: _phoneCtrl,
          keyboardType: TextInputType.phone,
          decoration: InputDecoration(
            labelText: 'Phone Number',
            hintText: 'e.g. 9876543210',
            prefixIcon: const Icon(Icons.phone),
          ),
        ),
      ],
    );
  }

  Widget _buildStep2() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Bill Customization', style: AppTheme.heading2),
        SizedBox(height: 4.h),
        Text('Personalize your printed bills', style: AppTheme.caption),
        SizedBox(height: 20.h),

        // Logo Upload
        Text('Shop Logo (Optional)', style: AppTheme.heading3),
        SizedBox(height: 8.h),
        GestureDetector(
          onTap: _pickLogo,
          child: Container(
            width: 100.w,
            height: 100.h,
            decoration: BoxDecoration(
              color: AppTheme.surface,
              borderRadius: BorderRadius.circular(16.r),
              border: Border.all(
                color: _logoPath != null ? AppTheme.primary : AppTheme.divider,
                width: _logoPath != null ? 2 : 1,
              ),
            ),
            child: _logoPath != null
                ? ClipRRect(
              borderRadius: BorderRadius.circular(15.r),
              child: Image.file(File(_logoPath!), fit: BoxFit.cover),
            )
                : Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.add_photo_alternate, color: AppTheme.textSecondary, size: 28.sp),
                SizedBox(height: 4.h),
                Text('Upload Logo', style: AppTheme.caption, textAlign: TextAlign.center),
              ],
            ),
          ),
        ),
        SizedBox(height: 16.h),

        TextFormField(
          controller: _thankYouCtrl,
          decoration: InputDecoration(
            labelText: 'Thank You Message',
            hintText: 'Message at the bottom of bill',
            prefixIcon: const Icon(Icons.message),
          ),
          maxLines: 2,
        ),
        SizedBox(height: 20.h),

        // Preview
        Text('Bill Preview', style: AppTheme.heading3),
        SizedBox(height: 8.h),
        Container(
          width: double.infinity,
          padding: EdgeInsets.all(16.w),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12.r),
            border: Border.all(color: AppTheme.divider),
          ),
          child: Column(
            children: [
              if (_logoPath != null) ...[
                ClipRRect(
                  borderRadius: BorderRadius.circular(8.r),
                  child: Image.file(File(_logoPath!), width: 48.w, height: 48.h, fit: BoxFit.cover),
                ),
                SizedBox(height: 4.h),
              ],
              Text(
                _nameCtrl.text.isEmpty ? 'Your Shop Name' : _nameCtrl.text,
                style: AppTheme.heading3,
                textAlign: TextAlign.center,
              ),
              if (_addressCtrl.text.isNotEmpty)
                Text(_addressCtrl.text, style: AppTheme.caption, textAlign: TextAlign.center),
              if (_phoneCtrl.text.isNotEmpty)
                Text('Ph: ${_phoneCtrl.text}', style: AppTheme.caption),
              Divider(height: 12.h),
              Text('Item       Qty  Price  Total', style: TextStyle(fontSize: 10.sp, fontFamily: 'Poppins')),
              Divider(height: 8.h),
              Text('Sample Tea  2   10    20.00', style: TextStyle(fontSize: 10.sp, fontFamily: 'Poppins')),
              Divider(height: 8.h),
              Text('TOTAL: ₹20.00', style: TextStyle(fontSize: 12.sp, fontWeight: FontWeight.w700, fontFamily: 'Poppins')),
              SizedBox(height: 4.h),
              Text(
                _thankYouCtrl.text.isEmpty ? 'Thank you!' : _thankYouCtrl.text,
                style: AppTheme.caption,
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _stepDot(int step, String label) {
    final isActive = _currentStep >= step;
    return Column(
      children: [
        AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          width: 32.w,
          height: 32.h,
          decoration: BoxDecoration(
            color: isActive ? AppTheme.primary : AppTheme.divider,
            shape: BoxShape.circle,
          ),
          child: Center(
            child: isActive && _currentStep > step
                ? Icon(Icons.check, color: Colors.white, size: 16.sp)
                : Text('${step + 1}',
                style: TextStyle(
                  color: isActive ? Colors.white : AppTheme.textSecondary,
                  fontWeight: FontWeight.w600,
                  fontSize: 13.sp,
                  fontFamily: 'Poppins',
                )),
          ),
        ),
        SizedBox(height: 4.h),
        Text(label, style: AppTheme.caption.copyWith(fontSize: 10.sp)),
      ],
    );
  }
}
