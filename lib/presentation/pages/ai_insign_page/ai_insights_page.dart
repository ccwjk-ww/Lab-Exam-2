import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';

import '../../../data/datasources/remote/gemini_datasource.dart';
import '../../blocs/expense/expense_bloc.dart';

@RoutePage()
class AiInsightsPage extends StatefulWidget {
  const AiInsightsPage({super.key});

  @override
  State<AiInsightsPage> createState() => _AiInsightsPageState();
}

class _AiInsightsPageState extends State<AiInsightsPage>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  late DateTime _from;
  late DateTime _to;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    final now = DateTime.now();
    _from = DateTime(now.year, now.month, 1);
    _to = now;
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  void _runAnalysis() {
    context
        .read<ExpenseBloc>()
        .add(AnalyzeSpendingEvent(from: _from, to: _to));
  }

  void _runBudget() {
    context
        .read<ExpenseBloc>()
        .add(GenerateBudgetAdviceEvent(from: _from, to: _to));
  }

  void _runAnomalies() {
    context
        .read<ExpenseBloc>()
        .add(DetectAnomaliesEvent(from: _from, to: _to));
  }

  Future<void> _pickDateRange() async {
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2023),
      lastDate: DateTime.now(),
      initialDateRange: DateTimeRange(start: _from, end: _to),
      helpText: 'เลือกช่วงเวลาที่ต้องการวิเคราะห์',
    );
    if (picked != null) {
      setState(() {
        _from = picked.start;
        _to = picked.end;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final dateFmt = DateFormat('d MMM yy', 'th');

    return Scaffold(
      appBar: AppBar(
        title: const Text('🧠 AI Insights'),
        actions: [
          TextButton.icon(
            onPressed: _pickDateRange,
            icon: const Icon(Icons.date_range, size: 18),
            label: Text(
              '${dateFmt.format(_from)} – ${dateFmt.format(_to)}',
              style: const TextStyle(fontSize: 12),
            ),
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(icon: Icon(Icons.insights, size: 18), text: 'วิเคราะห์'),
            Tab(
                icon: Icon(Icons.account_balance_wallet, size: 18),
                text: 'งบประมาณ'),
            Tab(icon: Icon(Icons.warning_amber, size: 18), text: 'ผิดปกติ'),
          ],
        ),
      ),
      // ✅ ลบ buildWhen ออก → ให้ rebuild ทุกครั้งที่ state เปลี่ยน
      // buildWhen ที่เดิมกรองออกทำให้ Tab ไม่ได้รับ state ใหม่
      body: BlocConsumer<ExpenseBloc, ExpenseState>(
        // แสดง error ผ่าน SnackBar
        listenWhen: (prev, curr) =>
        prev.errorMessage != curr.errorMessage &&
            curr.errorMessage != null,
        listener: (context, state) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(state.errorMessage!),
              backgroundColor: Colors.red,
            ),
          );
        },
        builder: (context, state) {
          return TabBarView(
            controller: _tabController,
            children: [
              _SpendingAnalysisTab(state: state, onAnalyze: _runAnalysis),
              _BudgetAdviceTab(state: state, onGenerate: _runBudget),
              _AnomalyTab(state: state, onDetect: _runAnomalies),
            ],
          );
        },
      ),
    );
  }
}

// ─── Tab 1: Spending Analysis ─────────────────────────────────────────────────

class _SpendingAnalysisTab extends StatelessWidget {
  final ExpenseState state;
  final VoidCallback onAnalyze;

  const _SpendingAnalysisTab(
      {required this.state, required this.onAnalyze});

  @override
  Widget build(BuildContext context) {
    // ✅ loading: isAnalysisLoading = true และยังไม่มีผลเก่า
    if (state.isAnalysisLoading && state.spendingAnalysis == null) {
      return _buildLoading('กำลังวิเคราะห์พฤติกรรมการใช้จ่าย...');
    }

    // ✅ ยังไม่เคยกด
    if (state.spendingAnalysis == null) {
      return _buildEmpty(
        context,
        icon: Icons.insights,
        title: 'วิเคราะห์พฤติกรรมการใช้จ่าย',
        subtitle:
        'AI จะวิเคราะห์รูปแบบการใช้จ่ายของคุณ\nและให้คำแนะนำที่เหมาะสม',
        buttonLabel: '🧠 เริ่มวิเคราะห์',
        onTap: onAnalyze,
      );
    }

    // ✅ มีผลแล้ว → แสดง (ถ้า loading ซ้ำให้แสดง overlay แทน)
    final analysis = state.spendingAnalysis!;
    return Stack(
      children: [
        RefreshIndicator(
          onRefresh: () async => onAnalyze(),
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _AiCard(
                  icon: '📊',
                  title: 'ภาพรวม',
                  color: Theme.of(context).colorScheme.primaryContainer,
                  child: Text(analysis.overview,
                      style: const TextStyle(height: 1.5)),
                ),
                const SizedBox(height: 12),
                if (analysis.insights.isNotEmpty)
                  _AiCard(
                    icon: '💡',
                    title: 'สิ่งที่น่าสนใจ',
                    color: Theme.of(context).colorScheme.secondaryContainer,
                    child: Column(
                      children: analysis.insights
                          .map((s) => _BulletItem(
                          text: s, icon: Icons.lightbulb_outline))
                          .toList(),
                    ),
                  ),
                const SizedBox(height: 12),
                if (analysis.warnings.isNotEmpty)
                  _AiCard(
                    icon: '⚠️',
                    title: 'สิ่งที่ควรระวัง',
                    color: Theme.of(context).colorScheme.errorContainer,
                    child: Column(
                      children: analysis.warnings
                          .map((s) => _BulletItem(
                        text: s,
                        icon: Icons.warning_amber_outlined,
                        color: Theme.of(context).colorScheme.error,
                      ))
                          .toList(),
                    ),
                  ),
                const SizedBox(height: 12),
                if (analysis.suggestions.isNotEmpty)
                  _AiCard(
                    icon: '✅',
                    title: 'คำแนะนำ',
                    color: Theme.of(context).colorScheme.tertiaryContainer,
                    child: Column(
                      children: analysis.suggestions
                          .map((s) => _BulletItem(
                        text: s,
                        icon: Icons.check_circle_outline,
                        color: Colors.green.shade700,
                      ))
                          .toList(),
                    ),
                  ),
                const SizedBox(height: 16),
                OutlinedButton.icon(
                  onPressed: state.isAnalysisLoading ? null : onAnalyze,
                  icon: const Icon(Icons.refresh, size: 18),
                  label: const Text('วิเคราะห์ใหม่'),
                ),
              ],
            ),
          ),
        ),
        // overlay loading เมื่อ refresh
        if (state.isAnalysisLoading)
          const Positioned(
            top: 12,
            left: 0,
            right: 0,
            child: Center(
              child: Card(
                child: Padding(
                  padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2)),
                      SizedBox(width: 10),
                      Text('กำลังวิเคราะห์ใหม่...', style: TextStyle(fontSize: 13)),
                    ],
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}

// ─── Tab 2: Budget Advice ─────────────────────────────────────────────────────

class _BudgetAdviceTab extends StatelessWidget {
  final ExpenseState state;
  final VoidCallback onGenerate;

  const _BudgetAdviceTab(
      {required this.state, required this.onGenerate});

  @override
  Widget build(BuildContext context) {
    final fmt = NumberFormat('#,##0', 'th_TH');

    if (state.isAnalysisLoading && state.budgetAdvice == null) {
      return _buildLoading('กำลังวางแผนงบประมาณ...');
    }

    if (state.budgetAdvice == null) {
      return _buildEmpty(
        context,
        icon: Icons.account_balance_wallet,
        title: 'วางแผนงบประมาณ',
        subtitle: 'AI จะแนะนำงบประมาณที่เหมาะสม\nสำหรับแต่ละหมวดหมู่',
        buttonLabel: '💰 วางแผนงบประมาณ',
        onTap: onGenerate,
      );
    }

    final advice = state.budgetAdvice!;
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  Theme.of(context).colorScheme.primary,
                  Theme.of(context).colorScheme.secondary,
                ],
              ),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Column(
              children: [
                const Text('งบประมาณรายเดือนที่แนะนำ',
                    style: TextStyle(color: Colors.white70, fontSize: 13)),
                const SizedBox(height: 4),
                Text(
                  '฿${fmt.format(advice.recommendedMonthlyBudget)}',
                  style: const TextStyle(
                      color: Colors.white,
                      fontSize: 32,
                      fontWeight: FontWeight.bold),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          _AiCard(
            icon: '📋',
            title: 'งบประมาณแต่ละหมวดหมู่',
            color: Theme.of(context).colorScheme.primaryContainer,
            child: Column(
              children: advice.categoryBudgets.entries
                  .where((e) => e.value > 0)
                  .map((entry) => Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Row(
                  children: [
                    Text(_categoryEmoji(entry.key),
                        style: const TextStyle(fontSize: 16)),
                    const SizedBox(width: 8),
                    Expanded(child: Text(entry.key)),
                    Text(
                      '฿${fmt.format(entry.value)}',
                      style: const TextStyle(
                          fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
              ))
                  .toList(),
            ),
          ),
          const SizedBox(height: 12),
          _AiCard(
            icon: '🤔',
            title: 'เหตุผล',
            color: Theme.of(context).colorScheme.secondaryContainer,
            child:
            Text(advice.reasoning, style: const TextStyle(height: 1.5)),
          ),
          const SizedBox(height: 12),
          if (advice.tips.isNotEmpty)
            _AiCard(
              icon: '💡',
              title: 'เคล็ดลับประหยัด',
              color: Theme.of(context).colorScheme.tertiaryContainer,
              child: Column(
                children: advice.tips
                    .map((t) => _BulletItem(
                  text: t,
                  icon: Icons.savings_outlined,
                  color: Colors.green.shade700,
                ))
                    .toList(),
              ),
            ),
          const SizedBox(height: 16),
          OutlinedButton.icon(
            onPressed: state.isAnalysisLoading ? null : onGenerate,
            icon: const Icon(Icons.refresh, size: 18),
            label: const Text('วางแผนใหม่'),
          ),
        ],
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

// ─── Tab 3: Anomaly Detection ─────────────────────────────────────────────────

class _AnomalyTab extends StatelessWidget {
  final ExpenseState state;
  final VoidCallback onDetect;

  const _AnomalyTab({required this.state, required this.onDetect});

  @override
  Widget build(BuildContext context) {
    if (state.isAnalysisLoading && state.anomalyResult == null) {
      return _buildLoading('กำลังตรวจสอบรายจ่ายผิดปกติ...');
    }

    if (state.anomalyResult == null) {
      return _buildEmpty(
        context,
        icon: Icons.security,
        title: 'ตรวจสอบรายจ่ายผิดปกติ',
        subtitle:
        'AI จะตรวจหารายจ่ายซ้ำ, จำนวนสูงผิดปกติ\nหรือหมวดหมู่ที่ดูแปลก',
        buttonLabel: '🔍 เริ่มตรวจสอบ',
        onTap: onDetect,
      );
    }

    final result = state.anomalyResult!;
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: result.anomalies.isEmpty
                  ? Colors.green.shade100
                  : Theme.of(context).colorScheme.errorContainer,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                Icon(
                  result.anomalies.isEmpty
                      ? Icons.check_circle
                      : Icons.warning,
                  color: result.anomalies.isEmpty
                      ? Colors.green.shade700
                      : Theme.of(context).colorScheme.error,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    result.summary,
                    style: TextStyle(
                      color: result.anomalies.isEmpty
                          ? Colors.green.shade900
                          : Theme.of(context).colorScheme.onErrorContainer,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          if (result.anomalies.isNotEmpty) ...[
            Text('รายการที่พบ (${result.anomalies.length} รายการ)',
                style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            ...result.anomalies.map((a) => _AnomalyCard(anomaly: a)),
          ],
          const SizedBox(height: 16),
          OutlinedButton.icon(
            onPressed: state.isAnalysisLoading ? null : onDetect,
            icon: const Icon(Icons.refresh, size: 18),
            label: const Text('ตรวจสอบใหม่'),
          ),
        ],
      ),
    );
  }
}

// ─── Anomaly Card ─────────────────────────────────────────────────────────────

class _AnomalyCard extends StatelessWidget {
  final ExpenseAnomaly anomaly;
  const _AnomalyCard({required this.anomaly});

  @override
  Widget build(BuildContext context) {
    final severityColor = switch (anomaly.severity) {
      'high' => Colors.red.shade100,
      'medium' => Colors.orange.shade100,
      _ => Colors.yellow.shade100,
    };
    final severityIcon = switch (anomaly.severity) {
      'high' => Icons.error,
      'medium' => Icons.warning_amber,
      _ => Icons.info_outline,
    };
    final severityIconColor = switch (anomaly.severity) {
      'high' => Colors.red.shade700,
      'medium' => Colors.orange.shade700,
      _ => Colors.amber.shade700,
    };

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      color: severityColor,
      child: ListTile(
        leading: Icon(severityIcon, color: severityIconColor),
        title: Text(anomaly.description,
            style: const TextStyle(fontSize: 14)),
        subtitle: anomaly.relatedExpenseTitle != null
            ? Text('รายการ: ${anomaly.relatedExpenseTitle}',
            style: const TextStyle(fontSize: 12))
            : null,
        trailing: Chip(
          label: Text(_typeLabel(anomaly.type),
              style: const TextStyle(fontSize: 10)),
          visualDensity: VisualDensity.compact,
          padding: EdgeInsets.zero,
        ),
      ),
    );
  }

  String _typeLabel(String type) => switch (type) {
    'duplicate' => 'ซ้ำ',
    'high_amount' => 'สูงเกิน',
    'unusual_category' => 'หมวดแปลก',
    _ => type,
  };
}

// ─── Shared Widgets ───────────────────────────────────────────────────────────

class _AiCard extends StatelessWidget {
  final String icon;
  final String title;
  final Color color;
  final Widget child;

  const _AiCard({
    required this.icon,
    required this.title,
    required this.color,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(icon, style: const TextStyle(fontSize: 18)),
              const SizedBox(width: 6),
              Text(title,
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                  )),
            ],
          ),
          const SizedBox(height: 10),
          child,
        ],
      ),
    );
  }
}

class _BulletItem extends StatelessWidget {
  final String text;
  final IconData icon;
  final Color? color;

  const _BulletItem({required this.text, required this.icon, this.color});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon,
              size: 16,
              color: color ?? Theme.of(context).colorScheme.primary),
          const SizedBox(width: 8),
          Expanded(
            child: Text(text,
                style: const TextStyle(height: 1.4, fontSize: 13)),
          ),
        ],
      ),
    );
  }
}

Widget _buildLoading(String message) {
  return Center(
    child: Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const CircularProgressIndicator(),
        const SizedBox(height: 16),
        Text(message, style: const TextStyle(fontSize: 14)),
        const SizedBox(height: 8),
        const Text('อาจใช้เวลา 5–15 วินาที',
            style: TextStyle(fontSize: 12, color: Colors.grey)),
      ],
    ),
  );
}

Widget _buildEmpty(
    BuildContext context, {
      required IconData icon,
      required String title,
      required String subtitle,
      required String buttonLabel,
      required VoidCallback onTap,
    }) {
  return Center(
    child: Padding(
      padding: const EdgeInsets.all(32),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 64, color: Theme.of(context).colorScheme.primary),
          const SizedBox(height: 16),
          Text(title,
              style: Theme.of(context).textTheme.titleLarge,
              textAlign: TextAlign.center),
          const SizedBox(height: 8),
          Text(subtitle,
              style: const TextStyle(color: Colors.grey),
              textAlign: TextAlign.center),
          const SizedBox(height: 24),
          FilledButton.icon(
            onPressed: onTap,
            icon: const Icon(Icons.auto_awesome),
            label: Text(buttonLabel),
          ),
        ],
      ),
    ),
  );
}