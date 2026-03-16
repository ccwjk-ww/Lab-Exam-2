import 'package:auto_route/auto_route.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';

import '../../blocs/expense/expense_bloc.dart';
import '../../router/app_router.dart';

// ─── Route Observer (Singleton) ───────────────────────────────────────────────
// ต้อง register ใน app.dart:
//   routerDelegate: _router.delegate(
//     navigatorObservers: () => [AppRouteObserver.instance],
//   ),
class AppRouteObserver {
  static final RouteObserver<ModalRoute<void>> instance =
  RouteObserver<ModalRoute<void>>();
}

// ─── Dashboard Page ───────────────────────────────────────────────────────────
@RoutePage()
class DashboardPage extends StatefulWidget {
  const DashboardPage({super.key});

  @override
  State<DashboardPage> createState() => _DashboardPageState();
}

class _DashboardPageState extends State<DashboardPage>
    with SingleTickerProviderStateMixin, RouteAware {
  late final AnimationController _fabController;
  late final Animation<double> _fabAnimation;

  @override
  void initState() {
    super.initState();
    _fabController = AnimationController(
      vsync: this, // ถูกต้อง: this มาจาก SingleTickerProviderStateMixin
      duration: const Duration(milliseconds: 500),
    );
    _fabAnimation = CurvedAnimation(
      parent: _fabController,
      curve: Curves.elasticOut,
    );
    _fabController.forward();
    _loadData();
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
    _fabController.dispose();
    super.dispose();
  }

  /// เรียกเมื่อ pop route ด้านบน (เช่น กลับจาก AddEdit หรือ ScanReceipt)
  @override
  void didPopNext() {
    _loadData();
  }

  void _loadData() {
    final now = DateTime.now();
    context.read<ExpenseBloc>().add(LoadSummaryEvent(
      from: DateTime(now.year, now.month, 1),
      to: now,
    ));
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('💰 AI Expense Tracker'),
        backgroundColor: theme.colorScheme.primaryContainer,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'รีเฟรช',
            onPressed: _loadData,
          ),
          IconButton(
            icon: const Icon(Icons.settings),
            onPressed: () => context.router.push(const SettingsRoute()),
          ),
          IconButton(
            icon: const Icon(Icons.auto_awesome),
            onPressed: () => context.router.push(const AiInsightsRoute()),
          )
        ],
      ),
      body: BlocBuilder<ExpenseBloc, ExpenseState>(
        // rebuild เฉพาะเมื่อ summary / loading เปลี่ยน
        // ไม่ rebuild จาก AI state ของ ScanReceipt
        buildWhen: (prev, curr) =>
        prev.isSummaryLoading != curr.isSummaryLoading ||
            prev.summary != curr.summary ||
            prev.errorMessage != curr.errorMessage,
        builder: (context, state) {
          if (state.isSummaryLoading) {
            return const Center(child: CircularProgressIndicator());
          }

          if (state.errorMessage != null && state.summary == null) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.error_outline, size: 48, color: Colors.red),
                  const SizedBox(height: 12),
                  Text('เกิดข้อผิดพลาด: ${state.errorMessage}'),
                  const SizedBox(height: 16),
                  FilledButton.icon(
                    onPressed: _loadData,
                    icon: const Icon(Icons.refresh),
                    label: const Text('ลองใหม่'),
                  ),
                ],
              ),
            );
          }

          if (state.summary != null) {
            return _buildDashboard(context, state);
          }

          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Text('ยังไม่มีข้อมูลรายจ่าย',
                    style: TextStyle(fontSize: 16)),
                const SizedBox(height: 16),
                FilledButton.icon(
                  onPressed: _loadData,
                  icon: const Icon(Icons.refresh),
                  label: const Text('โหลดข้อมูล'),
                ),
              ],
            ),
          );
        },
      ),
      floatingActionButton: ScaleTransition(
        scale: _fabAnimation,
        child: FloatingActionButton.extended(
          onPressed: () => context.router.push(const ScanReceiptRoute()),
          icon: const Icon(Icons.document_scanner),
          label: const Text('สแกนใบเสร็จ'),
        ),
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: 0,
        destinations: const [
          NavigationDestination(
              icon: Icon(Icons.dashboard), label: 'Dashboard'),
          NavigationDestination(icon: Icon(Icons.list), label: 'รายการ'),
          NavigationDestination(
              icon: Icon(Icons.add_circle_outline), label: 'เพิ่ม'),
        ],
        onDestinationSelected: (index) async {
          if (index == 1) {
            await context.router.push(const ExpenseListRoute());
            if (mounted) _loadData();
          }
          if (index == 2) {
            await context.router.push(AddEditExpenseRoute());
            if (mounted) _loadData();
          }
        },
      ),
    );
  }

  Widget _buildDashboard(BuildContext context, ExpenseState state) {
    final summary = state.summary!;
    final fmt = NumberFormat('#,##0.00', 'th_TH');

    return RefreshIndicator(
      onRefresh: () async => _loadData(),
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _TotalCard(total: summary.totalAmount, count: summary.totalCount),
            const SizedBox(height: 20),
            Text('รายจ่ายตามหมวดหมู่',
                style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 12),
            if (summary.categoryTotals.isNotEmpty) ...[
              SizedBox(
                height: 220,
                child: PieChart(
                  PieChartData(
                    sections: _buildPieSections(summary.categoryTotals),
                    centerSpaceRadius: 50,
                    sectionsSpace: 3,
                  ),
                ),
              ),
              const SizedBox(height: 20),
              ...summary.categoryTotals.entries.map((e) => ListTile(
                leading: CircleAvatar(child: Text(_categoryEmoji(e.key))),
                title: Text(e.key),
                trailing: Text(
                  '฿${fmt.format(e.value)}',
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
              )),
            ] else
              const Center(
                child: Padding(
                  padding: EdgeInsets.all(32),
                  child: Text('ยังไม่มีรายจ่ายในเดือนนี้'),
                ),
              ),
          ],
        ),
      ),
    );
  }

  List<PieChartSectionData> _buildPieSections(Map<String, double> data) {
    const colors = [
      Colors.blue, Colors.orange, Colors.green, Colors.purple,
      Colors.red, Colors.teal, Colors.amber, Colors.indigo,
    ];
    final entries = data.entries.toList();
    final total = data.values.fold(0.0, (a, b) => a + b);

    return List.generate(entries.length, (i) {
      final pct = (entries[i].value / total * 100).toStringAsFixed(1);
      return PieChartSectionData(
        value: entries[i].value,
        title: '$pct%',
        color: colors[i % colors.length],
        radius: 80,
        titleStyle: const TextStyle(
            color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold),
      );
    });
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

// ─── Animated Total Card ──────────────────────────────────────────────────────
class _TotalCard extends StatefulWidget {
  final double total;
  final int count;
  const _TotalCard({required this.total, required this.count});

  @override
  State<_TotalCard> createState() => _TotalCardState();
}

class _TotalCardState extends State<_TotalCard> {
  bool _expanded = false;

  @override
  void initState() {
    super.initState();
    Future.delayed(const Duration(milliseconds: 200), () {
      if (mounted) setState(() => _expanded = true);
    });
  }

  @override
  Widget build(BuildContext context) {
    final fmt = NumberFormat('#,##0.00', 'th_TH');
    return AnimatedContainer(
      duration: const Duration(milliseconds: 600),
      curve: Curves.easeOutCubic,
      height: _expanded ? 130 : 60,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            Theme.of(context).colorScheme.primary,
            Theme.of(context).colorScheme.secondary,
          ],
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.3),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      child: AnimatedOpacity(
        opacity: _expanded ? 1.0 : 0.0,
        duration: const Duration(milliseconds: 400),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('รายจ่ายเดือนนี้',
                style: TextStyle(color: Colors.white70, fontSize: 13)),
            const SizedBox(height: 4),
            Text(
              '฿${fmt.format(widget.total)}',
              style: const TextStyle(
                  color: Colors.white,
                  fontSize: 26,
                  fontWeight: FontWeight.bold),
            ),
            Text('${widget.count} รายการ',
                style: const TextStyle(color: Colors.white70, fontSize: 12)),
          ],
        ),
      ),
    );
  }
}