import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:intl/date_symbol_data_local.dart'; // เพิ่ม

import 'core/di/injection.dart';
import 'presentation/app.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await dotenv.load(fileName: '.env');
  await Hive.initFlutter();
  await initializeDateFormatting('th_TH', null); // เพิ่ม
  await configureDependencies();
  runApp(const App());
}