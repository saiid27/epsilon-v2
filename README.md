# Epsilon

تطبيق تعليمي مبني بـ Flutter.

## التشغيل

```bash
flutter pub get
flutter run
```

## أهم الملفات

- `lib/main.dart`: نقطة بداية التطبيق والواجهات.
- `pubspec.yaml`: إعدادات Flutter والحزم.
- `android/`: ملفات بناء Android.
- `ios/`: ملفات بناء iOS.
- `test/`: اختبارات التطبيق.

## Firebase

ملفات Firebase الموجودة داخل التطبيق ما زالت محفوظة:

- `firebase.json`
- `firestore.rules`
- `firestore.indexes.json`
- `functions/`
- `lib/firebase_repository.dart`
- `lib/firebase_schema.dart`
- `lib/firebase_options.dart`

## Supabase

تم ربط التطبيق بـ Supabase من خلال:

- `lib/supabase_config.dart`
- `lib/supabase_repository.dart`
- `supabase/schema.sql`

قبل تشغيل التطبيق على Supabase لأول مرة، افتح Supabase SQL Editor وشغّل محتوى:

```text
supabase/schema.sql
```

حساب الإدارة الابتدائي الذي ينشئه الملف:

```text
phone: 22240000000
password: 123456
```
