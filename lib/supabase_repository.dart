import 'dart:convert';
import 'dart:math';

import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';

class SupabaseAppException implements Exception {
  const SupabaseAppException(this.message);

  final String message;

  @override
  String toString() => message;
}

class SupabaseRepository {
  SupabaseRepository({SupabaseClient? client})
    : client = client ?? Supabase.instance.client;

  final SupabaseClient client;
  static const _userIdKey = 'epsilon_supabase_user_id';

  Future<void> initialize() async {}

  Future<bool> healthCheck() async {
    try {
      await client.from('app_settings').select('key').limit(1);
      return true;
    } on Object {
      return false;
    }
  }

  Future<Map<String, dynamic>?> currentUser() async {
    final prefs = await SharedPreferences.getInstance();
    final userId = prefs.getString(_userIdKey);
    if (userId == null || userId.trim().isEmpty) {
      return null;
    }
    final rows = await client.from('users').select().eq('id', userId).limit(1);
    final users = _list(rows);
    return users.isEmpty ? null : _userPayload(users.first);
  }

  Future<Map<String, dynamic>> signIn({
    required String phone,
    required String password,
  }) async {
    final rows = await client
        .from('users')
        .select()
        .eq('phone', phone.trim())
        .eq('password', password)
        .limit(1);
    final users = _list(rows);
    if (users.isEmpty) {
      throw const SupabaseAppException('رقم الهاتف أو كلمة المرور غير صحيحة.');
    }
    final user = _userPayload(users.first);
    if (user['status'] != 'active') {
      throw const SupabaseAppException('الحساب غير مفعل بعد.');
    }
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_userIdKey, '${user['id']}');
    return user;
  }

  Future<void> signOut() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_userIdKey);
  }

  Future<Map<String, String>> createPasswordResetCode({
    required String phone,
  }) async {
    final cleanPhone = phone.trim();
    final rows = await client
        .from('users')
        .select('id, phone')
        .eq('phone', cleanPhone)
        .limit(1);
    final users = _list(rows);
    if (users.isEmpty) {
      throw const SupabaseAppException('رقم الهاتف غير مسجل.');
    }

    final code = (Random.secure().nextInt(900000) + 100000).toString();
    final expiresAt = DateTime.now()
        .toUtc()
        .add(const Duration(minutes: 10))
        .toIso8601String();
    await client
        .from('users')
        .update({
          'password_reset_code': code,
          'password_reset_expires_at': expiresAt,
        })
        .eq('id', '${users.first['id']}');

    return {'phone': _smsPhone(cleanPhone), 'code': code};
  }

  Future<void> resetPasswordWithCode({
    required String phone,
    required String code,
    required String newPassword,
  }) async {
    final rows = await client
        .from('users')
        .select('id, password_reset_code, password_reset_expires_at')
        .eq('phone', phone.trim())
        .limit(1);
    final users = _list(rows);
    if (users.isEmpty) {
      throw const SupabaseAppException('رقم الهاتف غير مسجل.');
    }

    final user = users.first;
    final savedCode = '${user['password_reset_code'] ?? ''}'.trim();
    final expiresAt = DateTime.tryParse(
      '${user['password_reset_expires_at'] ?? ''}',
    );
    if (savedCode.isEmpty ||
        savedCode != code.trim() ||
        expiresAt == null ||
        expiresAt.isBefore(DateTime.now().toUtc())) {
      throw const SupabaseAppException('رمز التحقق غير صحيح أو منتهي.');
    }

    await client
        .from('users')
        .update({
          'password': newPassword,
          'password_reset_code': null,
          'password_reset_expires_at': null,
        })
        .eq('id', '${user['id']}');
  }

  Future<Map<String, dynamic>> get(String path) async {
    return switch (path) {
      '/api/classes' => {'classes': await classes()},
      '/api/courses' => {'courses': await courses()},
      '/api/guest-videos' => {'items': await guestContent('guest_video')},
      '/api/archive-files' => {'items': await guestContent('archive_file')},
      '/api/users' => {'users': await users()},
      '/api/lessons' => {'lessons': await lessons()},
      '/api/notifications' => {'notifications': await notifications()},
      _ => throw SupabaseAppException('Unsupported Supabase path: $path'),
    };
  }

  Future<Map<String, dynamic>> post(
    String path,
    Map<String, dynamic> body,
  ) async {
    if (path == '/api/classes') {
      final row = await client
          .from('classes')
          .insert({'name': body['name'], 'level': body['level']})
          .select()
          .single();
      return {'class': _classPayload(_map(row))};
    }
    throw SupabaseAppException('Unsupported Supabase path: $path');
  }

  Future<Map<String, dynamic>> registerStudent({
    required String name,
    required String phone,
    required String password,
    required String courseId,
    required List<String> selectedSubjects,
    required String paymentProofPath,
    required String paymentSenderPhone,
    String? paymentAmount,
  }) async {
    final course = await _courseById(courseId);
    final row = await client
        .from('users')
        .insert({
          'name': name.trim(),
          'phone': phone.trim(),
          'password': password,
          'role': 'student',
          'status': 'pending',
          'class_id': course?['class_id'],
          'course_id': courseId,
          'selected_subjects': selectedSubjects,
          'payment_proof_url': paymentProofPath.trim(),
          'payment_sender_phone': paymentSenderPhone.trim(),
          'payment_amount': paymentAmount?.trim(),
        })
        .select()
        .single();
    return {'user': _userPayload(_map(row))};
  }

  Future<Map<String, dynamic>> settings() async {
    final rows = _list(await client.from('app_settings').select());
    final values = <String, String>{};
    for (final row in rows) {
      values['${row['key']}'] = '${row['value'] ?? ''}';
    }
    return {
      'settings': {
        'paymentNumber': values['paymentNumber'] ?? '',
        'paymentAmount': values['paymentAmount'] ?? '',
        'offerTextTitle': values['offerTextTitle'] ?? '',
        'offerTextBody': values['offerTextBody'] ?? '',
        'offerTextActive': values['offerTextActive'] ?? 'true',
        'expenses': _decodeJsonList(values['expenses']),
        'payments': _decodeJsonList(values['payments']),
        'paymentMethods': await paymentMethods(),
      },
    };
  }

  Future<Map<String, dynamic>> updateSettings({
    String? paymentNumber,
    String? paymentAmount,
    List<Map<String, dynamic>>? expenses,
    List<Map<String, dynamic>>? payments,
  }) async {
    if (paymentNumber != null) {
      await _upsertSetting('paymentNumber', paymentNumber);
    }
    if (paymentAmount != null) {
      await _upsertSetting('paymentAmount', paymentAmount);
    }
    if (expenses != null) {
      await _upsertSetting('expenses', jsonEncode(expenses));
    }
    if (payments != null) {
      await _upsertSetting('payments', jsonEncode(payments));
    }
    return settings();
  }

  Future<void> _upsertSetting(String key, String value) {
    return client.from('app_settings').upsert({
      'key': key,
      'value': value.trim(),
      'updated_at': DateTime.now().toUtc().toIso8601String(),
    });
  }

  List<Map<String, dynamic>> _decodeJsonList(String? raw) {
    if (raw == null || raw.trim().isEmpty) {
      return const [];
    }
    try {
      final decoded = jsonDecode(raw);
      if (decoded is List) {
        return decoded
            .whereType<Map>()
            .map((item) => Map<String, dynamic>.from(item))
            .toList();
      }
    } on Object {
      return const [];
    }
    return const [];
  }

  String _smsPhone(String phone) {
    final trimmed = phone.trim();
    if (trimmed.startsWith('+')) {
      return trimmed;
    }
    if (trimmed.startsWith('00')) {
      return '+${trimmed.substring(2)}';
    }
    final digits = trimmed.replaceAll(RegExp(r'[^0-9]'), '');
    if (digits.length == 8) {
      return '+222$digits';
    }
    return '+$digits';
  }

  Future<Map<String, dynamic>> createPaymentMethod({
    required String name,
    required String accountNumber,
    required String imageUrl,
  }) async {
    await client.from('payment_methods').insert({
      'name': name.trim(),
      'account_number': accountNumber.trim(),
      'image_url': imageUrl.trim(),
    });
    return settings();
  }

  Future<Map<String, dynamic>> deletePaymentMethod(String id) async {
    await client.from('payment_methods').delete().eq('id', id);
    return settings();
  }

  Future<Map<String, dynamic>> createUser({
    required String name,
    required String phone,
    required String password,
    required String role,
    required String courseId,
    String? subject,
    String? paymentAmount,
  }) async {
    final course = await _courseById(courseId);
    final row = await client
        .from('users')
        .insert({
          'name': name.trim(),
          'phone': phone.trim(),
          'password': password,
          'role': role,
          'status': 'active',
          'class_id': course?['class_id'],
          'course_id': courseId,
          'subject': subject?.trim(),
          'payment_amount': paymentAmount?.trim(),
        })
        .select()
        .single();
    return {'user': _userPayload(_map(row))};
  }

  Future<void> updateAccountStatus(String uid, String status) {
    return client.from('users').update({'status': status}).eq('id', uid);
  }

  Future<void> deleteUserAccount(String uid) {
    return client.from('users').delete().eq('id', uid);
  }

  Future<void> createCourse({
    required String title,
    required String classId,
    required String description,
    required String price,
    required List<Map<String, String>> subjects,
  }) {
    return client.from('courses').insert({
      'title': title.trim(),
      'class_id': classId,
      'description': description.trim(),
      'price': price.trim(),
      'subjects': subjects.map((item) => item['name'] ?? '').toList(),
      'subject_details': subjects,
    });
  }

  Future<void> deleteCourse(String courseId) {
    return client.from('courses').delete().eq('id', courseId);
  }

  Future<void> createLesson({
    required String title,
    required String url,
    required String classId,
    required String courseId,
    required String subject,
    String? teacherId,
  }) {
    return client.from('lessons').insert({
      'title': title.trim(),
      'url': url.trim(),
      'teacher_id': teacherId,
      'class_id': classId,
      'course_id': courseId,
      'subject': subject.trim(),
    });
  }

  Future<void> updateLesson({
    required String lessonId,
    required String title,
    required String url,
  }) {
    return client
        .from('lessons')
        .update({'title': title.trim(), 'url': url.trim()})
        .eq('id', lessonId);
  }

  Future<void> deleteLesson(String lessonId) {
    return client.from('lessons').delete().eq('id', lessonId);
  }

  Future<void> addNotification({required String title, required String body}) {
    return client.from('notifications').insert({
      'title': title.trim(),
      'body': body.trim(),
    });
  }

  Future<void> updateNotification({
    required String id,
    required String title,
    required String body,
  }) {
    return client
        .from('notifications')
        .update({'title': title.trim(), 'body': body.trim()})
        .eq('id', id);
  }

  Future<void> deleteNotification(String id) {
    return client.from('notifications').delete().eq('id', id);
  }

  Future<Map<String, dynamic>> createGuestContent({
    required String contentType,
    required String title,
    required String url,
    required String description,
    required String courseId,
  }) async {
    final row = await client
        .from('guest_content')
        .insert({
          'content_type': contentType,
          'title': title.trim(),
          'url': url.trim(),
          'description': description.trim(),
          'course_id': courseId,
        })
        .select()
        .single();
    return {'item': _guestPayload(_map(row))};
  }

  Future<Map<String, dynamic>> updateGuestContent({
    required String id,
    required String title,
    required String url,
    required String description,
    required String courseId,
  }) async {
    final row = await client
        .from('guest_content')
        .update({
          'title': title.trim(),
          'url': url.trim(),
          'description': description.trim(),
          'course_id': courseId,
        })
        .eq('id', id)
        .select()
        .single();
    return {'item': _guestPayload(_map(row))};
  }

  Future<void> deleteGuestContent(String id) {
    return client.from('guest_content').delete().eq('id', id);
  }

  Future<List<Map<String, dynamic>>> searchNationalResults({
    required String examType,
    required String query,
    String? center,
  }) async {
    final trimmed = query.trim();
    if (trimmed.length < 2 && int.tryParse(trimmed) == null) {
      return const [];
    }
    var request = client
        .from('national_exam_results')
        .select()
        .eq('exam_type', examType);
    if (center != null && center.trim().isNotEmpty) {
      request = request.eq('center_name', center.trim());
    }
    final rows = int.tryParse(trimmed) != null
        ? await request.eq('candidate_number', trimmed).limit(20)
        : await request.ilike('full_name', '%$trimmed%').limit(20);
    return _list(rows).map(_resultPayload).toList();
  }

  Future<List<String>> nationalResultCenters({required String examType}) async {
    final rows = await client
        .from('national_exam_results')
        .select('center_name')
        .eq('exam_type', examType)
        .not('center_name', 'is', null)
        .order('center_name');
    return _list(rows)
        .map((row) => '${row['center_name'] ?? ''}'.trim())
        .where((value) => value.isNotEmpty)
        .toSet()
        .toList();
  }

  Future<List<Map<String, dynamic>>> offers() async {
    final rows = await client
        .from('offer_slides')
        .select()
        .eq('active', true)
        .order('sort_order')
        .order('created_at', ascending: false);
    return _list(rows).map(_offerPayload).toList();
  }

  Future<Map<String, dynamic>> offerTextSection() async {
    final data = await settings();
    final settingsData = data['settings'] as Map<String, dynamic>;
    return {
      'title': settingsData['offerTextTitle'] ?? '',
      'body': settingsData['offerTextBody'] ?? '',
      'active': '${settingsData['offerTextActive'] ?? 'true'}' != 'false',
    };
  }

  Future<int> uploadNationalResults({
    required String examType,
    required String filePath,
    required String fileName,
  }) {
    throw const SupabaseAppException(
      'رفع ملفات النتائج يحتاج Edge Function أو استيراد SQL/CSV من لوحة Supabase.',
    );
  }

  Future<List<Map<String, dynamic>>> users() async {
    final rows = await client.from('users').select().order('created_at');
    return _list(rows).map(_userPayload).toList();
  }

  Future<List<Map<String, dynamic>>> classes() async {
    final rows = await client.from('classes').select().order('created_at');
    return _list(rows).map(_classPayload).toList();
  }

  Future<List<Map<String, dynamic>>> courses() async {
    final rows = await client
        .from('courses')
        .select()
        .eq('is_active', true)
        .order('created_at');
    return _list(rows).map(_coursePayload).toList();
  }

  Future<List<Map<String, dynamic>>> lessons() async {
    final rows = await client
        .from('lessons')
        .select()
        .order('created_at', ascending: false);
    return _list(rows).map(_lessonPayload).toList();
  }

  Future<List<Map<String, dynamic>>> notifications() async {
    final rows = await client
        .from('notifications')
        .select()
        .order('created_at', ascending: false);
    return _list(rows).map(_notificationPayload).toList();
  }

  Future<List<Map<String, dynamic>>> paymentMethods() async {
    final rows = await client
        .from('payment_methods')
        .select()
        .eq('active', true)
        .order('created_at', ascending: false);
    return _list(rows).map(_paymentMethodPayload).toList();
  }

  Future<List<Map<String, dynamic>>> guestContent(String type) async {
    final rows = await client
        .from('guest_content')
        .select()
        .eq('content_type', type)
        .eq('active', true)
        .order('created_at', ascending: false);
    return _list(rows).map(_guestPayload).toList();
  }

  Future<Map<String, dynamic>?> _courseById(String id) async {
    final rows = await client.from('courses').select().eq('id', id).limit(1);
    final items = _list(rows);
    return items.isEmpty ? null : items.first;
  }

  List<Map<String, dynamic>> _list(Object? value) {
    if (value is List) {
      return value.whereType<Map>().map(_map).toList();
    }
    return const [];
  }

  Map<String, dynamic> _map(Object? value) {
    return value is Map ? Map<String, dynamic>.from(value) : const {};
  }

  Map<String, dynamic> _userPayload(Map<String, dynamic> row) {
    return {
      'id': '${row['id'] ?? ''}',
      'name': row['name'],
      'phone': row['phone'],
      'role': row['role'],
      'status': row['status'],
      'classId': row['class_id'],
      'courseId': row['course_id'],
      'subject': row['subject'],
      'selectedSubjects': row['selected_subjects'],
      'paymentProofUrl': row['payment_proof_url'],
      'paymentSenderPhone': row['payment_sender_phone'],
      'activeDeviceId': row['active_device_id'],
      'paymentAmount': row['payment_amount'],
    };
  }

  Map<String, dynamic> _classPayload(Map<String, dynamic> row) {
    return {
      'id': '${row['id'] ?? ''}',
      'name': row['name'],
      'level': row['level'],
    };
  }

  Map<String, dynamic> _coursePayload(Map<String, dynamic> row) {
    return {
      'id': '${row['id'] ?? ''}',
      'title': row['title'],
      'classId': row['class_id'],
      'description': row['description'],
      'price': row['price'],
      'subjects': row['subjects'],
      'subjectDetails': row['subject_details'],
      'isActive': row['is_active'],
    };
  }

  Map<String, dynamic> _lessonPayload(Map<String, dynamic> row) {
    return {
      'id': '${row['id'] ?? ''}',
      'title': row['title'],
      'url': row['url'],
      'teacherId': '${row['teacher_id'] ?? ''}',
      'classId': row['class_id'],
      'courseId': row['course_id'],
      'subject': row['subject'],
      'createdAt': row['created_at'],
      'isPublished': row['is_published'],
    };
  }

  Map<String, dynamic> _notificationPayload(Map<String, dynamic> row) {
    return {
      'id': '${row['id'] ?? ''}',
      'title': row['title'],
      'body': row['body'],
      'createdAt': row['created_at'],
    };
  }

  Map<String, dynamic> _paymentMethodPayload(Map<String, dynamic> row) {
    return {
      'id': '${row['id'] ?? ''}',
      'name': row['name'],
      'accountNumber': row['account_number'],
      'imageUrl': row['image_url'],
    };
  }

  Map<String, dynamic> _guestPayload(Map<String, dynamic> row) {
    return {
      'id': '${row['id'] ?? ''}',
      'title': row['title'],
      'url': row['url'],
      'description': row['description'],
      'courseId': row['course_id'],
      'createdAt': row['created_at'],
    };
  }

  Map<String, dynamic> _resultPayload(Map<String, dynamic> row) {
    return {
      'id': '${row['id'] ?? ''}',
      'examType': row['exam_type'],
      'candidateNumber': row['candidate_number'],
      'fullName': row['full_name'],
      'birthPlace': row['birth_place'],
      'birthDate': row['birth_date'],
      'wilaya': row['wilaya'],
      'moughataa': row['moughataa'],
      'centerName': row['center_name'],
      'score': row['score'],
      'decision': row['decision'],
      'rank': row['rank'],
      'rawData': row['raw_data'],
    };
  }

  Map<String, dynamic> _offerPayload(Map<String, dynamic> row) {
    return {
      'id': '${row['id'] ?? ''}',
      'title': row['title'],
      'imageUrl': row['image_url'],
      'durationSeconds': row['duration_seconds'],
    };
  }
}
