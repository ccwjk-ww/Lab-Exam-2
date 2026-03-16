import 'dart:convert';
import 'package:dio/dio.dart';
import 'package:dartz/dartz.dart';
import 'package:flutter/foundation.dart';

import '../../../core/error/failures.dart';

// ─── Response Models ──────────────────────────────────────────────────────────

class ExtractedReceiptData {
  final String storeName;
  final double? totalAmount;
  final DateTime? date;
  final String suggestedTitle;
  final String suggestedCategory;
  final List<ReceiptItem> items;

  const ExtractedReceiptData({
    required this.storeName,
    this.totalAmount,
    this.date,
    required this.suggestedTitle,
    required this.suggestedCategory,
    required this.items,
  });

  factory ExtractedReceiptData.fromJson(Map<String, dynamic> json) {
    return ExtractedReceiptData(
      storeName: json['store_name'] as String? ?? '',
      totalAmount: (json['total_amount'] as num?)?.toDouble(),
      date: json['date'] != null && json['date'] != 'null'
          ? DateTime.tryParse(json['date'] as String)
          : null,
      suggestedTitle: json['suggested_title'] as String? ?? '',
      suggestedCategory: json['suggested_category'] as String? ?? 'อื่นๆ',
      items: (json['items'] as List<dynamic>?)
          ?.map((e) => ReceiptItem.fromJson(e as Map<String, dynamic>))
          .toList() ??
          [],
    );
  }
}

class ReceiptItem {
  final String name;
  final double? price;
  final int? quantity;

  const ReceiptItem({required this.name, this.price, this.quantity});

  factory ReceiptItem.fromJson(Map<String, dynamic> json) => ReceiptItem(
    name: json['name'] as String? ?? '',
    price: (json['price'] as num?)?.toDouble(),
    quantity: json['quantity'] as int?,
  );
}

class SpendingAnalysis {
  final String overview;
  final List<String> insights;
  final List<String> warnings;
  final List<String> suggestions;

  const SpendingAnalysis({
    required this.overview,
    required this.insights,
    required this.warnings,
    required this.suggestions,
  });

  factory SpendingAnalysis.fromJson(Map<String, dynamic> json) =>
      SpendingAnalysis(
        overview: json['overview'] as String? ?? '',
        insights: List<String>.from(json['insights'] as List? ?? []),
        warnings: List<String>.from(json['warnings'] as List? ?? []),
        suggestions: List<String>.from(json['suggestions'] as List? ?? []),
      );
}

class BudgetAdvice {
  final double recommendedMonthlyBudget;
  final Map<String, double> categoryBudgets;
  final List<String> tips;
  final String reasoning;

  const BudgetAdvice({
    required this.recommendedMonthlyBudget,
    required this.categoryBudgets,
    required this.tips,
    required this.reasoning,
  });

  factory BudgetAdvice.fromJson(Map<String, dynamic> json) => BudgetAdvice(
    recommendedMonthlyBudget:
    (json['recommended_monthly_budget'] as num?)?.toDouble() ?? 0,
    categoryBudgets: (json['category_budgets'] as Map<String, dynamic>?)
        ?.map((k, v) => MapEntry(k, (v as num).toDouble())) ??
        {},
    tips: List<String>.from(json['tips'] as List? ?? []),
    reasoning: json['reasoning'] as String? ?? '',
  );
}

class AnomalyResult {
  final List<ExpenseAnomaly> anomalies;
  final String summary;

  const AnomalyResult({required this.anomalies, required this.summary});

  factory AnomalyResult.fromJson(Map<String, dynamic> json) => AnomalyResult(
    anomalies: (json['anomalies'] as List<dynamic>?)
        ?.map((e) =>
        ExpenseAnomaly.fromJson(e as Map<String, dynamic>))
        .toList() ??
        [],
    summary: json['summary'] as String? ?? 'ไม่พบรายจ่ายผิดปกติ',
  );
}

class ExpenseAnomaly {
  final String type;
  final String description;
  final String? relatedExpenseTitle;
  final String severity;

  const ExpenseAnomaly({
    required this.type,
    required this.description,
    this.relatedExpenseTitle,
    required this.severity,
  });

  factory ExpenseAnomaly.fromJson(Map<String, dynamic> json) => ExpenseAnomaly(
    type: json['type'] as String? ?? '',
    description: json['description'] as String? ?? '',
    relatedExpenseTitle: json['related_expense_title'] as String?,
    severity: json['severity'] as String? ?? 'low',
  );
}

// ─── Abstract Interface ───────────────────────────────────────────────────────

abstract class RemoteAiDataSource {
  Future<Either<Failure, String>> categorizeExpense(String ocrText);
  Future<Either<Failure, String>> summarizeExpense(String ocrText);
  Future<Either<Failure, ExtractedReceiptData>> extractReceiptData(String ocrText);
  Future<Either<Failure, SpendingAnalysis>> analyzeSpendingPattern(
      List<Map<String, dynamic>> expensesJson);
  Future<Either<Failure, BudgetAdvice>> generateBudgetAdvice(
      List<Map<String, dynamic>> expensesJson, double currentMonthTotal);
  Future<Either<Failure, AnomalyResult>> detectAnomalies(
      List<Map<String, dynamic>> expensesJson);
}

// ─── Implementation ───────────────────────────────────────────────────────────

class GeminiDataSourceImpl implements RemoteAiDataSource {
  final Dio _dio;

  GeminiDataSourceImpl(this._dio);

  // ── Helper: POST ไปที่ baseUrl โดยตรง ────────────────────────────────────
  // .env: GEMINI_BASE_URL=https://generativelanguage.googleapis.com/v1beta/
  // _callGemini จะต่อ path = models/gemini-2.5-flash:generateContent
  // → https://generativelanguage.googleapis.com/v1beta/models/gemini-2.5-flash:generateContent
  Future<String> _callGemini(String prompt) async {
    final response = await _dio.post(
      'models/gemini-2.5-flash:generateContent',
      data: {
        'contents': [
          {
            'parts': [
              {'text': prompt}
            ]
          }
        ],
        'generationConfig': {
          'temperature': 0.2,
          'maxOutputTokens': 2048,
        },
      },
    );

    // ── ดึง text จาก response อย่างปลอดภัย ──
    final data = response.data as Map<String, dynamic>?;
    if (data == null) throw Exception('Response data is null');

    final candidates = data['candidates'] as List?;
    if (candidates == null || candidates.isEmpty) {
      throw Exception('No candidates in response');
    }

    final content = candidates[0]['content'] as Map<String, dynamic>?;
    if (content == null) throw Exception('No content in candidate');

    final parts = content['parts'] as List?;
    if (parts == null || parts.isEmpty) throw Exception('No parts in content');

    final text = parts[0]['text'] as String?;
    if (text == null || text.trim().isEmpty) throw Exception('Empty text in response');

    if (kDebugMode) {
      debugPrint('=== Gemini raw response (first 300 chars) ===');
      debugPrint(text.substring(0, text.length.clamp(0, 300)));
      debugPrint('=============================================');
    }

    return text;
  }

  // ── Helper: แกะ JSON ที่อาจมี markdown หรือ text นำหน้า ─────────────────
  Map<String, dynamic> _parseJson(String raw) {
    String s = raw.trim();

    // ลบ markdown code block: ```json ... ``` หรือ ``` ... ```
    s = s.replaceAll(RegExp(r'```json', caseSensitive: false), '');
    s = s.replaceAll('```', '');
    s = s.trim();

    // หา { อันแรก (ตัด text นำหน้าออก)
    final start = s.indexOf('{');
    if (start < 0) throw Exception('No JSON object found in:\n$s');
    s = s.substring(start);

    // หา } อันสุดท้าย (ตัด text ท้ายออก)
    final end = s.lastIndexOf('}');
    if (end < 0) throw Exception('No closing brace found');
    s = s.substring(0, end + 1);

    try {
      return jsonDecode(s) as Map<String, dynamic>;
    } catch (e) {
      if (kDebugMode) {
        debugPrint('JSON parse failed. Cleaned string:\n$s');
      }
      throw Exception('JSON parse error: $e');
    }
  }

  // ── 1. Categorize ─────────────────────────────────────────────────────────
  @override
  Future<Either<Failure, String>> categorizeExpense(String ocrText) async {
    try {
      final prompt = '''
คุณเป็นผู้ช่วยจัดหมวดหมู่รายจ่าย จากข้อความใบเสร็จด้านล่าง ให้ระบุหมวดหมู่เป็น 1 คำ จากรายการ:
อาหาร, เดินทาง, ช้อปปิ้ง, สุขภาพ, บันเทิง, ที่อยู่อาศัย, การศึกษา, อื่นๆ

ข้อความใบเสร็จ:
$ocrText

ตอบเฉพาะชื่อหมวดหมู่เท่านั้น ไม่ต้องอธิบายเพิ่มเติม
''';
      final text = await _callGemini(prompt);
      return Right(text.trim());
    } on DioException catch (e) {
      return Left(ServerFailure(e.error?.toString() ?? 'Server error'));
    } catch (e) {
      return Left(ServerFailure(e.toString()));
    }
  }

  // ── 2. Summarize ──────────────────────────────────────────────────────────
  @override
  Future<Either<Failure, String>> summarizeExpense(String ocrText) async {
    try {
      final prompt = '''
สรุปข้อมูลจากใบเสร็จต่อไปนี้อย่างกระชับ ระบุ: ชื่อร้าน, รายการสินค้าหลัก, และยอดรวม

ข้อความจากใบเสร็จ:
$ocrText

สรุปเป็นภาษาไทย ไม่เกิน 3 ประโยค
''';
      final text = await _callGemini(prompt);
      return Right(text.trim());
    } on DioException catch (e) {
      return Left(ServerFailure(e.error?.toString() ?? 'Server error'));
    } catch (e) {
      return Left(ServerFailure(e.toString()));
    }
  }

  // ── 3. Extract Receipt Data ───────────────────────────────────────────────
  @override
  Future<Either<Failure, ExtractedReceiptData>> extractReceiptData(
      String ocrText) async {
    try {
      final prompt = '''
คุณเป็นผู้ช่วยอ่านใบเสร็จ วิเคราะห์ข้อความใบเสร็จด้านล่างแล้วตอบเป็น JSON เท่านั้น

ข้อความใบเสร็จ:
$ocrText

ตอบเป็น JSON object เท่านั้น ห้ามมี markdown ห้ามมี text อื่น:
{
  "store_name": "ชื่อร้าน",
  "total_amount": 0.00,
  "date": "YYYY-MM-DD หรือ null ถ้าไม่พบ",
  "suggested_title": "ชื่อรายการสั้นๆ",
  "suggested_category": "อาหาร",
  "items": [{"name": "ชื่อสินค้า", "price": 0.00, "quantity": 1}]
}
''';
      final raw = await _callGemini(prompt);
      final parsed = _parseJson(raw);
      return Right(ExtractedReceiptData.fromJson(parsed));
    } on DioException catch (e) {
      return Left(ServerFailure(e.error?.toString() ?? 'Server error'));
    } catch (e) {
      return Left(ServerFailure('extractReceiptData: $e'));
    }
  }

  // ── 4. Analyze Spending Pattern ───────────────────────────────────────────
  @override
  Future<Either<Failure, SpendingAnalysis>> analyzeSpendingPattern(
      List<Map<String, dynamic>> expensesJson) async {
    try {
      final summary = expensesJson
          .take(50)
          .map((e) =>
      '- ${e['date']}: ${e['category']} ${e['amount']} บาท (${e['title']})')
          .join('\n');

      final prompt = '''
คุณเป็นที่ปรึกษาการเงินส่วนตัว วิเคราะห์รายการรายจ่ายด้านล่าง แล้วตอบเป็น JSON เท่านั้น

รายการรายจ่าย:
$summary

ตอบเป็น JSON object เท่านั้น ห้ามมี markdown ห้ามมี text อื่น:
{
  "overview": "ภาพรวมการใช้จ่าย 2-3 ประโยค",
  "insights": ["ข้อสังเกต 1", "ข้อสังเกต 2", "ข้อสังเกต 3"],
  "warnings": ["สิ่งที่ควรระวัง 1"],
  "suggestions": ["คำแนะนำ 1", "คำแนะนำ 2", "คำแนะนำ 3"]
}
''';
      final raw = await _callGemini(prompt);
      final parsed = _parseJson(raw);
      return Right(SpendingAnalysis.fromJson(parsed));
    } on DioException catch (e) {
      return Left(ServerFailure(e.error?.toString() ?? 'Server error'));
    } catch (e) {
      return Left(ServerFailure('analyzeSpendingPattern: $e'));
    }
  }

  // ── 5. Generate Budget Advice ─────────────────────────────────────────────
  @override
  Future<Either<Failure, BudgetAdvice>> generateBudgetAdvice(
      List<Map<String, dynamic>> expensesJson,
      double currentMonthTotal) async {
    try {
      final Map<String, double> totals = {};
      for (final e in expensesJson) {
        final cat = e['category'] as String? ?? 'อื่นๆ';
        final amt = (e['amount'] as num?)?.toDouble() ?? 0;
        totals[cat] = (totals[cat] ?? 0) + amt;
      }
      final breakdown = totals.entries
          .map((e) => '${e.key}: ${e.value.toStringAsFixed(0)} บาท')
          .join(', ');

      final prompt = '''
คุณเป็นที่ปรึกษาการเงิน แนะนำงบประมาณที่เหมาะสมจากข้อมูลด้านล่าง ตอบเป็น JSON เท่านั้น

รายจ่ายแต่ละหมวดหมู่: $breakdown
ยอดรวมเดือนนี้: ${currentMonthTotal.toStringAsFixed(0)} บาท

ตอบเป็น JSON object เท่านั้น ห้ามมี markdown ห้ามมี text อื่น:
{
  "recommended_monthly_budget": 0.00,
  "category_budgets": {
    "อาหาร": 0.00,
    "เดินทาง": 0.00,
    "ช้อปปิ้ง": 0.00,
    "สุขภาพ": 0.00,
    "บันเทิง": 0.00,
    "ที่อยู่อาศัย": 0.00,
    "การศึกษา": 0.00,
    "อื่นๆ": 0.00
  },
  "tips": ["เคล็ดลับ 1", "เคล็ดลับ 2", "เคล็ดลับ 3"],
  "reasoning": "เหตุผล 1-2 ประโยค"
}
''';
      final raw = await _callGemini(prompt);
      final parsed = _parseJson(raw);
      return Right(BudgetAdvice.fromJson(parsed));
    } on DioException catch (e) {
      return Left(ServerFailure(e.error?.toString() ?? 'Server error'));
    } catch (e) {
      return Left(ServerFailure('generateBudgetAdvice: $e'));
    }
  }

  // ── 6. Detect Anomalies ───────────────────────────────────────────────────
  @override
  Future<Either<Failure, AnomalyResult>> detectAnomalies(
      List<Map<String, dynamic>> expensesJson) async {
    try {
      final list = expensesJson
          .take(100)
          .map((e) =>
      '${e['date']} | ${e['title']} | ${e['category']} | ${e['amount']} บาท')
          .join('\n');

      final prompt = '''
คุณเป็นผู้ตรวจสอบรายจ่าย ตรวจหารายการผิดปกติ ตอบเป็น JSON เท่านั้น

รายการรายจ่าย:
$list

ตอบเป็น JSON object เท่านั้น ห้ามมี markdown ห้ามมี text อื่น:
{
  "anomalies": [
    {
      "type": "duplicate",
      "description": "อธิบาย",
      "related_expense_title": null,
      "severity": "low"
    }
  ],
  "summary": "สรุปผล 1 ประโยค"
}

ถ้าไม่พบสิ่งผิดปกติ ให้ anomalies เป็น []
''';
      final raw = await _callGemini(prompt);
      final parsed = _parseJson(raw);
      return Right(AnomalyResult.fromJson(parsed));
    } on DioException catch (e) {
      return Left(ServerFailure(e.error?.toString() ?? 'Server error'));
    } catch (e) {
      return Left(ServerFailure('detectAnomalies: $e'));
    }
  }
}