import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:intl/intl.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../core/utils/currency_formatter.dart';
import '../../../expenses/presentation/bloc/expense_bloc.dart';
import '../../../products/presentation/bloc/product_bloc.dart';
import '../../../sales/presentation/bloc/sales_bloc.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  @override
  void initState() {
    super.initState();
    context.read<SalesBloc>().add(LoadSalesData());
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.surface,
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: () async {
            context.read<SalesBloc>().add(LoadSalesData());
          },
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: EdgeInsets.all(16.w),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildHeader(),
                SizedBox(height: 16.h),
                _buildTodaySummary(),
                SizedBox(height: 16.h),
                _buildMonthlyChart(),
                SizedBox(height: 16.h),
                _buildQuickStats(),
                SizedBox(height: 16.h),
                _buildLowStockAlert(),
                SizedBox(height: 80.h),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    final greeting = _getGreeting();
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(greeting, style: AppTheme.caption),
              Text('Dashboard', style: AppTheme.heading1),
            ],
          ),
        ),
        Text(
          DateFormat('EEE, d MMM').format(DateTime.now()),
          style: AppTheme.caption,
        ),
      ],
    );
  }

  String _getGreeting() {
    final hour = DateTime.now().hour;
    if (hour < 12) return 'Good Morning! 🌅';
    if (hour < 17) return 'Good Afternoon! ☀️';
    return 'Good Evening! 🌙';
  }

  Widget _buildTodaySummary() {
    return BlocBuilder<SalesBloc, SalesState>(
      builder: (context, state) {
        if (state is SalesLoaded) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text("Today's Summary", style: AppTheme.heading3),
              SizedBox(height: 10.h),
              Row(
                children: [
                  Expanded(
                    child: _summaryCard(
                      label: "Today's Sales",
                      value: CurrencyFormatter.format(state.todaySales),
                      icon: '💰',
                      color: AppTheme.primary,
                      sub: '${state.todayBillCount} bills',
                    ),
                  ),
                  SizedBox(width: 10.w),
                  Expanded(
                    child: _summaryCard(
                      label: "Today's Profit",
                      value: CurrencyFormatter.format(state.todayProfit),
                      icon: '📈',
                      color: AppTheme.accent,
                      sub: '${state.profitMargin.toStringAsFixed(1)}% margin',
                    ),
                  ),
                ],
              ),
              SizedBox(height: 10.h),
              Row(
                children: [
                  Expanded(
                    child: _summaryCard(
                      label: 'Monthly Sales',
                      value: CurrencyFormatter.format(state.monthlySales),
                      icon: '📅',
                      color: AppTheme.secondary,
                      sub: '${state.monthlyBillCount} bills',
                    ),
                  ),
                  SizedBox(width: 10.w),
                  Expanded(
                    child: _summaryCard(
                      label: 'Monthly Profit',
                      value: CurrencyFormatter.format(state.monthlyProfit),
                      icon: '🎯',
                      color: AppTheme.warning,
                      sub: 'After expenses',
                    ),
                  ),
                ],
              ),
            ],
          );
        }
        return const Center(child: CircularProgressIndicator());
      },
    );
  }

  Widget _summaryCard({
    required String label,
    required String value,
    required String icon,
    required Color color,
    String? sub,
  }) {
    return Container(
      padding: EdgeInsets.all(14.w),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16.r),
        border: Border.all(color: AppTheme.divider),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(icon, style: TextStyle(fontSize: 20.sp)),
              const Spacer(),
              Container(
                width: 8.w,
                height: 8.h,
                decoration: BoxDecoration(color: color, shape: BoxShape.circle),
              ),
            ],
          ),
          SizedBox(height: 8.h),
          Text(label, style: AppTheme.caption),
          SizedBox(height: 2.h),
          Text(
            value,
            style: TextStyle(
              fontSize: 18.sp,
              fontWeight: FontWeight.w700,
              color: color,
              fontFamily: 'Poppins',
            ),
          ),
          if (sub != null) ...[
            SizedBox(height: 2.h),
            Text(sub, style: AppTheme.caption.copyWith(fontSize: 10.sp)),
          ],
        ],
      ),
    );
  }

  Widget _buildMonthlyChart() {
    return BlocBuilder<SalesBloc, SalesState>(
      builder: (context, state) {
        if (state is! SalesLoaded || state.weeklyData.isEmpty) return const SizedBox();
        return Container(
          padding: EdgeInsets.all(16.w),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16.r),
            border: Border.all(color: AppTheme.divider),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Last 7 Days Sales', style: AppTheme.heading3),
              SizedBox(height: 16.h),
              SizedBox(
                height: 180.h,
                child: BarChart(
                  BarChartData(
                    alignment: BarChartAlignment.spaceAround,
                    barGroups: state.weeklyData.asMap().entries.map((e) {
                      return BarChartGroupData(
                        x: e.key,
                        barRods: [
                          BarChartRodData(
                            toY: e.value['sales']!,
                            color: AppTheme.primary,
                            width: 14.w,
                            borderRadius: BorderRadius.vertical(top: Radius.circular(4.r)),
                          ),
                        ],
                      );
                    }).toList(),
                    titlesData: FlTitlesData(
                      leftTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                      rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                      topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                      bottomTitles: AxisTitles(
                        sideTitles: SideTitles(
                          showTitles: true,
                          getTitlesWidget: (value, _) {
                            final days = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
                            return Text(days[value.toInt() % 7],
                                style: AppTheme.caption.copyWith(fontSize: 10.sp));
                          },
                        ),
                      ),
                    ),
                    gridData: FlGridData(
                      show: true,
                      drawVerticalLine: false,
                      getDrawingHorizontalLine: (_) => FlLine(color: AppTheme.divider, strokeWidth: 1),
                    ),
                    borderData: FlBorderData(show: false),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildQuickStats() {
    return BlocBuilder<ProductBloc, ProductState>(
      builder: (context, state) {
        if (state is! ProductsLoaded) return const SizedBox();
        final total = state.products.length;
        final lowStock = state.lowStockProducts.where((p) => !p.isOutOfStock).length;
        final outOfStock = state.lowStockProducts.where((p) => p.isOutOfStock).length;
        return Container(
          padding: EdgeInsets.all(16.w),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16.r),
            border: Border.all(color: AppTheme.divider),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Inventory Overview', style: AppTheme.heading3),
              SizedBox(height: 12.h),
              Row(
                children: [
                  Expanded(child: _statChip('Total\nProducts', '$total', AppTheme.secondary)),
                  SizedBox(width: 8.w),
                  Expanded(child: _statChip('Low\nStock', '$lowStock', AppTheme.warning)),
                  SizedBox(width: 8.w),
                  Expanded(child: _statChip('Out of\nStock', '$outOfStock', AppTheme.danger)),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _statChip(String label, String value, Color color) {
    return Container(
      padding: EdgeInsets.symmetric(vertical: 12.h),
      decoration: BoxDecoration(
        color: color.withOpacity(0.08),
        borderRadius: BorderRadius.circular(12.r),
      ),
      child: Column(
        children: [
          Text(value, style: TextStyle(fontSize: 22.sp, fontWeight: FontWeight.w700, color: color, fontFamily: 'Poppins')),
          SizedBox(height: 2.h),
          Text(label, style: AppTheme.caption.copyWith(fontSize: 10.sp), textAlign: TextAlign.center),
        ],
      ),
    );
  }

  Widget _buildLowStockAlert() {
    return BlocBuilder<ProductBloc, ProductState>(
      builder: (context, state) {
        if (state is! ProductsLoaded || state.lowStockProducts.isEmpty) return const SizedBox();
        return Container(
          padding: EdgeInsets.all(16.w),
          decoration: BoxDecoration(
            color: AppTheme.warning.withOpacity(0.08),
            borderRadius: BorderRadius.circular(16.r),
            border: Border.all(color: AppTheme.warning.withOpacity(0.3)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Icons.warning_amber_rounded, color: AppTheme.warning, size: 20.sp),
                  SizedBox(width: 8.w),
                  Text('Stock Alerts', style: AppTheme.heading3),
                ],
              ),
              SizedBox(height: 10.h),
              ...state.lowStockProducts.take(5).map((product) {
                return Padding(
                  padding: EdgeInsets.only(bottom: 6.h),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(product.name, style: AppTheme.body),
                      ),
                      Container(
                        padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 3.h),
                        decoration: BoxDecoration(
                          color: product.isOutOfStock ? AppTheme.danger : AppTheme.warning,
                          borderRadius: BorderRadius.circular(6.r),
                        ),
                        child: Text(
                          product.isOutOfStock
                              ? 'OUT OF STOCK'
                              : '${product.stockQuantity} ${product.unit} left',
                          style: TextStyle(color: Colors.white, fontSize: 10.sp, fontWeight: FontWeight.w600),
                        ),
                      ),
                    ],
                  ),
                );
              }),
            ],
          ),
        );
      },
    );
  }
}
