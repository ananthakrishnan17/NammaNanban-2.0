import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shimmer/shimmer.dart';

import '../../../../core/database/database_helper.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/utils/currency_formatter.dart';
import '../../../printer/services/printer_service.dart';
import '../../data/repositories/billing_repository_impl.dart';
import '../../domain/entities/bill.dart';

class AllBillsPage extends StatefulWidget {
  const AllBillsPage({super.key});

  @override
  State<AllBillsPage> createState() => _AllBillsPageState();
}

class _AllBillsPageState extends State<AllBillsPage> {
  late final BillingRepositoryImpl _repo;
  late DateTime _selectedDate;
  bool _isMonthView = false;
  List<Bill> _bills = [];
  bool _isLoading = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _repo = BillingRepositoryImpl(DatabaseHelper.instance);
    _selectedDate = DateTime.now();
    _load();
  }

  DateTime get _dayStart =>
      DateTime(_selectedDate.year, _selectedDate.month, _selectedDate.day);
  DateTime get _dayEnd =>
      DateTime(_selectedDate.year, _selectedDate.month, _selectedDate.day, 23, 59, 59);
  DateTime get _monthStart =>
      DateTime(_selectedDate.year, _selectedDate.month, 1);
  DateTime get _monthEnd =>
      DateTime(_selectedDate.year, _selectedDate.month + 1, 0, 23, 59, 59);

  DateTime get _fromDate => _isMonthView ? _monthStart : _dayStart;
  DateTime get _toDate => _isMonthView ? _monthEnd : _dayEnd;

  Future<void> _load() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      final data = await _repo.getAllBills(fromDate: _fromDate, toDate: _toDate);
      if (mounted) setState(() => _bills = data);
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _previousDay() {
    setState(() => _selectedDate = _selectedDate.subtract(const Duration(days: 1)));
    _isMonthView = false;
    _load();
  }

  void _nextDay() {
    setState(() => _selectedDate = _selectedDate.add(const Duration(days: 1)));
    _isMonthView = false;
    _load();
  }

  void _toggleMonthView() {
    setState(() => _isMonthView = !_isMonthView);
    _load();
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
    );
    if (picked != null && mounted) {
      setState(() {
        _selectedDate = picked;
        _isMonthView = false;
      });
      _load();
    }
  }

  String get _dateLabel {
    if (_isMonthView) {
      return DateFormat('MMMM yyyy').format(_selectedDate);
    }
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final sel = DateTime(_selectedDate.year, _selectedDate.month, _selectedDate.day);
    if (sel == today) return 'Today';
    if (sel == today.subtract(const Duration(days: 1))) return 'Yesterday';
    return DateFormat('d MMM yyyy').format(_selectedDate);
  }

  double get _totalSales => _bills.fold(0.0, (s, b) => s + b.totalAmount);
  double get _totalProfit => _bills.fold(0.0, (s, b) => s + b.totalProfit);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.surface,
      appBar: AppBar(
        title: const Text('All Bills'),
      ),
      body: Column(
        children: [
          _buildDatePicker(),
          if (!_isLoading && _bills.isNotEmpty) _buildSummaryCard(),
          Expanded(
            child: _isLoading
                ? _buildShimmer()
                : _error != null
                    ? _buildError()
                    : _bills.isEmpty
                        ? _buildEmpty()
                        : _buildBillList(),
          ),
        ],
      ),
    );
  }

  Widget _buildDatePicker() {
    return Container(
      color: Colors.white,
      padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 10.h),
      child: Row(
        children: [
          IconButton(
            icon: Icon(Icons.chevron_left, color: AppTheme.textPrimary, size: 22.sp),
            onPressed: _previousDay,
            visualDensity: VisualDensity.compact,
          ),
          Expanded(
            child: GestureDetector(
              onTap: _pickDate,
              child: Container(
                padding: EdgeInsets.symmetric(vertical: 8.h),
                decoration: BoxDecoration(
                  color: AppTheme.surface,
                  borderRadius: BorderRadius.circular(10.r),
                  border: Border.all(color: AppTheme.divider),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.calendar_today_rounded,
                        size: 15.sp, color: AppTheme.primary),
                    SizedBox(width: 6.w),
                    Text(
                      _dateLabel,
                      style: TextStyle(
                        fontSize: 14.sp,
                        fontWeight: FontWeight.w600,
                        color: AppTheme.textPrimary,
                        fontFamily: 'Poppins',
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          IconButton(
            icon: Icon(Icons.chevron_right, color: AppTheme.textPrimary, size: 22.sp),
            onPressed: _nextDay,
            visualDensity: VisualDensity.compact,
          ),
          SizedBox(width: 4.w),
          GestureDetector(
            onTap: _toggleMonthView,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 6.h),
              decoration: BoxDecoration(
                color: _isMonthView ? AppTheme.primary : AppTheme.surface,
                borderRadius: BorderRadius.circular(20.r),
                border: Border.all(
                  color: _isMonthView ? AppTheme.primary : AppTheme.divider,
                ),
              ),
              child: Text(
                'This Month',
                style: TextStyle(
                  fontSize: 11.sp,
                  fontWeight: FontWeight.w600,
                  color: _isMonthView ? Colors.white : AppTheme.textSecondary,
                  fontFamily: 'Poppins',
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryCard() {
    return Container(
      margin: EdgeInsets.fromLTRB(14.w, 10.h, 14.w, 0),
      padding: EdgeInsets.all(14.w),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16.r),
        border: Border.all(color: AppTheme.divider),
      ),
      child: Row(
        children: [
          _summaryItem('Total Bills', '${_bills.length}', AppTheme.secondary, '🧾'),
          _divider(),
          _summaryItem('Sales', CurrencyFormatter.format(_totalSales), AppTheme.primary, '💰'),
          _divider(),
          _summaryItem('Profit', CurrencyFormatter.format(_totalProfit), AppTheme.accent, '📈'),
        ],
      ),
    );
  }

  Widget _summaryItem(String label, String value, Color color, String emoji) {
    return Expanded(
      child: Column(
        children: [
          Text(emoji, style: TextStyle(fontSize: 18.sp)),
          SizedBox(height: 4.h),
          Text(
            value,
            style: TextStyle(
              fontSize: 13.sp,
              fontWeight: FontWeight.w700,
              color: color,
              fontFamily: 'Poppins',
            ),
          ),
          Text(label, style: AppTheme.caption.copyWith(fontSize: 10.sp)),
        ],
      ),
    );
  }

  Widget _divider() {
    return Container(width: 1, height: 48.h, color: AppTheme.divider);
  }

  Widget _buildBillList() {
    return ListView.separated(
      padding: EdgeInsets.all(14.w).copyWith(top: 10.h),
      itemCount: _bills.length,
      separatorBuilder: (_, __) => SizedBox(height: 8.h),
      itemBuilder: (_, i) => _BillCard(
        bill: _bills[i],
        onTap: () => _showBillDetail(_bills[i]),
      ),
    );
  }

  Future<void> _showBillDetail(Bill summary) async {
    // Show a loading indicator bottom sheet first, then replace with full bill
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => _BillDetailSheet(
        summaryBill: summary,
        repo: _repo,
      ),
    );
  }

  Widget _buildShimmer() {
    return Shimmer.fromColors(
      baseColor: Colors.grey.shade300,
      highlightColor: Colors.grey.shade100,
      child: ListView.separated(
        padding: EdgeInsets.all(14.w).copyWith(top: 10.h),
        itemCount: 6,
        separatorBuilder: (_, __) => SizedBox(height: 8.h),
        itemBuilder: (_, __) => Container(
          height: 86.h,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16.r),
          ),
        ),
      ),
    );
  }

  Widget _buildEmpty() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text('🧾', style: TextStyle(fontSize: 64.sp)),
          SizedBox(height: 16.h),
          Text('No Bills Found', style: AppTheme.heading3),
          SizedBox(height: 6.h),
          Text(
            _isMonthView
                ? 'No bills for ${DateFormat('MMMM yyyy').format(_selectedDate)}'
                : 'No bills for $_dateLabel',
            style: AppTheme.caption,
          ),
        ],
      ),
    );
  }

  Widget _buildError() {
    return Center(
      child: Padding(
        padding: EdgeInsets.all(24.w),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text('⚠️', style: TextStyle(fontSize: 48.sp)),
            SizedBox(height: 12.h),
            Text('Failed to load bills', style: AppTheme.heading3),
            SizedBox(height: 6.h),
            Text(_error ?? '', style: AppTheme.caption, textAlign: TextAlign.center),
            SizedBox(height: 16.h),
            ElevatedButton(onPressed: _load, child: const Text('Retry')),
          ],
        ),
      ),
    );
  }
}

// ── Bill Card ──────────────────────────────────────────────────────────────────

class _BillCard extends StatelessWidget {
  final Bill bill;
  final VoidCallback onTap;
  const _BillCard({required this.bill, required this.onTap});

  String _paymentIcon(String mode) {
    switch (mode.toLowerCase()) {
      case 'upi': return '📱';
      case 'card': return '💳';
      case 'credit': return '📋';
      case 'split': return '🔀';
      default: return '💵';
    }
  }

  @override
  Widget build(BuildContext context) {
    final dateStr = DateFormat('d MMM, h:mm a').format(bill.createdAt);
    final isWholesale = bill.billType == 'wholesale';
    final payIcon = _paymentIcon(bill.paymentMode);

    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: EdgeInsets.all(14.w),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16.r),
          border: Border.all(color: AppTheme.divider),
        ),
        child: Row(
          children: [
            // Left: icon badge
            Container(
              width: 44.w,
              height: 44.h,
              decoration: BoxDecoration(
                color: AppTheme.primary.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12.r),
              ),
              child: Center(
                child: Text(
                  isWholesale ? '📦' : '🛒',
                  style: TextStyle(fontSize: 20.sp),
                ),
              ),
            ),
            SizedBox(width: 12.w),
            // Middle: info
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          'Bill #${bill.billNumber}',
                          style: TextStyle(
                            fontSize: 13.sp,
                            fontWeight: FontWeight.w600,
                            color: AppTheme.textPrimary,
                            fontFamily: 'Poppins',
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      Container(
                        padding: EdgeInsets.symmetric(horizontal: 7.w, vertical: 2.h),
                        decoration: BoxDecoration(
                          color: (isWholesale ? AppTheme.secondary : AppTheme.primary)
                              .withOpacity(0.1),
                          borderRadius: BorderRadius.circular(6.r),
                        ),
                        child: Text(
                          isWholesale ? '📦 Wholesale' : '🛒 Retail',
                          style: TextStyle(
                            fontSize: 9.sp,
                            fontWeight: FontWeight.w600,
                            color: isWholesale ? AppTheme.secondary : AppTheme.primary,
                            fontFamily: 'Poppins',
                          ),
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: 3.h),
                  Text(dateStr, style: AppTheme.caption),
                  SizedBox(height: 2.h),
                  Row(
                    children: [
                      Text(
                        bill.customerName != null && bill.customerName!.isNotEmpty
                            ? bill.customerName!
                            : 'Walk-in',
                        style: AppTheme.caption,
                      ),
                      SizedBox(width: 6.w),
                      Text('•', style: AppTheme.caption),
                      SizedBox(width: 6.w),
                      Text('$payIcon ${bill.paymentMode.toUpperCase()}',
                          style: AppTheme.caption),
                    ],
                  ),
                ],
              ),
            ),
            SizedBox(width: 8.w),
            // Right: amount
            Text(
              CurrencyFormatter.format(bill.totalAmount),
              style: TextStyle(
                fontSize: 14.sp,
                fontWeight: FontWeight.w700,
                color: AppTheme.primary,
                fontFamily: 'Poppins',
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Bill Detail Bottom Sheet ───────────────────────────────────────────────────

class _BillDetailSheet extends StatefulWidget {
  final Bill summaryBill;
  final BillingRepositoryImpl repo;
  const _BillDetailSheet({required this.summaryBill, required this.repo});

  @override
  State<_BillDetailSheet> createState() => _BillDetailSheetState();
}

class _BillDetailSheetState extends State<_BillDetailSheet> {
  Bill? _fullBill;
  bool _isLoading = true;
  String? _error;
  String _shopName = '';

  @override
  void initState() {
    super.initState();
    _loadBill();
    _loadShopName();
  }

  Future<void> _loadShopName() async {
    final prefs = await SharedPreferences.getInstance();
    if (mounted) {
      setState(() => _shopName = prefs.getString('shop_name') ?? 'My Shop');
    }
  }

  Future<void> _loadBill() async {
    try {
      final bill = await widget.repo.getBillById(widget.summaryBill.id!);
      if (mounted) setState(() { _fullBill = bill; _isLoading = false; });
    } catch (e) {
      if (mounted) setState(() { _error = e.toString(); _isLoading = false; });
    }
  }

  Future<void> _onPrint() async {
    if (_fullBill == null) return;
    final printed = await PrinterService.instance.printBill(_fullBill!);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(printed ? '✅ Printed successfully!' : '⚠️ Printer not connected'),
      backgroundColor: printed ? AppTheme.accent : AppTheme.warning,
      behavior: SnackBarBehavior.floating,
      duration: const Duration(seconds: 3),
      margin: EdgeInsets.only(bottom: 24.h, left: 16.w, right: 16.w),
    ));
  }

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.7,
      minChildSize: 0.4,
      maxChildSize: 0.9,
      builder: (_, scrollController) {
        return Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(20.r)),
          ),
          child: Column(
            children: [
              // Drag handle
              Padding(
                padding: EdgeInsets.only(top: 10.h, bottom: 4.h),
                child: Container(
                  width: 40.w,
                  height: 4.h,
                  decoration: BoxDecoration(
                    color: AppTheme.divider,
                    borderRadius: BorderRadius.circular(2.r),
                  ),
                ),
              ),
              // Header
              Padding(
                padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 8.h),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        _shopName,
                        style: TextStyle(
                          fontSize: 16.sp,
                          fontWeight: FontWeight.w700,
                          color: AppTheme.textPrimary,
                          fontFamily: 'Poppins',
                        ),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close),
                      onPressed: () => Navigator.pop(context),
                      visualDensity: VisualDensity.compact,
                    ),
                  ],
                ),
              ),
              Divider(color: AppTheme.divider, height: 1),
              // Body
              Expanded(
                child: _isLoading
                    ? const Center(child: CircularProgressIndicator())
                    : _error != null
                        ? Center(child: Text('Error: $_error', style: AppTheme.caption))
                        : _buildContent(scrollController),
              ),
              // Bottom actions
              _buildBottomBar(),
            ],
          ),
        );
      },
    );
  }

  Widget _buildContent(ScrollController scrollController) {
    final bill = _fullBill!;
    final dateStr =
        DateFormat('dd MMM yyyy, hh:mm a').format(bill.createdAt);
    final isWholesale = bill.billType == 'wholesale';
    final subtotal = bill.items.fold(0.0, (s, i) => s + i.totalPrice);
    final hasDiscount = bill.discountAmount > 0;
    final hasTax = bill.gstTotal > 0;

    return ListView(
      controller: scrollController,
      padding: EdgeInsets.all(16.w),
      children: [
        // Bill meta row
        Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Bill #${bill.billNumber}',
                    style: TextStyle(
                      fontSize: 14.sp,
                      fontWeight: FontWeight.w700,
                      color: AppTheme.textPrimary,
                      fontFamily: 'Poppins',
                    ),
                  ),
                  SizedBox(height: 2.h),
                  Text(dateStr, style: AppTheme.caption),
                ],
              ),
            ),
            Container(
              padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 4.h),
              decoration: BoxDecoration(
                color: (isWholesale ? AppTheme.secondary : AppTheme.primary)
                    .withOpacity(0.1),
                borderRadius: BorderRadius.circular(8.r),
              ),
              child: Text(
                isWholesale ? '📦 Wholesale' : '🛒 Retail',
                style: TextStyle(
                  fontSize: 11.sp,
                  fontWeight: FontWeight.w600,
                  color: isWholesale ? AppTheme.secondary : AppTheme.primary,
                  fontFamily: 'Poppins',
                ),
              ),
            ),
          ],
        ),
        // Customer info
        if (bill.customerName != null && bill.customerName!.isNotEmpty) ...[
          SizedBox(height: 10.h),
          Container(
            padding: EdgeInsets.all(10.w),
            decoration: BoxDecoration(
              color: AppTheme.surface,
              borderRadius: BorderRadius.circular(10.r),
              border: Border.all(color: AppTheme.divider),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Customer', style: AppTheme.caption),
                SizedBox(height: 2.h),
                Text(
                  bill.customerName!,
                  style: TextStyle(
                    fontSize: 13.sp,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.textPrimary,
                    fontFamily: 'Poppins',
                  ),
                ),
                if (bill.customerAddress != null &&
                    bill.customerAddress!.isNotEmpty) ...[
                  SizedBox(height: 2.h),
                  Text(bill.customerAddress!, style: AppTheme.caption),
                ],
                if (bill.customerGstin != null &&
                    bill.customerGstin!.isNotEmpty) ...[
                  SizedBox(height: 2.h),
                  Text('GSTIN: ${bill.customerGstin!}', style: AppTheme.caption),
                ],
              ],
            ),
          ),
        ],
        SizedBox(height: 14.h),
        Divider(color: AppTheme.divider, height: 1),
        SizedBox(height: 8.h),
        // Items table header
        _tableHeader(),
        Divider(color: AppTheme.divider, height: 8),
        // Items
        ...bill.items.map((item) => _itemRow(item)),
        SizedBox(height: 8.h),
        Divider(color: AppTheme.divider, height: 1),
        SizedBox(height: 8.h),
        // Totals
        _totalRow('Subtotal', subtotal),
        if (hasDiscount) ...[
          SizedBox(height: 4.h),
          _totalRow('Discount', bill.discountAmount, isNegative: true),
        ],
        if (hasTax) ...[
          SizedBox(height: 4.h),
          _totalRow('GST', bill.gstTotal),
        ],
        SizedBox(height: 8.h),
        Divider(color: AppTheme.divider, height: 1),
        SizedBox(height: 6.h),
        _totalRow('Total', bill.totalAmount, isBold: true, isLarge: true),
        SizedBox(height: 12.h),
        Divider(color: AppTheme.divider, height: 1),
        SizedBox(height: 8.h),
        // Payment info
        _buildPaymentInfo(bill),
        SizedBox(height: 16.h),
      ],
    );
  }

  Widget _tableHeader() {
    return Row(
      children: [
        Expanded(
          flex: 4,
          child: Text('Item',
              style: TextStyle(
                  fontSize: 12.sp,
                  fontWeight: FontWeight.w600,
                  color: AppTheme.textSecondary)),
        ),
        SizedBox(
          width: 50.w,
          child: Text('Qty',
              style: TextStyle(
                  fontSize: 12.sp,
                  fontWeight: FontWeight.w600,
                  color: AppTheme.textSecondary),
              textAlign: TextAlign.center),
        ),
        SizedBox(
          width: 60.w,
          child: Text('Price',
              style: TextStyle(
                  fontSize: 12.sp,
                  fontWeight: FontWeight.w600,
                  color: AppTheme.textSecondary),
              textAlign: TextAlign.right),
        ),
        SizedBox(
          width: 64.w,
          child: Text('Total',
              style: TextStyle(
                  fontSize: 12.sp,
                  fontWeight: FontWeight.w600,
                  color: AppTheme.textSecondary),
              textAlign: TextAlign.right),
        ),
      ],
    );
  }

  Widget _itemRow(BillItem item) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 4.h),
      child: Row(
        children: [
          Expanded(
            flex: 4,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(item.productName,
                    style: TextStyle(
                        fontSize: 13.sp,
                        fontWeight: FontWeight.w500,
                        color: AppTheme.textPrimary,
                        fontFamily: 'Poppins')),
                Text(item.unit, style: AppTheme.caption),
              ],
            ),
          ),
          SizedBox(
            width: 50.w,
            child: Text(
              item.quantity % 1 == 0
                  ? item.quantity.toInt().toString()
                  : item.quantity.toStringAsFixed(2),
              style: TextStyle(fontSize: 13.sp, color: AppTheme.textPrimary),
              textAlign: TextAlign.center,
            ),
          ),
          SizedBox(
            width: 60.w,
            child: Text(
              CurrencyFormatter.format(item.unitPrice),
              style: TextStyle(fontSize: 12.sp, color: AppTheme.textSecondary),
              textAlign: TextAlign.right,
            ),
          ),
          SizedBox(
            width: 64.w,
            child: Text(
              CurrencyFormatter.format(item.totalPrice),
              style: TextStyle(
                  fontSize: 13.sp,
                  fontWeight: FontWeight.w600,
                  color: AppTheme.textPrimary),
              textAlign: TextAlign.right,
            ),
          ),
        ],
      ),
    );
  }

  Widget _totalRow(String label, double amount,
      {bool isBold = false, bool isLarge = false, bool isNegative = false}) {
    final style = TextStyle(
      fontSize: isLarge ? 15.sp : 13.sp,
      fontWeight: isBold ? FontWeight.w700 : FontWeight.w400,
      color: isNegative
          ? AppTheme.danger
          : (isBold ? AppTheme.primary : AppTheme.textPrimary),
      fontFamily: 'Poppins',
    );
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: style),
        Text(
          isNegative
              ? '- ${CurrencyFormatter.format(amount.abs())}'
              : CurrencyFormatter.format(amount),
          style: style,
        ),
      ],
    );
  }

  Widget _buildPaymentInfo(Bill bill) {
    final hasSplit = bill.splitPaymentSummary != null &&
        bill.splitPaymentSummary!.isNotEmpty;
    String payIcon;
    switch (bill.paymentMode.toLowerCase()) {
      case 'upi': payIcon = '📱'; break;
      case 'card': payIcon = '💳'; break;
      case 'credit': payIcon = '📋'; break;
      case 'split': payIcon = '🔀'; break;
      default: payIcon = '💵';
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Payment', style: AppTheme.caption),
        SizedBox(height: 4.h),
        if (hasSplit)
          Text(
            bill.splitPaymentSummary!,
            style: TextStyle(
                fontSize: 13.sp,
                fontWeight: FontWeight.w600,
                color: AppTheme.textPrimary),
          )
        else
          Text(
            '$payIcon ${bill.paymentMode.toUpperCase()}',
            style: TextStyle(
                fontSize: 13.sp,
                fontWeight: FontWeight.w600,
                color: AppTheme.primary),
          ),
      ],
    );
  }

  Widget _buildBottomBar() {
    return Container(
      padding: EdgeInsets.fromLTRB(16.w, 8.h, 16.w, 16.h),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: AppTheme.divider)),
      ),
      child: Row(
        children: [
          Expanded(
            child: OutlinedButton.icon(
              onPressed: _isLoading ? null : _onPrint,
              icon: const Text('🖨️'),
              label: const Text('Print'),
              style: OutlinedButton.styleFrom(
                padding: EdgeInsets.symmetric(vertical: 12.h),
                side: BorderSide(color: AppTheme.primary),
                foregroundColor: AppTheme.primary,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10.r)),
              ),
            ),
          ),
          SizedBox(width: 12.w),
          Expanded(
            child: ElevatedButton.icon(
              onPressed: () => Navigator.pop(context),
              icon: const Icon(Icons.close, size: 16),
              label: const Text('Close'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.secondary,
                foregroundColor: Colors.white,
                padding: EdgeInsets.symmetric(vertical: 12.h),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10.r)),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
