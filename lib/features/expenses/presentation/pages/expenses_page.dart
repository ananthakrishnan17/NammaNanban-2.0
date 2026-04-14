import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:intl/intl.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../core/utils/currency_formatter.dart';
import '../bloc/expense_bloc.dart';

class ExpensesPage extends StatefulWidget {
  const ExpensesPage({super.key});

  @override
  State<ExpensesPage> createState() => _ExpensesPageState();
}

class _ExpensesPageState extends State<ExpensesPage>
    with SingleTickerProviderStateMixin {
  late TabController _tabs;

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 2, vsync: this);
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
        title: const Text('Expenses'),
        bottom: TabBar(
          controller: _tabs,
          labelColor: AppTheme.primary,
          unselectedLabelColor: AppTheme.textSecondary,
          indicatorColor: AppTheme.primary,
          tabs: const [Tab(text: "Today"), Tab(text: "This Month")],
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showAddExpenseSheet(context),
        backgroundColor: AppTheme.primary,
        icon: const Icon(Icons.add, color: Colors.white),
        label: const Text('Add Expense', style: TextStyle(color: Colors.white)),
      ),
      body: BlocBuilder<ExpenseBloc, ExpenseState>(
        builder: (context, state) {
          if (state is ExpenseLoading) {
            return const Center(child: CircularProgressIndicator());
          }
          if (state is ExpenseLoaded) {
            return TabBarView(
              controller: _tabs,
              children: [
                _buildDayView(state),
                _buildMonthView(state),
              ],
            );
          }
          return const Center(child: CircularProgressIndicator());
        },
      ),
    );
  }

  Widget _buildDayView(ExpenseLoaded state) {
    return Column(
      children: [
        // Summary
        Container(
          margin: EdgeInsets.all(12.w),
          padding: EdgeInsets.all(16.w),
          decoration: BoxDecoration(
            color: AppTheme.danger.withOpacity(0.08),
            borderRadius: BorderRadius.circular(16.r),
            border: Border.all(color: AppTheme.danger.withOpacity(0.2)),
          ),
          child: Row(
            children: [
              Text('💸', style: TextStyle(fontSize: 28.sp)),
              SizedBox(width: 12.w),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text("Today's Expenses", style: AppTheme.caption),
                  Text(
                    CurrencyFormatter.format(state.todayTotal),
                    style: TextStyle(fontSize: 22.sp, fontWeight: FontWeight.w700,
                        color: AppTheme.danger, fontFamily: 'Poppins'),
                  ),
                ],
              ),
            ],
          ),
        ),
        Expanded(
          child: state.todayExpenses.isEmpty
              ? _emptyState("No expenses today")
              : ListView.separated(
            padding: EdgeInsets.symmetric(horizontal: 12.w),
            itemCount: state.todayExpenses.length,
            separatorBuilder: (_, __) => SizedBox(height: 8.h),
            itemBuilder: (_, i) => _expenseTile(context, state.todayExpenses[i]),
          ),
        ),
        SizedBox(height: 80.h),
      ],
    );
  }

  Widget _buildMonthView(ExpenseLoaded state) {
    return Column(
      children: [
        // Summary
        Container(
          margin: EdgeInsets.all(12.w),
          padding: EdgeInsets.all(16.w),
          decoration: BoxDecoration(
            color: AppTheme.danger.withOpacity(0.08),
            borderRadius: BorderRadius.circular(16.r),
            border: Border.all(color: AppTheme.danger.withOpacity(0.2)),
          ),
          child: Row(
            children: [
              Text('📊', style: TextStyle(fontSize: 28.sp)),
              SizedBox(width: 12.w),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Monthly Expenses', style: AppTheme.caption),
                  Text(
                    CurrencyFormatter.format(state.monthlyTotal),
                    style: TextStyle(fontSize: 22.sp, fontWeight: FontWeight.w700,
                        color: AppTheme.danger, fontFamily: 'Poppins'),
                  ),
                ],
              ),
            ],
          ),
        ),
        // Category Breakdown
        if (state.categoryBreakdown.isNotEmpty)
          Container(
            margin: EdgeInsets.symmetric(horizontal: 12.w),
            padding: EdgeInsets.all(14.w),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(14.r),
              border: Border.all(color: AppTheme.divider),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('By Category', style: AppTheme.heading3),
                SizedBox(height: 10.h),
                ...state.categoryBreakdown.entries.map((e) => Padding(
                  padding: EdgeInsets.only(bottom: 6.h),
                  child: Row(
                    children: [
                      Text(_categoryEmoji(e.key), style: TextStyle(fontSize: 16.sp)),
                      SizedBox(width: 8.w),
                      Expanded(child: Text(e.key, style: AppTheme.body)),
                      Text(CurrencyFormatter.format(e.value),
                          style: AppTheme.body.copyWith(fontWeight: FontWeight.w600)),
                    ],
                  ),
                )),
              ],
            ),
          ),
        SizedBox(height: 12.h),
        Expanded(
          child: state.monthlyExpenses.isEmpty
              ? _emptyState("No expenses this month")
              : ListView.separated(
            padding: EdgeInsets.symmetric(horizontal: 12.w),
            itemCount: state.monthlyExpenses.length,
            separatorBuilder: (_, __) => SizedBox(height: 8.h),
            itemBuilder: (_, i) => _expenseTile(context, state.monthlyExpenses[i]),
          ),
        ),
        SizedBox(height: 80.h),
      ],
    );
  }

  Widget _expenseTile(BuildContext context, Expense expense) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12.r),
        border: Border.all(color: AppTheme.divider),
      ),
      child: ListTile(
        leading: Container(
          width: 40.w,
          height: 40.h,
          decoration: BoxDecoration(
            color: AppTheme.danger.withOpacity(0.1),
            borderRadius: BorderRadius.circular(10.r),
          ),
          child: Center(child: Text(_categoryEmoji(expense.category), style: TextStyle(fontSize: 18.sp))),
        ),
        title: Text(expense.category, style: AppTheme.heading3),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (expense.description != null) Text(expense.description!, style: AppTheme.caption),
            Text(DateFormat('dd MMM, h:mm a').format(expense.date), style: AppTheme.caption),
          ],
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              CurrencyFormatter.format(expense.amount),
              style: TextStyle(fontSize: 16.sp, fontWeight: FontWeight.w700,
                  color: AppTheme.danger, fontFamily: 'Poppins'),
            ),
            IconButton(
              icon: const Icon(Icons.delete_outline, color: AppTheme.danger, size: 20),
              onPressed: () => context.read<ExpenseBloc>().add(DeleteExpenseEvent(expense.id!)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _emptyState(String msg) => Center(
    child: Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text('💸', style: TextStyle(fontSize: 48.sp)),
        SizedBox(height: 12.h),
        Text(msg, style: AppTheme.heading3),
      ],
    ),
  );

  String _categoryEmoji(String category) {
    switch (category.toLowerCase()) {
      case 'rent': return '🏠';
      case 'electricity': return '⚡';
      case 'water': return '💧';
      case 'raw materials': return '🌾';
      case 'salary': return '👷';
      case 'transport': return '🚗';
      case 'packaging': return '📦';
      case 'maintenance': return '🔧';
      default: return '💰';
    }
  }

  void _showAddExpenseSheet(BuildContext context) {
    String? selectedCategory;
    final amountCtrl = TextEditingController();
    final descCtrl = TextEditingController();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => StatefulBuilder(
        builder: (ctx, setSt) => Container(
          padding: EdgeInsets.only(
            left: 20.w, right: 20.w, top: 20.h,
            bottom: MediaQuery.of(ctx).viewInsets.bottom + 20.h,
          ),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24.r)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Center(
                child: Container(
                  width: 40.w, height: 4.h,
                  decoration: BoxDecoration(
                    color: AppTheme.divider, borderRadius: BorderRadius.circular(2.r),
                  ),
                ),
              ),
              SizedBox(height: 16.h),
              Text('Add Expense', style: AppTheme.heading2),
              SizedBox(height: 16.h),
              // Category
              Wrap(
                spacing: 8.w,
                runSpacing: 8.h,
                children: kExpenseCategories.map((cat) {
                  final isSelected = selectedCategory == cat;
                  return GestureDetector(
                    onTap: () => setSt(() => selectedCategory = cat),
                    child: Container(
                      padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 6.h),
                      decoration: BoxDecoration(
                        color: isSelected ? AppTheme.primary : AppTheme.surface,
                        borderRadius: BorderRadius.circular(20.r),
                        border: Border.all(
                          color: isSelected ? AppTheme.primary : AppTheme.divider,
                        ),
                      ),
                      child: Text(
                        '${_categoryEmoji(cat)} $cat',
                        style: TextStyle(
                          fontSize: 12.sp,
                          color: isSelected ? Colors.white : AppTheme.textPrimary,
                          fontFamily: 'Poppins',
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
              SizedBox(height: 14.h),
              TextField(
                controller: amountCtrl,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: 'Amount *', prefixText: '₹ '),
              ),
              SizedBox(height: 10.h),
              TextField(
                controller: descCtrl,
                decoration: const InputDecoration(labelText: 'Description (optional)'),
              ),
              SizedBox(height: 16.h),
              ElevatedButton(
                onPressed: () {
                  if (selectedCategory == null || amountCtrl.text.isEmpty) return;
                  final now = DateTime.now();
                  context.read<ExpenseBloc>().add(AddExpenseEvent(Expense(
                    category: selectedCategory!,
                    description: descCtrl.text.isEmpty ? null : descCtrl.text,
                    amount: double.parse(amountCtrl.text),
                    date: now,
                    createdAt: now,
                  )));
                  Navigator.pop(context);
                },
                child: const Text('Save Expense'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
