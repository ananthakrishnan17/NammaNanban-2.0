import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../../../../core/l10n/app_localizations.dart';
import '../../../../core/theme/app_theme.dart';

class LanguageSettingsPage extends StatefulWidget {
  const LanguageSettingsPage({super.key});
  @override State<LanguageSettingsPage> createState() => _LanguageSettingsPageState();
}

class _LanguageSettingsPageState extends State<LanguageSettingsPage> {
  AppLanguage _selected = AppLocalizations.instance.current;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Language / மொழி / भाषा')),
      body: ListView(
        padding: EdgeInsets.all(16.w),
        children: [
          Container(
            padding: EdgeInsets.all(14.w),
            decoration: BoxDecoration(color: AppTheme.primary.withOpacity(0.08),
                borderRadius: BorderRadius.circular(12.r), border: Border.all(color: AppTheme.primary.withOpacity(0.3))),
            child: Row(children: [
              const Icon(Icons.language, color: AppTheme.primary),
              SizedBox(width: 10.w),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('App Language', style: AppTheme.heading3),
                Text('Choose the language for the entire app', style: AppTheme.caption),
              ])),
            ]),
          ),
          SizedBox(height: 16.h),
          ...AppLanguage.values.map((lang) {
            final isSelected = _selected == lang;
            return GestureDetector(
              onTap: () async {
                setState(() => _selected = lang);
                await AppLocalizations.instance.setLanguage(lang);
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                    content: Text('Language changed to ${lang.nativeName}'),
                    backgroundColor: AppTheme.accent,
                    duration: const Duration(seconds: 2),
                  ));
                }
              },
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                margin: EdgeInsets.only(bottom: 10.h),
                padding: EdgeInsets.all(16.w),
                decoration: BoxDecoration(
                  color: isSelected ? AppTheme.primary.withOpacity(0.08) : Colors.white,
                  borderRadius: BorderRadius.circular(14.r),
                  border: Border.all(color: isSelected ? AppTheme.primary : AppTheme.divider, width: isSelected ? 2 : 1),
                ),
                child: Row(children: [
                  Text(lang.flag, style: TextStyle(fontSize: 28.sp)),
                  SizedBox(width: 14.w),
                  Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(lang.nativeName, style: TextStyle(fontSize: 16.sp, fontWeight: FontWeight.w600,
                        color: isSelected ? AppTheme.primary : AppTheme.textPrimary, fontFamily: 'Poppins')),
                    Text(lang.englishName, style: AppTheme.caption),
                  ])),
                  if (isSelected)
                    Container(
                      width: 28.w, height: 28.h,
                      decoration: const BoxDecoration(color: AppTheme.primary, shape: BoxShape.circle),
                      child: const Icon(Icons.check, color: Colors.white, size: 16),
                    ),
                ]),
              ),
            );
          }),
          SizedBox(height: 20.h),
          Container(
            padding: EdgeInsets.all(14.w),
            decoration: BoxDecoration(color: AppTheme.surface, borderRadius: BorderRadius.circular(12.r)),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('Note', style: AppTheme.heading3),
              SizedBox(height: 6.h),
              Text('Language change applies immediately to all screens. '
                  'Bills are always printed in English for compatibility with all thermal printers.',
                  style: AppTheme.caption),
            ]),
          ),
        ],
      ),
    );
  }
}