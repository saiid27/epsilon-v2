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
  static const _deviceIdKey = 'epsilon_device_id';

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
    if (users.isEmpty) {
      await prefs.remove(_userIdKey);
      return null;
    }
    final user = _userPayload(users.first);
    final deviceId = await _deviceId();
    final activeDeviceId = '${user['activeDeviceId'] ?? ''}'.trim();
    if (activeDeviceId.isEmpty) {
      await _setActiveDevice('${user['id']}', deviceId);
      return {...user, 'activeDeviceId': deviceId};
    }
    if (activeDeviceId != deviceId) {
      await prefs.remove(_userIdKey);
      return null;
    }
    return user;
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
    final deviceId = await _deviceId();
    final activeDeviceId = '${user['activeDeviceId'] ?? ''}'.trim();
    if (activeDeviceId.isNotEmpty && activeDeviceId != deviceId) {
      throw const SupabaseAppException(
        'هذا الحساب مفتوح على هاتف آخر. سجّل الخروج من الهاتف الآخر أولاً.',
      );
    }
    await _setActiveDevice('${user['id']}', deviceId);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_userIdKey, '${user['id']}');
    return {...user, 'activeDeviceId': deviceId};
  }

  Future<void> signOut() async {
    final prefs = await SharedPreferences.getInstance();
    final userId = prefs.getString(_userIdKey);
    if (userId != null && userId.trim().isNotEmpty) {
      final deviceId = await _deviceId();
      await client
          .from('users')
          .update({'active_device_id': null})
          .eq('id', userId)
          .eq('active_device_id', deviceId);
    }
    await prefs.remove(_userIdKey);
  }

  Future<String> _deviceId() async {
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getString(_deviceIdKey);
    if (saved != null && saved.trim().isNotEmpty) {
      return saved;
    }
    final random = Random.secure();
    final bytes = List<int>.generate(16, (_) => random.nextInt(256));
    final id = [
      DateTime.now().microsecondsSinceEpoch.toRadixString(16),
      ...bytes.map((byte) => byte.toRadixString(16).padLeft(2, '0')),
    ].join();
    await prefs.setString(_deviceIdKey, id);
    return id;
  }

  Future<void> _setActiveDevice(String userId, String deviceId) {
    return client
        .from('users')
        .update({'active_device_id': deviceId})
        .eq('id', userId);
  }

  Future<void> sendPasswordResetOtp({required String phone}) async {
    try {
      await client.functions.invoke(
        'otp',
        body: {
          'action': 'request',
          'phone': phone.trim(),
          'lang': 'ar',
          'purpose': 'password_reset',
        },
      );
    } on FunctionException catch (error) {
      throw _functionAppException(error);
    }
  }

  /// Free account from the redesigned signup: starts `pending` and becomes
  /// `active` when the phone code is verified (otp function, purpose signup).
  Future<void> registerFreeStudent({
    required String name,
    required String phone,
    required String password,
    required String level,
  }) async {
    final existing = _list(
      await client
          .from('users')
          .select('id')
          .eq('phone', phone.trim())
          .limit(1),
    );
    if (existing.isNotEmpty) {
      throw const SupabaseAppException('رقم الهاتف مسجل مسبقاً.');
    }
    await client.from('users').insert({
      'name': name.trim(),
      'phone': phone.trim(),
      'password': password,
      'role': 'student',
      'status': 'pending',
      'level': level,
    });
    await requestOtp(phone: phone, purpose: 'signup');
  }

  Future<void> requestOtp({
    required String phone,
    required String purpose,
  }) async {
    try {
      await client.functions.invoke(
        'otp',
        body: {
          'action': 'request',
          'phone': phone.trim(),
          'lang': 'ar',
          'purpose': purpose,
        },
      );
    } on FunctionException catch (error) {
      throw _functionAppException(error);
    }
  }

  Future<void> verifyOtp({
    required String phone,
    required String code,
    required String purpose,
  }) async {
    try {
      await client.functions.invoke(
        'otp',
        body: {
          'action': 'verify',
          'phone': phone.trim(),
          'code': code.trim(),
          'purpose': purpose,
        },
      );
    } on FunctionException catch (error) {
      throw _functionAppException(error);
    }
  }

  Future<void> resetPasswordWithCode({
    required String phone,
    required String code,
    required String newPassword,
  }) async {
    try {
      await client.functions.invoke(
        'reset-password',
        body: {
          'phone': phone.trim(),
          'code': code.trim(),
          'password': newPassword,
        },
      );
    } on FunctionException catch (error) {
      throw _functionAppException(error);
    }
  }

  SupabaseAppException _functionAppException(FunctionException error) {
    final details = error.details;
    if (details is Map && details['error'] is String) {
      return SupabaseAppException(details['error'] as String);
    }
    if (details is Map && details['message'] is String) {
      return SupabaseAppException(details['message'] as String);
    }
    return const SupabaseAppException('حدث خطأ غير متوقع. حاول مرة أخرى.');
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
        'adminAccess': _decodeJsonList(values['adminAccess']),
        'paymentMethods': await paymentMethods(),
      },
    };
  }

  Future<Map<String, dynamic>> updateSettings({
    String? paymentNumber,
    String? paymentAmount,
    List<Map<String, dynamic>>? expenses,
    List<Map<String, dynamic>>? payments,
    List<Map<String, dynamic>>? adminAccess,
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
    if (adminAccess != null) {
      await _upsertSetting('adminAccess', jsonEncode(adminAccess));
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
    DateTime? subscriptionExpiresAt,
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
          if (subscriptionExpiresAt != null)
            'subscription_expires_at': subscriptionExpiresAt
                .toUtc()
                .toIso8601String(),
        })
        .select()
        .single();
    return {'user': _userPayload(_map(row))};
  }

  Future<Map<String, dynamic>> createAdmin({
    required String name,
    required String phone,
    required String password,
  }) async {
    final row = await client
        .from('users')
        .insert({
          'name': name.trim(),
          'phone': phone.trim(),
          'password': password,
          'role': 'admin',
          'status': 'active',
        })
        .select()
        .single();
    return {'user': _userPayload(_map(row))};
  }

  Future<void> updateAdminAccess({
    required String uid,
    required String adminType,
    required List<String> managedCourseIds,
  }) {
    return client
        .from('users')
        .update({
          'admin_type': adminType,
          'managed_course_ids': managedCourseIds,
        })
        .eq('id', uid)
        .eq('role', 'admin');
  }

  Future<void> updateAccountStatus(
    String uid,
    String status, {
    DateTime? subscriptionExpiresAt,
  }) {
    return client
        .from('users')
        .update({
          'status': status,
          if (subscriptionExpiresAt != null)
            'subscription_expires_at': subscriptionExpiresAt
                .toUtc()
                .toIso8601String(),
        })
        .eq('id', uid);
  }

  Future<void> updateStudentSubscription(
    String uid, {
    required DateTime subscriptionExpiresAt,
    required String paymentAmount,
  }) {
    return client
        .from('users')
        .update({
          'status': 'active',
          'payment_amount': paymentAmount.trim(),
          'subscription_expires_at': subscriptionExpiresAt
              .toUtc()
              .toIso8601String(),
        })
        .eq('id', uid);
  }

  Future<void> deleteUserAccount(String uid) {
    return client.from('users').delete().eq('id', uid);
  }

  Future<void> createCourse({
    required String title,
    required String classId,
    required String description,
    required String price,
    required int renewalMonths,
    required List<Map<String, String>> subjects,
  }) {
    return client.from('courses').insert({
      'title': title.trim(),
      'class_id': classId,
      'description': description.trim(),
      'price': price.trim(),
      'renewal_months': renewalMonths.clamp(1, 120),
      'subjects': subjects.map((item) => item['name'] ?? '').toList(),
      'subject_details': subjects,
    });
  }

  Future<void> updateCourseRenewalMonths({
    required String courseId,
    required int renewalMonths,
  }) {
    return client
        .from('courses')
        .update({'renewal_months': renewalMonths.clamp(1, 120)})
        .eq('id', courseId);
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
      'adminType': row['admin_type'],
      'managedCourseIds': row['managed_course_ids'],
      'paymentProofUrl': row['payment_proof_url'],
      'paymentSenderPhone': row['payment_sender_phone'],
      'activeDeviceId': row['active_device_id'],
      'paymentAmount': row['payment_amount'],
      'subscriptionExpiresAt': row['subscription_expires_at'],
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
      'renewalMonths': row['renewal_months'],
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
