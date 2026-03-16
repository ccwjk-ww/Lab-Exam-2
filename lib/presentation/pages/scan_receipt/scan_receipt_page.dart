import 'dart:io';
import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:image_picker/image_picker.dart';

import '../../blocs/expense/expense_bloc.dart';
import '../../router/app_router.dart';

@RoutePage()
class ScanReceiptPage extends StatefulWidget {
  const ScanReceiptPage({super.key});

  @override
  State<ScanReceiptPage> createState() => _ScanReceiptPageState();
}

class _ScanReceiptPageState extends State<ScanReceiptPage> {
  XFile? _pickedFile;
  String _extractedText = '';
  bool _isProcessing = false;
  bool _isPickerOpen = false;

  final _picker = ImagePicker();
  final _manualController = TextEditingController();

  // ─── Simulator Detection ───────────────────────────────────────────────────
  // บน iOS Simulator ที่รันบน Mac:
  //   Platform.isIOS = true (simulator แสดงตัวเป็น iOS)
  //   แต่ HOME = /Users/<username>/... (path ของ Mac)
  // บน iPhone จริง:
  //   HOME = /var/mobile หรือ /private/var/mobile
  static bool? _simulatorCached;

  bool get _isSimulator {
    if (kIsWeb) return false;
    if (!Platform.isIOS) return false;
    if (_simulatorCached != null) return _simulatorCached!;
    try {
      final home = Platform.environment['HOME'] ?? '';
      _simulatorCached = home.startsWith('/Users/');
      return _simulatorCached!;
    } catch (_) {
      _simulatorCached = false;
      return false;
    }
  }

  bool get _supportsCamera {
    if (kIsWeb) return false;
    if (Platform.isAndroid) return true;
    if (Platform.isIOS) return !_isSimulator;
    return false;
  }

  @override
  void dispose() {
    _manualController.dispose();
    super.dispose();
  }

  // ─── Image Picking ─────────────────────────────────────────────────────────
  Future<void> _pickImage(ImageSource source) async {
    if (_isPickerOpen) return;
    setState(() => _isPickerOpen = true);

    try {
      final XFile? picked = await _picker.pickImage(
        source: source,
        imageQuality: 85,
        maxWidth: 1920,
        maxHeight: 1920,
      );

      if (!mounted) return;

      if (picked == null) {
        setState(() => _isPickerOpen = false);
        return;
      }

      setState(() {
        _pickedFile = picked;
        _isProcessing = true;
        _extractedText = '';
        _manualController.clear();
        _isPickerOpen = false;
      });

      await _runOcr(picked);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isProcessing = false;
        _isPickerOpen = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(_friendlyError(e.toString())),
          backgroundColor: Colors.red.shade700,
          duration: const Duration(seconds: 4),
        ),
      );
    }
  }

  String _friendlyError(String raw) {
    final s = raw.toLowerCase();
    if (s.contains('permission') || s.contains('denied')) {
      return 'ไม่ได้รับอนุญาต — ไปที่ Settings > Privacy > Photos แล้วอนุญาตแอป';
    }
    if (s.contains('camera') || s.contains('not available')) {
      return 'กล้องไม่รองรับบน Simulator — ใช้ iPhone จริงหรือเลือกจาก Gallery';
    }
    return 'เกิดข้อผิดพลาด: $raw';
  }

  Future<void> _runOcr(XFile imageFile) async {
    // TODO: เพิ่ม ML Kit ตรงนี้
    await Future.delayed(const Duration(milliseconds: 300));
    if (!mounted) return;
    setState(() => _isProcessing = false);
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('📷 โหลดรูปสำเร็จ — กรุณากรอกข้อความจากใบเสร็จด้านล่าง'),
        duration: Duration(seconds: 3),
      ),
    );
  }

  void _useManualText() {
    final text = _manualController.text.trim();
    if (text.isEmpty) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('กรุณากรอกข้อความก่อน')));
      return;
    }
    setState(() => _extractedText = text);
  }

  void _categorizeWithAi() {
    if (_extractedText.isEmpty) return;
    context.read<ExpenseBloc>().add(CategorizeWithAiEvent(_extractedText));
  }

  void _summarizeWithAi() {
    if (_extractedText.isEmpty) return;
    context.read<ExpenseBloc>().add(SummarizeWithAiEvent(_extractedText));
  }

  void _goToAddExpense(ExpenseState state) {
    context.router.push(AddEditExpenseRoute(
      initialOcrText: _extractedText.isNotEmpty ? _extractedText : null,
      initialCategory: state.aiCategory,
      initialSummary: state.aiSummary,
    ));
  }

  // ─── Build ─────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('📷 สแกนใบเสร็จ')),
      body: SafeArea(
        child: BlocConsumer<ExpenseBloc, ExpenseState>(
          listenWhen: (prev, curr) =>
          prev.errorMessage != curr.errorMessage ||
              prev.aiCategory != curr.aiCategory ||
              prev.aiSummary != curr.aiSummary,
          listener: (context, state) {
            if (state.errorMessage != null) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                    content: Text(state.errorMessage!),
                    backgroundColor: Colors.red),
              );
            }
          },
          builder: (context, state) {
            return SingleChildScrollView(
              keyboardDismissBehavior:
              ScrollViewKeyboardDismissBehavior.onDrag,
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // ── Simulator banner ──────────────────────────────────
                  if (_isSimulator) _buildSimulatorBanner(context),

                  // ── Image preview ─────────────────────────────────────
                  _buildImagePreview(context),
                  const SizedBox(height: 14),

                  // ── Buttons ───────────────────────────────────────────
                  _buildPickButtons(),

                  // ── Processing ────────────────────────────────────────
                  if (_isProcessing) _buildProcessing(),

                  // ── Manual text input ─────────────────────────────────
                  if (_pickedFile != null && !_isProcessing) ...[
                    const SizedBox(height: 16),
                    _buildManualInput(context),
                  ],

                  // ── AI section ────────────────────────────────────────
                  if (_extractedText.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    _buildAiSection(context, state),
                  ],
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  // ─── Widgets ───────────────────────────────────────────────────────────────

  Widget _buildSimulatorBanner(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.tertiaryContainer,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: [
          Icon(Icons.info_outline,
              size: 18,
              color: Theme.of(context).colorScheme.onTertiaryContainer),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              'iOS Simulator: กล้องไม่รองรับ — ใช้ปุ่ม "แกลเลอรี" แทน',
              style: TextStyle(
                fontSize: 12,
                color: Theme.of(context).colorScheme.onTertiaryContainer,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildImagePreview(BuildContext context) {
    return ConstrainedBox(
      constraints: const BoxConstraints(minHeight: 150, maxHeight: 230),
      child: Container(
        width: double.infinity,
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Theme.of(context).colorScheme.outline),
        ),
        clipBehavior: Clip.hardEdge,
        child: _pickedFile != null
            ? Image.file(
          File(_pickedFile!.path),
          fit: BoxFit.cover,
          errorBuilder: (_, __, ___) => Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.broken_image,
                    size: 48, color: Colors.grey),
                const SizedBox(height: 6),
                Text('ไม่สามารถแสดงรูปได้',
                    style: TextStyle(color: Colors.grey.shade600)),
              ],
            ),
          ),
        )
            : Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.receipt_long,
                  size: 56,
                  color: Theme.of(context).colorScheme.primary),
              const SizedBox(height: 8),
              Text(
                'เลือกรูปใบเสร็จ',
                style: TextStyle(
                    color: Theme.of(context)
                        .colorScheme
                        .onSurfaceVariant),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPickButtons() {
    return Row(
      children: [
        if (_supportsCamera) ...[
          Expanded(
            child: FilledButton.icon(
              onPressed: _isPickerOpen
                  ? null
                  : () => _pickImage(ImageSource.camera),
              icon: const Icon(Icons.camera_alt, size: 18),
              label: const Text('ถ่ายรูป'),
            ),
          ),
          const SizedBox(width: 12),
        ],
        Expanded(
          child: OutlinedButton.icon(
            onPressed: _isPickerOpen
                ? null
                : () => _pickImage(ImageSource.gallery),
            icon: _isPickerOpen
                ? const SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
                : const Icon(Icons.photo_library, size: 18),
            label: Text(_isPickerOpen ? 'กำลังเปิด...' : 'แกลเลอรี'),
          ),
        ),
      ],
    );
  }

  Widget _buildProcessing() {
    return const Padding(
      padding: EdgeInsets.symmetric(vertical: 20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          CircularProgressIndicator(),
          SizedBox(height: 10),
          Text('กำลังประมวลผล...', style: TextStyle(fontSize: 13)),
        ],
      ),
    );
  }

  Widget _buildManualInput(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text('กรอกข้อความจากใบเสร็จ:',
            style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 8),
        TextField(
          controller: _manualController,
          maxLines: 4,
          minLines: 3,
          textInputAction: TextInputAction.newline,
          decoration: InputDecoration(
            hintText: 'พิมพ์หรือวางข้อความจากใบเสร็จที่นี่...',
            border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12)),
            filled: true,
            contentPadding:
            const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          ),
        ),
        const SizedBox(height: 8),
        OutlinedButton.icon(
          onPressed: _useManualText,
          icon: const Icon(Icons.check, size: 18),
          label: const Text('ใช้ข้อความนี้'),
        ),
      ],
    );
  }

  Widget _buildAiSection(BuildContext context, ExpenseState state) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        const Divider(),
        const SizedBox(height: 6),
        Text('ข้อความที่ใช้:', style: Theme.of(context).textTheme.titleSmall),
        const SizedBox(height: 6),
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Text(
            _extractedText,
            maxLines: 6,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontSize: 12, fontFamily: 'monospace'),
          ),
        ),
        const SizedBox(height: 12),

        // AI Buttons
        Row(
          children: [
            Expanded(
              child: FilledButton.tonal(
                onPressed: state.isAiLoading ? null : _categorizeWithAi,
                child: state.isAiLoading
                    ? const SizedBox(
                  height: 16,
                  width: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
                    : const Text('🤖 จัดหมวดหมู่'),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: FilledButton.tonal(
                onPressed: state.isAiLoading ? null : _summarizeWithAi,
                child: const Text('✨ สรุปด้วย AI'),
              ),
            ),
          ],
        ),

        if (state.aiCategory != null) ...[
          const SizedBox(height: 10),
          Wrap(
            children: [
              Chip(
                label: Text('หมวดหมู่: ${state.aiCategory}',
                    style: const TextStyle(fontSize: 13)),
                avatar: const Icon(Icons.label, size: 16),
                backgroundColor:
                Theme.of(context).colorScheme.primaryContainer,
                visualDensity: VisualDensity.compact,
              ),
            ],
          ),
        ],

        if (state.aiSummary != null) ...[
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.secondaryContainer,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Text(state.aiSummary!, style: const TextStyle(fontSize: 13)),
          ),
        ],

        const SizedBox(height: 14),
        FilledButton.icon(
          onPressed: () => _goToAddExpense(state),
          icon: const Icon(Icons.arrow_forward, size: 18),
          label: const Text('บันทึกรายจ่ายนี้'),
        ),
        const SizedBox(height: 8),
      ],
    );
  }
}