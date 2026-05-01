import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../../../../core/theme/app_theme.dart';
import '../../data/repositories/printer_settings_repository.dart';
import '../../domain/entities/bill_template.dart';

/// Full-screen page where users can choose a bill template and configure
/// print options (paper size, GST visibility, footer text, auto-print, etc.).
class BillTemplateSettingsPage extends StatefulWidget {
  const BillTemplateSettingsPage({super.key});

  @override
  State<BillTemplateSettingsPage> createState() =>
      _BillTemplateSettingsPageState();
}

class _BillTemplateSettingsPageState extends State<BillTemplateSettingsPage> {
  bool _loading = true;
  BillTemplateConfig _config = const BillTemplateConfig();
  late TextEditingController _footerCtrl;

  @override
  void initState() {
    super.initState();
    _footerCtrl = TextEditingController();
    _load();
  }

  @override
  void dispose() {
    _footerCtrl.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final cfg = await PrinterSettingsRepository.instance.loadConfig();
    if (mounted) {
      setState(() {
        _config = cfg;
        _footerCtrl.text = cfg.footerText;
        _loading = false;
      });
    }
  }

  Future<void> _save() async {
    final updated =
        _config.copyWith(footerText: _footerCtrl.text.trim());
    await PrinterSettingsRepository.instance.saveConfig(updated);
    setState(() => _config = updated);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Text('✅ Template settings saved'),
        backgroundColor: AppTheme.accent,
        behavior: SnackBarBehavior.floating,
        margin: EdgeInsets.only(bottom: 24.h, left: 16.w, right: 16.w),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10.r)),
      ),
    );
  }

  void _selectTemplate(BillTemplate t) {
    setState(() {
      _config = _config.copyWith(
        template: t,
        paperSize: t.defaultPaperSize,
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Bill Template Settings'),
        actions: [
          TextButton.icon(
            onPressed: _loading ? null : _save,
            icon: const Icon(Icons.save_outlined),
            label: const Text('Save'),
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: EdgeInsets.all(16.w),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _sectionHead('🗂️  Choose Template'),
                  SizedBox(height: 10.h),
                  ...BillTemplate.values.map(_buildTemplateCard),
                  SizedBox(height: 24.h),

                  _sectionHead('📐  Paper Size'),
                  SizedBox(height: 10.h),
                  _buildPaperSizePicker(),
                  SizedBox(height: 24.h),

                  _sectionHead('⚙️  Print Options'),
                  SizedBox(height: 8.h),
                  _buildOptionsCard(),
                  SizedBox(height: 24.h),

                  _sectionHead('📝  Footer Text'),
                  SizedBox(height: 8.h),
                  TextField(
                    controller: _footerCtrl,
                    decoration: InputDecoration(
                      hintText: 'Thank you for your visit!',
                      border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12.r)),
                    ),
                    maxLines: 2,
                  ),
                  SizedBox(height: 24.h),

                  _sectionHead('🖨️  Auto Print'),
                  SizedBox(height: 8.h),
                  _buildAutoPrintCard(),
                  SizedBox(height: 60.h),
                ],
              ),
            ),
      bottomNavigationBar: _loading
          ? null
          : SafeArea(
              child: Padding(
                padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 12.h),
                child: ElevatedButton.icon(
                  onPressed: _save,
                  icon: const Icon(Icons.check_circle_outline),
                  label: const Text('Save Template Settings'),
                  style: ElevatedButton.styleFrom(
                    minimumSize: Size(double.infinity, 50.h),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14.r)),
                  ),
                ),
              ),
            ),
    );
  }

  // ── Template Cards ──────────────────────────────────────────────────────────
  Widget _buildTemplateCard(BillTemplate t) {
    final isSelected = _config.template == t;
    return GestureDetector(
      onTap: () => _selectTemplate(t),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        margin: EdgeInsets.only(bottom: 10.h),
        padding: EdgeInsets.all(14.w),
        decoration: BoxDecoration(
          color: isSelected ? AppTheme.primary.withOpacity(0.06) : Colors.white,
          borderRadius: BorderRadius.circular(14.r),
          border: Border.all(
            color: isSelected ? AppTheme.primary : AppTheme.divider,
            width: isSelected ? 2 : 1,
          ),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: AppTheme.primary.withOpacity(0.12),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  )
                ]
              : [],
        ),
        child: Row(
          children: [
            Container(
              width: 44.w,
              height: 44.w,
              decoration: BoxDecoration(
                color: isSelected
                    ? AppTheme.primary.withOpacity(0.12)
                    : AppTheme.surface,
                borderRadius: BorderRadius.circular(10.r),
              ),
              child: Center(
                child: Text(t.emoji,
                    style: TextStyle(fontSize: 22.sp)),
              ),
            ),
            SizedBox(width: 12.w),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    t.label,
                    style: TextStyle(
                      fontSize: 14.sp,
                      fontWeight: FontWeight.w600,
                      fontFamily: 'Poppins',
                      color: isSelected
                          ? AppTheme.primary
                          : AppTheme.textPrimary,
                    ),
                  ),
                  SizedBox(height: 2.h),
                  Text(t.description, style: AppTheme.caption),
                  SizedBox(height: 4.h),
                  Container(
                    padding: EdgeInsets.symmetric(
                        horizontal: 8.w, vertical: 2.h),
                    decoration: BoxDecoration(
                      color: AppTheme.surface,
                      borderRadius: BorderRadius.circular(6.r),
                      border: Border.all(color: AppTheme.divider),
                    ),
                    child: Text(
                      t.defaultPaperSize,
                      style: AppTheme.caption.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            if (isSelected)
              Icon(Icons.check_circle,
                  color: AppTheme.primary, size: 22.sp),
          ],
        ),
      ),
    );
  }

  // ── Paper Size Picker ───────────────────────────────────────────────────────
  Widget _buildPaperSizePicker() {
    const sizes = ['58mm', '80mm', 'A4'];
    return Row(
      children: sizes.map((s) {
        final isSelected = _config.paperSize == s;
        return Expanded(
          child: GestureDetector(
            onTap: () =>
                setState(() => _config = _config.copyWith(paperSize: s)),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 150),
              margin: EdgeInsets.only(
                  right: s != sizes.last ? 8.w : 0),
              padding: EdgeInsets.symmetric(vertical: 12.h),
              decoration: BoxDecoration(
                color: isSelected
                    ? AppTheme.primary.withOpacity(0.10)
                    : AppTheme.surface,
                borderRadius: BorderRadius.circular(12.r),
                border: Border.all(
                  color: isSelected ? AppTheme.primary : AppTheme.divider,
                  width: isSelected ? 1.5 : 1,
                ),
              ),
              child: Center(
                child: Text(
                  s,
                  style: TextStyle(
                    fontSize: 13.sp,
                    fontWeight: isSelected
                        ? FontWeight.w700
                        : FontWeight.w500,
                    color: isSelected
                        ? AppTheme.primary
                        : AppTheme.textSecondary,
                    fontFamily: 'Poppins',
                  ),
                ),
              ),
            ),
          ),
        );
      }).toList(),
    );
  }

  // ── Options Card ────────────────────────────────────────────────────────────
  Widget _buildOptionsCard() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14.r),
        border: Border.all(color: AppTheme.divider),
      ),
      child: Column(
        children: [
          _switchTile(
            icon: Icons.image_outlined,
            title: 'Show Logo',
            subtitle: 'Display shop logo on bill',
            value: _config.showLogo,
            onChanged: (v) =>
                setState(() => _config = _config.copyWith(showLogo: v)),
          ),
          _divider(),
          _switchTile(
            icon: Icons.receipt_long_outlined,
            title: 'Show GST',
            subtitle: 'Print CGST / SGST breakdown',
            value: _config.showGst,
            onChanged: (v) =>
                setState(() => _config = _config.copyWith(showGst: v)),
          ),
          _divider(),
          _switchTile(
            icon: Icons.tag_outlined,
            title: 'Show HSN Code',
            subtitle: 'Print HSN code per line item',
            value: _config.showHsn,
            onChanged: (v) =>
                setState(() => _config = _config.copyWith(showHsn: v)),
          ),
          _divider(),
          _switchTile(
            icon: Icons.discount_outlined,
            title: 'Show Discount',
            subtitle: 'Show discount line on bill',
            value: _config.showDiscount,
            onChanged: (v) =>
                setState(() => _config = _config.copyWith(showDiscount: v)),
          ),
        ],
      ),
    );
  }

  // ── Auto-Print Card ─────────────────────────────────────────────────────────
  Widget _buildAutoPrintCard() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14.r),
        border: Border.all(color: AppTheme.divider),
      ),
      child: Column(
        children: [
          _switchTile(
            icon: Icons.print_outlined,
            title: 'Auto Print After Payment',
            subtitle: 'Print immediately after confirming payment',
            value: _config.autoPrint,
            onChanged: (v) =>
                setState(() => _config = _config.copyWith(autoPrint: v)),
          ),
          _divider(),
          ListTile(
            leading: Container(
              width: 36.w,
              height: 36.h,
              decoration: BoxDecoration(
                color: AppTheme.primary.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8.r),
              ),
              child: Icon(Icons.content_copy_outlined,
                  color: AppTheme.primary, size: 18.sp),
            ),
            title: Text('Number of Copies', style: AppTheme.body),
            subtitle: Text(
                '${_config.copies} ${_config.copies == 1 ? "copy" : "copies"}',
                style: AppTheme.caption),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  icon: const Icon(Icons.remove_circle_outline),
                  color: AppTheme.danger,
                  onPressed: _config.copies <= 1
                      ? null
                      : () => setState(() =>
                          _config = _config.copyWith(copies: _config.copies - 1)),
                ),
                Text('${_config.copies}',
                    style: AppTheme.heading3),
                IconButton(
                  icon: const Icon(Icons.add_circle_outline),
                  color: AppTheme.accent,
                  onPressed: _config.copies >= 5
                      ? null
                      : () => setState(() =>
                          _config = _config.copyWith(copies: _config.copies + 1)),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ── Helpers ─────────────────────────────────────────────────────────────────
  Widget _sectionHead(String t) => Padding(
        padding: EdgeInsets.only(bottom: 4.h),
        child: Text(t, style: AppTheme.heading3),
      );

  Widget _divider() => Divider(height: 0, indent: 16.w, color: AppTheme.divider);

  Widget _switchTile({
    required IconData icon,
    required String title,
    required String subtitle,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) =>
      SwitchListTile(
        secondary: Container(
          width: 36.w,
          height: 36.h,
          decoration: BoxDecoration(
            color: AppTheme.primary.withOpacity(0.1),
            borderRadius: BorderRadius.circular(8.r),
          ),
          child: Icon(icon, color: AppTheme.primary, size: 18.sp),
        ),
        title: Text(title, style: AppTheme.body),
        subtitle: Text(subtitle, style: AppTheme.caption),
        value: value,
        onChanged: onChanged,
        activeColor: AppTheme.primary,
      );
}
