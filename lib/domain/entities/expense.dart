import 'package:equatable/equatable.dart';

class Expense extends Equatable {
  final int? id;
  final String title;
  final String storeName;
  final double amount;
  final String category;
  final DateTime date;
  final String? imagePath;
  final String? rawOcrText;
  final String? aiSummary;

  const Expense({
    this.id,
    required this.title,
    required this.storeName,
    required this.amount,
    required this.category,
    required this.date,
    this.imagePath,
    this.rawOcrText,
    this.aiSummary,
  });

  Expense copyWith({
    int? id,
    String? title,
    String? storeName,
    double? amount,
    String? category,
    DateTime? date,
    String? imagePath,
    String? rawOcrText,
    String? aiSummary,
  }) =>
      Expense(
        id: id ?? this.id,
        title: title ?? this.title,
        storeName: storeName ?? this.storeName,
        amount: amount ?? this.amount,
        category: category ?? this.category,
        date: date ?? this.date,
        imagePath: imagePath ?? this.imagePath,
        rawOcrText: rawOcrText ?? this.rawOcrText,
        aiSummary: aiSummary ?? this.aiSummary,
      );

  @override
  List<Object?> get props =>
      [id, title, storeName, amount, category, date, imagePath];
}

class ExpenseSummary extends Equatable {
  final Map<String, double> categoryTotals;
  final double totalAmount;
  final int totalCount;
  final DateTime periodStart;
  final DateTime periodEnd;

  const ExpenseSummary({
    required this.categoryTotals,
    required this.totalAmount,
    required this.totalCount,
    required this.periodStart,
    required this.periodEnd,
  });

  @override
  List<Object> get props =>
      [categoryTotals, totalAmount, totalCount, periodStart, periodEnd];
}
