import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:intl/intl.dart';
import 'package:table_calendar/table_calendar.dart';

import '../../../../core/database/database_helper.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/utils/currency_formatter.dart';
import '../../../expenses/presentation/bloc/expense_bloc.dart';
import '../../../sales/data/repositories/sales_repository_impl.dart';

class ReportsPage extends StatefulWidget {
  const ReportsPage({super.key});

  @override
  State<ReportsPage> createState() => _ReportsPageState();
}

class _ReportsPageState extends State<ReportsPage>
    with SingleTickerProviderStateMixin {
  late TabController _tabs;
  DateTime _selectedDay = DateTime.now();
  bool _isLoading = false;

  // Daily report data
  List<Map<String, dynamic>> _dailyBills = [];
  double _dailySales = 0;
  double _dailyProfit = 0;
  double _dailyExpenses = 0;

  // Monthly data
  List<Map<String, dynamic>> _productWiseSales = [];
  double _monthlySales = 0;
  double _monthlyProfit = 0;
  double _monthlyExpenses = 0;

  late final SalesRepository _salesRepo;

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 3, vsync: this);
    _salesRepo = SalesRepositoryImpl(DatabaseHelper.instance);
    _loadData();
    _tabs.addListener(() => setState(() {}));
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    await Future.wait([_loadDailyData(), _loadMonthlyData()]);
    setState(() => _isLoading = false);
  }

  Future<void> _loadDailyData() async {
    final bills = await _salesRepo.getDailyReport(_selectedDay);
    final summary = await _salesRepo.getDailySummary(_selectedDay);
    final expenseBloc = context.read<ExpenseBloc>().state;
    double expenses = 0;
    if (expenseBloc is ExpenseLoaded) expenses = expenseBloc.todayTotal;
    setState(() {
      _dailyBills = bills;
      _dailySales = summary['sales'] ?? 0;
      _dailyProfit = summary['profit'] ?? 0;
      _dailyExpenses = expenses;
    });
  }

  Future<void> _loadMonthlyData() async {
    final now = DateTime.now();
    final from = DateTime(now.year, now.month, 1);
    final to = DateTime(now.year, now.month + 1, 0, 23, 59, 59);
    final productWise = await _salesRepo.getProductWiseSales(from, to);
    final summary = await _salesRepo.getMonthlySummary(now.year, now.month);
    final expenseBloc = context.read<ExpenseBloc>().state;
    double expenses = 0;
    if (expenseBloc is ExpenseLoaded) expenses = expenseBloc.monthlyTotal;
    setState(() {
      _productWiseSales = productWise;
      _monthlySales = summary['sales'] ?? 0;
      _monthlyProfit = summary['profit'] ?? 0;
      _monthlyExpenses = expenses;
    });
  }

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Reports'),
        bottom: TabBar(
          controller: _tabs,
          labelColor: AppTheme.primary,
          unselectedLabelColor: AppTheme.textSecondary,
          indicatorColor: AppTheme.primary,
          tabs: const [
            Tab(text: 'Daily'),
            Tab(text: 'Monthly'),
            Tab(text: 'Products'),
          ],
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : TabBarView(
        controller: _tabs,
        children: [
          _buildDailyReport(),
          _buildMonthlyReport(),
          _buildProductReport(),
        ],
      ),
    );
  }

  // ── Daily Tab ────────────────────────────────────────────────────────────────
  Widget _buildDailyReport() {
    return SingleChildScrollView(
      padding: EdgeInsets.all(16.w),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Calendar
          Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16.r),
              border: Border.all(color: AppTheme.divider),
            ),
            child: TableCalendar(
              firstDay: DateTime(2020),
              lastDay: DateTime.now(),
              focusedDay: _selectedDay,
              selectedDayPredicate: (day) => isSameDay(day, _selectedDay),
              onDaySelected: (selected, _) {
                setState(() => _selectedDay = selected);
                _loadDailyData();
              },
              calendarStyle: CalendarStyle(
                selectedDecoration: BoxDecoration(
                  color: AppTheme.primary,
                  shape: BoxShape.circle,
                ),
                todayDecoration: BoxDecoration(
                  color: AppTheme.primary.withOpacity(0.3),
                  shape: BoxShape.circle,
                ),
              ),
              headerStyle: HeaderStyle(
                formatButtonVisible: false,
                titleCentered: true,
                titleTextStyle: AppTheme.heading3,
              ),
            ),
          ),
          SizedBox(height: 16.h),

          Text(
            DateFormat('EEEE, d MMMM yyyy').format(_selectedDay),
            style: AppTheme.heading3,
          ),
          SizedBox(height: 12.h),

          // Summary Cards
          Row(
            children: [
              Expanded(child: _reportCard('Sales', CurrencyFormatter.format(_dailySales), AppTheme.primary, '💰')),
              SizedBox(width: 8.w),
              Expanded(child: _reportCard('Profit', CurrencyFormatter.format(_dailyProfit), AppTheme.accent, '📈')),
            ],
          ),
          SizedBox(height: 8.h),
          Row(
            children: [
              Expanded(child: _reportCard('Expenses', CurrencyFormatter.format(_dailyExpenses), AppTheme.danger, '💸')),
              SizedBox(width: 8.w),
              Expanded(child: _reportCard('Net Profit',
                  CurrencyFormatter.format(_dailyProfit - _dailyExpenses),
                  _dailyProfit - _dailyExpenses >= 0 ? AppTheme.accent : AppTheme.danger,
                  '🎯')),
            ],
          ),
          SizedBox(height: 16.h),

          if (_dailyBills.isNotEmpty) ...[
            Text('Bills (${_dailyBills.length})', style: AppTheme.heading3),
            SizedBox(height: 8.h),
            ..._dailyBills.map((bill) => Container(
              margin: EdgeInsets.only(bottom: 8.h),
              padding: EdgeInsets.all(12.w),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12.r),
                border: Border.all(color: AppTheme.divider),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Bill #${bill['bill_number']}', style: AppTheme.body.copyWith(fontWeight: FontWeight.w600)),
                        Text(bill['items_summary'] ?? '', style: AppTheme.caption, maxLines: 1, overflow: TextOverflow.ellipsis),
                        Text(DateFormat('h:mm a').format(DateTime.parse(bill['created_at'] as String)), style: AppTheme.caption),
                      ],
                    ),
                  ),
                  Text(
                    CurrencyFormatter.format((bill['total_amount'] as num).toDouble()),
                    style: AppTheme.price.copyWith(fontSize: 15.sp),
                  ),
                ],
              ),
            )),
          ] else
            Center(
              child: Padding(
                padding: EdgeInsets.symmetric(vertical: 24.h),
                child: Text('No bills on this date', style: AppTheme.caption),
              ),
            ),
        ],
      ),
    );
  }

  // ── Monthly Tab ──────────────────────────────────────────────────────────────
  Widget _buildMonthlyReport() {
    final net = _monthlyProfit - _monthlyExpenses;
    return SingleChildScrollView(
      padding: EdgeInsets.all(16.w),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(DateFormat('MMMM yyyy').format(DateTime.now()), style: AppTheme.heading2),
          SizedBox(height: 12.h),
          Row(
            children: [
              Expanded(child: _reportCard('Total Sales', CurrencyFormatter.format(_monthlySales), AppTheme.primary, '💰')),
              SizedBox(width: 8.w),
              Expanded(child: _reportCard('Total Profit', CurrencyFormatter.format(_monthlyProfit), AppTheme.accent, '📈')),
            ],
          ),
          SizedBox(height: 8.h),
          Row(
            children: [
              Expanded(child: _reportCard('Total Expenses', CurrencyFormatter.format(_monthlyExpenses), AppTheme.danger, '💸')),
              SizedBox(width: 8.w),
              Expanded(child: _reportCard('Net Profit', CurrencyFormatter.format(net),
                  net >= 0 ? AppTheme.accent : AppTheme.danger, '🎯')),
            ],
          ),
          SizedBox(height: 8.h),
          if (_monthlySales > 0)
            _reportCard(
              'Profit Margin',
              '${((_monthlyProfit / _monthlySales) * 100).toStringAsFixed(1)}%',
              AppTheme.secondary, '📊',
            ),
        ],
      ),
    );
  }

  // ── Product Tab ──────────────────────────────────────────────────────────────
  Widget _buildProductReport() {
    return _productWiseSales.isEmpty
        ? Center(child: Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [Text('📊', style: TextStyle(fontSize: 48.sp)), SizedBox(height: 12.h), Text('No sales data yet', style: AppTheme.heading3)],
    ))
        : ListView.separated(
      padding: EdgeInsets.all(16.w),
      itemCount: _productWiseSales.length,
      separatorBuilder: (_, __) => SizedBox(height: 8.h),
      itemBuilder: (_, i) {
        final p = _productWiseSales[i];
        return Container(
          padding: EdgeInsets.all(14.w),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12.r),
            border: Border.all(color: AppTheme.divider),
          ),
          child: Row(
            children: [
              Container(
                width: 36.w, height: 36.h,
                decoration: BoxDecoration(
                  color: AppTheme.primary.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8.r),
                ),
                child: Center(
                  child: Text('${i + 1}', style: TextStyle(color: AppTheme.primary,
                      fontWeight: FontWeight.w700, fontSize: 14.sp, fontFamily: 'Poppins')),
                ),
              ),
              SizedBox(width: 12.w),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(p['product_name'] as String, style: AppTheme.body.copyWith(fontWeight: FontWeight.w600)),
                    Text('Qty: ${(p['total_qty'] as num).toStringAsFixed(1)}  •  Bills: ${p['bill_count']}',
                        style: AppTheme.caption),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(CurrencyFormatter.format((p['total_revenue'] as num).toDouble()),
                      style: AppTheme.body.copyWith(fontWeight: FontWeight.w700, color: AppTheme.primary)),
                  Text('Profit: ${CurrencyFormatter.format((p['total_profit'] as num).toDouble())}',
                      style: AppTheme.caption.copyWith(color: AppTheme.accent)),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _reportCard(String label, String value, Color color, String emoji) {
    return Container(
      padding: EdgeInsets.all(14.w),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14.r),
        border: Border.all(color: AppTheme.divider),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(emoji, style: TextStyle(fontSize: 18.sp)),
              const Spacer(),
              Container(width: 8.w, height: 8.h, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
            ],
          ),
          SizedBox(height: 6.h),
          Text(label, style: AppTheme.caption),
          Text(value, style: TextStyle(fontSize: 16.sp, fontWeight: FontWeight.w700, color: color, fontFamily: 'Poppins')),
        ],
      ),
    );
  }
}
