# 🤖 AI Receipt & Expense Tracker

แอปพลิเคชัน Flutter สำหรับจัดการรายรับรายจ่ายด้วย AI — สแกนใบเสร็จด้วย Google ML Kit และจัดหมวดหมู่อัตโนมัติด้วย Gemini API

---

## 🏗️ Architecture

โปรเจกต์นี้ใช้ **Clean Architecture** แบ่งออกเป็น 3 เลเยอร์:

```
lib/
├── core/
│   ├── di/           # Dependency Injection (get_it)
│   ├── error/        # Failure classes (dartz)
│   └── network/      # Dio client + Interceptors
│
├── data/
│   ├── datasources/
│   │   ├── local/    # Isar DB + Hive Cache
│   │   └── remote/   # Gemini API
│   └── repositories/ # Repository implementations
│
├── domain/
│   ├── entities/     # Pure Dart classes
│   ├── repositories/ # Abstract interfaces
│   └── usecases/     # Business logic
│
└── presentation/
    ├── blocs/        # BLoC + Cubit
    ├── pages/        # UI Pages
    └── router/       # auto_route
```

---

## 📦 Dependencies หลัก

| Package | หน้าที่ |
|---------|---------|
| `flutter_bloc` | State Management (BLoC Pattern) |
| `get_it` | Dependency Injection |
| `dartz` | Functional Error Handling (Either) |
| `auto_route` | Navigation & Routing |
| `isar` | Local Database (Offline-first) |
| `hive` | Key-Value Cache สำหรับ AI responses |
| `shared_preferences` | เก็บ Settings (Dark/Light mode) |
| `dio` | HTTP Client + Interceptors |
| `google_mlkit_text_recognition` | On-device OCR |
| `fl_chart` | Dashboard Charts |
| `freezed` | JSON Serialization |

---

## 🚀 วิธีรันโปรเจกต์

### 1. Prerequisites
```bash
flutter --version  # ต้องการ Flutter 3.19+
```

### 2. Clone & Setup
```bash
git clone <your-repo-url>
cd ai_expense_tracker
```

### 3. ตั้งค่า API Key
สร้างไฟล์ `.env` ที่ root ของโปรเจกต์:
```env
GEMINI_API_KEY=your_gemini_api_key_here
GEMINI_BASE_URL=https://generativelanguage.googleapis.com/v1beta
```
> 🔑 ขอ API Key ได้ฟรีที่ https://makersuite.google.com/app/apikey

### 4. Install Dependencies
```bash
flutter pub get
```

### 5. Generate Code
```bash
dart run build_runner build --delete-conflicting-outputs
```

### 6. รันแอป
```bash
flutter run
```

---

## 🧪 รัน Tests

```bash
# Unit Tests
flutter test test/unit/

# Widget Tests  
flutter test test/widget/

# Integration Tests (ต้องมี emulator/device)
flutter test integration_test/
```

---

## ✅ Technical Requirements Checklist

- [x] **Clean Architecture** — Domain / Data / Presentation layers
- [x] **Dependency Injection** — get_it
- [x] **Functional Programming** — dartz Either<Failure, Success>
- [x] **State Management** — BLoC pattern
- [x] **Navigation** — auto_route พร้อม parameter passing
- [x] **Local Database** — Isar (offline-first)
- [x] **Key-Value Storage** — Hive (AI cache) + SharedPreferences (settings)
- [x] **REST API + Dio** — Interceptors (API Key, Logging, Error)
- [x] **JSON Serialization** — freezed / json_serializable
- [x] **On-device ML** — Google ML Kit Text Recognition
- [x] **Cloud LLM** — Gemini API (categorize + summarize)
- [x] **Form + Validation** — GlobalKey<FormState>
- [x] **Implicit Animation** — AnimatedContainer + AnimatedOpacity (Dashboard card)
- [x] **Explicit/Hero Animation** — Hero widget (List → Detail)
- [x] **Unit Test** — BLoC tests with mocktail
- [x] **Widget Test** — Form validation tests
- [x] **Integration Test** — End-to-end flow

---

## 📱 หน้าจอหลัก

1. **Dashboard** — สรุปรายจ่ายเดือนนี้ + Pie Chart ตามหมวดหมู่
2. **Scan Receipt** — ถ่ายรูปใบเสร็จ → ML Kit OCR → AI จัดหมวด + สรุป
3. **Add/Edit Expense** — Form พร้อม Validation ครบถ้วน
4. **Expense List** — รายการทั้งหมด + Hero Animation + Swipe to delete
5. **Settings** — สลับ Dark/Light Mode
# Lab-Exam-2
