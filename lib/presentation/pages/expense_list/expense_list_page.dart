import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';

import '../../../domain/entities/expense.dart';
import '../../blocs/expense/expense_bloc.dart';
import '../../router/app_router.dart';
// import dashboard_page.dart เพื่อใช้ AppRouteObserver (หรือแยกไฟล์ core ก็ได้)
import '../dashboard/dashboard_page.dart';

@RoutePage()
class ExpenseListPage extends StatefulWidget {
  const ExpenseListPage({super.key});

  @override
  State<ExpenseListPage> createState() => _ExpenseListPageState();
}

class _ExpenseListPageState extends State<ExpenseListPage> with RouteAware {
  @override
  void initState() {
    super.initState();
    _loadExpenses();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final route = ModalRoute.of(context);
    if (route != null) {
      AppRouteObserver.instance.subscribe(this, route);
    }
  }

  @override
  void dispose() {
    AppRouteObserver.instance.unsubscribe(this);
    super.dispose();
  }

  /// โหลดซ้ำเมื่อกลับมาจากหน้า Add/Edit
  @override
  void didPopNext() {
    _loadExpenses();
  }

  void _loadExpenses() {
    context.read<ExpenseBloc>().add(LoadExpensesEvent());
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('📋 รายการรายจ่าย'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'รีเฟรช',
            onPressed: _loadExpenses,
          ),
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: () async {
              await context.router.push(AddEditExpenseRoute());
              if (mounted) _loadExpenses();
            },
          ),
        ],
      ),
      body: BlocConsumer<ExpenseBloc, ExpenseState>(
        // listenWhen/buildWhen แยกกันเพื่อไม่ให้ rebuild ที่ไม่จำเป็น
        listenWhen: (prev, curr) =>
        prev.errorMessage != curr.errorMessage ||
            prev.justDeleted != curr.justDeleted,
        listener: (context, state) {
          if (state.errorMessage != null) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                  content: Text(state.errorMessage!),
                  backgroundColor: Colors.red),
            );
          }
        },
        buildWhen: (prev, curr) =>
        prev.isLoading != curr.isLoading ||
            prev.expenses != curr.expenses ||
            prev.justDeleted != curr.justDeleted,
        builder: (context, state) {
          if (state.isLoading && state.expenses.isEmpty) {
            return const Center(child: CircularProgressIndicator());
          }
          if (state.expenses.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Text('🧾', style: TextStyle(fontSize: 64)),
                  const SizedBox(height: 16),
                  const Text('ยังไม่มีรายจ่าย'),
                  const SizedBox(height: 16),
                  FilledButton.icon(
                    onPressed: () async {
                      await context.router.push(AddEditExpenseRoute());
                      if (mounted) _loadExpenses();
                    },
                    icon: const Icon(Icons.add),
                    label: const Text('เพิ่มรายจ่าย'),
                  ),
                ],
              ),
            );
          }
          return RefreshIndicator(
            onRefresh: () async => _loadExpenses(),
            child: ListView.builder(
              itemCount: state.expenses.length,
              itemBuilder: (ctx, i) => _ExpenseCard(
                expense: state.expenses[i],
                onDeleted: _loadExpenses,
              ),
            ),
          );
        },
      ),
    );
  }
}

class _ExpenseCard extends StatelessWidget {
  final Expense expense;
  final VoidCallback onDeleted;
  const _ExpenseCard({required this.expense, required this.onDeleted});

  @override
  Widget build(BuildContext context) {
    final fmt = NumberFormat('#,##0.00', 'th_TH');
    final dateFmt = DateFormat('dd MMM yy', 'th');

    return Dismissible(
      key: Key('expense_${expense.id}'),
      direction: DismissDirection.endToStart,
      background: Container(
        color: Colors.red,
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.symmetric(horizontal: 20),
        child: const Icon(Icons.delete, color: Colors.white),
      ),
      confirmDismiss: (_) => showDialog<bool>(
        context: context,
        builder: (_) => AlertDialog(
          title: const Text('ลบรายการ?'),
          content: Text('ต้องการลบ "${expense.title}" ใช่ไหม?'),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('ยกเลิก')),
            FilledButton(
                onPressed: () => Navigator.pop(context, true),
                child: const Text('ลบ')),
          ],
        ),
      ),
      onDismissed: (_) {
        context.read<ExpenseBloc>().add(DeleteExpenseEvent(expense.id!));
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('ลบรายการแล้ว'),
            action: SnackBarAction(
              label: 'ตกลง',
              onPressed: () {},
            ),
          ),
        );
      },
      child: InkWell(
        onTap: () async {
          await context.router.push(AddEditExpenseRoute(expense: expense));
          // โหลดใหม่หลังแก้ไข
          if (context.mounted) onDeleted();
        },
        child: Card(
          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
          child: ListTile(
            leading: Hero(
              tag: 'expense_icon_${expense.id}',
              child: CircleAvatar(
                backgroundColor:
                Theme.of(context).colorScheme.primaryContainer,
                child: Text(_categoryEmoji(expense.category)),
              ),
            ),
            title: Text(expense.title,
                maxLines: 1, overflow: TextOverflow.ellipsis),
            subtitle:
            Text('${expense.storeName} • ${dateFmt.format(expense.date)}'),
            trailing: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  '฿${fmt.format(expense.amount)}',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Theme.of(context).colorScheme.error,
                  ),
                ),
                Chip(
                  label: Text(expense.category,
                      style: const TextStyle(fontSize: 10)),
                  padding: EdgeInsets.zero,
                  visualDensity: VisualDensity.compact,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  String _categoryEmoji(String cat) {
    const map = {
      'อาหาร': '🍜', 'เดินทาง': '🚗', 'ช้อปปิ้ง': '🛍️',
      'สุขภาพ': '💊', 'บันเทิง': '🎮', 'ที่อยู่อาศัย': '🏠',
      'การศึกษา': '📚', 'อื่นๆ': '📦',
    };
    return map[cat] ?? '💰';
  }
}