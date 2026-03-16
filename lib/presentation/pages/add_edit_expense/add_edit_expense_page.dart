import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';

import '../../../domain/entities/expense.dart';
import '../../blocs/expense/expense_bloc.dart';

@RoutePage()
class AddEditExpensePage extends StatefulWidget {
  final Expense? expense;
  final String? initialOcrText;
  final String? initialCategory;
  final String? initialSummary;

  const AddEditExpensePage({
    super.key,
    this.expense,
    this.initialOcrText,
    this.initialCategory,
    this.initialSummary,
  });

  @override
  State<AddEditExpensePage> createState() => _AddEditExpensePageState();
}

class _AddEditExpensePageState extends State<AddEditExpensePage> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _titleCtrl;
  late final TextEditingController _storeCtrl;
  late final TextEditingController _amountCtrl;
  late final TextEditingController _ocrCtrl;
  late String _selectedCategory;
  late DateTime _selectedDate;

  final List<String> _categories = [
    'อาหาร', 'เดินทาง', 'ช้อปปิ้ง', 'สุขภาพ',
    'บันเทิง', 'ที่อยู่อาศัย', 'การศึกษา', 'อื่นๆ',
  ];

  bool get _isEditMode => widget.expense != null;
  // ป้องกัน submit ซ้ำ
  bool _submitted = false;

  @override
  void initState() {
    super.initState();
    final e = widget.expense;
    _titleCtrl = TextEditingController(
        text: e?.title ?? widget.initialSummary ?? '');
    _storeCtrl = TextEditingController(text: e?.storeName ?? '');
    _amountCtrl = TextEditingController(
        text: e != null ? e.amount.toStringAsFixed(2) : '');
    _ocrCtrl = TextEditingController(
        text: e?.rawOcrText ?? widget.initialOcrText ?? '');
    _selectedCategory =
        e?.category ?? widget.initialCategory ?? 'อาหาร';
    _selectedDate = e?.date ?? DateTime.now();
  }

  @override
  void dispose() {
    _titleCtrl.dispose();
    _storeCtrl.dispose();
    _amountCtrl.dispose();
    _ocrCtrl.dispose();
    super.dispose();
  }

  void _submit() {
    if (_submitted) return;
    if (!_formKey.currentState!.validate()) return;

    final expense = Expense(
      id: widget.expense?.id,
      title: _titleCtrl.text.trim(),
      storeName: _storeCtrl.text.trim(),
      amount: double.parse(_amountCtrl.text),
      category: _selectedCategory,
      date: _selectedDate,
      rawOcrText: _ocrCtrl.text.trim().isEmpty ? null : _ocrCtrl.text.trim(),
      aiSummary: widget.initialSummary,
    );

    setState(() => _submitted = true);

    if (_isEditMode) {
      context.read<ExpenseBloc>().add(UpdateExpenseEvent(expense));
    } else {
      context.read<ExpenseBloc>().add(SaveExpenseEvent(expense));
    }
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
    );
    if (picked != null) setState(() => _selectedDate = picked);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_isEditMode ? 'แก้ไขรายจ่าย' : 'เพิ่มรายจ่าย'),
      ),
      body: BlocListener<ExpenseBloc, ExpenseState>(
        listenWhen: (prev, curr) =>
        prev.lastSavedId != curr.lastSavedId ||
            prev.errorMessage != curr.errorMessage,
        listener: (context, state) {
          // บันทึกสำเร็จ
          if (state.lastSavedId != null) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('บันทึกสำเร็จ ✅'),
                backgroundColor: Colors.green,
              ),
            );
            context.router.maybePop();
          }
          // เกิด error → reset ให้ submit ใหม่ได้
          if (state.errorMessage != null) {
            setState(() => _submitted = false);
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                  content: Text(state.errorMessage!),
                  backgroundColor: Colors.red),
            );
          }
        },
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Title
                TextFormField(
                  controller: _titleCtrl,
                  decoration: const InputDecoration(
                    labelText: 'ชื่อรายการ *',
                    prefixIcon: Icon(Icons.title),
                    border: OutlineInputBorder(),
                  ),
                  validator: (v) {
                    if (v == null || v.trim().isEmpty) return 'กรุณากรอกชื่อรายการ';
                    if (v.trim().length < 2) return 'ชื่อต้องมีอย่างน้อย 2 ตัวอักษร';
                    return null;
                  },
                ),
                const SizedBox(height: 16),

                // Store
                TextFormField(
                  controller: _storeCtrl,
                  decoration: const InputDecoration(
                    labelText: 'ชื่อร้าน *',
                    prefixIcon: Icon(Icons.store),
                    border: OutlineInputBorder(),
                  ),
                  validator: (v) =>
                  (v == null || v.trim().isEmpty) ? 'กรุณากรอกชื่อร้าน' : null,
                ),
                const SizedBox(height: 16),

                // Amount
                TextFormField(
                  controller: _amountCtrl,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  decoration: const InputDecoration(
                    labelText: 'จำนวนเงิน (บาท) *',
                    prefixIcon: Icon(Icons.attach_money),
                    border: OutlineInputBorder(),
                    prefixText: '฿ ',
                  ),
                  validator: (v) {
                    if (v == null || v.isEmpty) return 'กรุณากรอกจำนวนเงิน';
                    final amount = double.tryParse(v);
                    if (amount == null) return 'จำนวนเงินไม่ถูกต้อง';
                    if (amount <= 0) return 'จำนวนเงินต้องมากกว่า 0';
                    return null;
                  },
                ),
                const SizedBox(height: 16),

                // Category
                DropdownButtonFormField<String>(
                  value: _selectedCategory,
                  decoration: const InputDecoration(
                    labelText: 'หมวดหมู่',
                    prefixIcon: Icon(Icons.label),
                    border: OutlineInputBorder(),
                  ),
                  items: _categories
                      .map((c) => DropdownMenuItem(value: c, child: Text(c)))
                      .toList(),
                  onChanged: (v) => setState(() => _selectedCategory = v!),
                ),
                const SizedBox(height: 16),

                // Date
                InkWell(
                  onTap: _pickDate,
                  child: InputDecorator(
                    decoration: const InputDecoration(
                      labelText: 'วันที่',
                      prefixIcon: Icon(Icons.calendar_today),
                      border: OutlineInputBorder(),
                    ),
                    child: Text(
                        DateFormat('dd MMM yyyy', 'th').format(_selectedDate)),
                  ),
                ),
                const SizedBox(height: 16),

                // OCR text
                TextFormField(
                  controller: _ocrCtrl,
                  maxLines: 4,
                  decoration: const InputDecoration(
                    labelText: 'ข้อความจากใบเสร็จ (OCR) — ไม่บังคับ',
                    prefixIcon: Icon(Icons.text_snippet),
                    border: OutlineInputBorder(),
                  ),
                ),

                const SizedBox(height: 32),

                BlocBuilder<ExpenseBloc, ExpenseState>(
                  buildWhen: (prev, curr) =>
                  prev.isLoading != curr.isLoading,
                  builder: (context, state) => FilledButton.icon(
                    onPressed: (state.isLoading || _submitted) ? null : _submit,
                    icon: state.isLoading
                        ? const SizedBox(
                        height: 18,
                        width: 18,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: Colors.white))
                        : const Icon(Icons.save),
                    label: Text(_isEditMode ? 'อัปเดต' : 'บันทึก'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}