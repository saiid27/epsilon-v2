import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

class ApiException implements Exception {
  const ApiException(this.message);

  final String message;

  @override
  String toString() => message;
}

class ApiRepository {
  ApiRepository({String? baseUrl})
    : baseUrl =
          baseUrl ??
          const String.fromEnvironment('EPSILON_API_URL', defaultValue: '');

  final String baseUrl;
  bool get hasBaseUrl => baseUrl.trim().isNotEmpty;
  static const _tokenKey = 'epsilon_api_token';
  String? _token;

  Future<void> initialize() async {
    final prefs = await SharedPreferences.getInstance();
    _token = prefs.getString(_tokenKey);
  }

  Future<Map<String, dynamic>?> currentUser() async {
    if (_token == null) {
      return null;
    }
    try {
      final data = await get('/api/me');
      return data['user'] as Map<String, dynamic>?;
    } on Object {
      await signOut();
      return null;
    }
  }

  Future<Map<String, dynamic>> signIn({
    required String phone,
    required String password,
  }) async {
    final data = await post('/api/auth/login', {
      'identifier': phone.trim(),
      'phone': phone.trim(),
      'password': password,
    }, authenticated: false);
    final token = data['token'] as String?;
    if (token == null || token.isEmpty) {
      throw const ApiException('Login did not return a token.');
    }
    _token = token;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_tokenKey, token);
    return data['user'] as Map<String, dynamic>;
  }

  Future<void> signOut() async {
    _token = null;
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_tokenKey);
  }

  Future<Map<String, dynamic>> get(String path) async {
    final response = await http.get(_uri(path), headers: _headers());
    return _decode(response);
  }

  Future<Map<String, dynamic>> post(
    String path,
    Map<String, dynamic> body, {
    bool authenticated = true,
  }) async {
    final response = await http.post(
      _uri(path),
      headers: _headers(authenticated: authenticated),
      body: jsonEncode(body),
    );
    return _decode(response);
  }

  Future<Map<String, dynamic>> patch(
    String path,
    Map<String, dynamic> body,
  ) async {
    final response = await http.patch(
      _uri(path),
      headers: _headers(),
      body: jsonEncode(body),
    );
    return _decode(response);
  }

  Future<Map<String, dynamic>> delete(String path) async {
    final response = await http.delete(_uri(path), headers: _headers());
    return _decode(response);
  }

  Future<Map<String, dynamic>> registerStudent({
    required String name,
    required String phone,
    required String password,
    required String courseId,
    required List<String> selectedSubjects,
    required String paymentSenderPhone,
  }) {
    return post('/api/auth/register-student', {
      'name': name,
      'phone': phone,
      'password': password,
      'courseId': courseId,
      'selectedSubjects': selectedSubjects,
      'paymentSenderPhone': paymentSenderPhone,
    }, authenticated: false);
  }

  Future<Map<String, dynamic>> settings() {
    return get('/api/settings');
  }

  Future<Map<String, dynamic>> updateSettings({
    String? paymentNumber,
    String? paymentAmount,
  }) {
    final body = <String, dynamic>{};
    if (paymentNumber != null) {
      body['paymentNumber'] = paymentNumber;
    }
    if (paymentAmount != null) {
      body['paymentAmount'] = paymentAmount;
    }
    return patch('/api/settings', body);
  }

  Future<Map<String, dynamic>> createPaymentMethod({
    required String name,
    required String accountNumber,
    required String imageUrl,
  }) {
    return post('/api/payment-methods', {
      'name': name,
      'accountNumber': accountNumber,
      'imageUrl': imageUrl,
    });
  }

  Future<Map<String, dynamic>> deletePaymentMethod(String id) {
    return delete('/api/payment-methods/$id');
  }

  Future<Map<String, dynamic>> createUser({
    required String name,
    required String phone,
    required String password,
    required String role,
    required String courseId,
    String? subject,
  }) {
    return post('/api/admin/users', {
      'name': name,
      'phone': phone,
      'password': password,
      'role': role,
      'courseId': courseId,
      'classId': courseId,
      'level': courseId,
      'subject': subject,
      'status': role == 'student' ? 'active' : 'active',
    });
  }

  Future<void> updateAccountStatus(String uid, String status) async {
    await patch('/api/users/$uid/status', {'status': status});
  }

  Future<void> deleteUserAccount(String uid) async {
    await delete('/api/users/$uid');
  }

  Future<void> createCourse({
    required String title,
    required String classId,
    required String description,
    required String price,
    required List<Map<String, String>> subjects,
  }) async {
    await post('/api/courses', {
      'title': title,
      'classId': classId,
      'description': description,
      'price': price,
      'subjects': subjects,
    });
  }

  Future<void> deleteCourse(String courseId) async {
    await delete('/api/courses/$courseId');
  }

  Future<void> createLesson({
    required String title,
    required String url,
    required String classId,
    required String courseId,
    required String subject,
  }) async {
    await post('/api/lessons', {
      'title': title,
      'url': url,
      'classId': classId,
      'courseId': courseId,
      'level': classId,
      'subject': subject,
    });
  }

  Future<void> updateLesson({
    required String lessonId,
    required String title,
    required String url,
  }) async {
    await patch('/api/lessons/$lessonId', {'title': title, 'url': url});
  }

  Future<void> deleteLesson(String lessonId) async {
    await delete('/api/lessons/$lessonId');
  }

  Future<void> addNotification({
    required String title,
    required String body,
  }) async {
    await post('/api/notifications', {'title': title, 'body': body});
  }

  Future<void> updateNotification({
    required String id,
    required String title,
    required String body,
  }) async {
    await patch('/api/notifications/$id', {'title': title, 'body': body});
  }

  Future<void> deleteNotification(String id) async {
    await delete('/api/notifications/$id');
  }

  Future<Map<String, dynamic>> createGuestContent({
    required String contentType,
    required String title,
    required String url,
    required String description,
    required String courseId,
  }) {
    return post('/api/guest-content', {
      'contentType': contentType,
      'title': title,
      'url': url,
      'description': description,
      'courseId': courseId,
    });
  }

  Future<Map<String, dynamic>> updateGuestContent({
    required String id,
    required String title,
    required String url,
    required String description,
    required String courseId,
  }) {
    return patch('/api/guest-content/$id', {
      'title': title,
      'url': url,
      'description': description,
      'courseId': courseId,
    });
  }

  Future<void> deleteGuestContent(String id) async {
    await delete('/api/guest-content/$id');
  }

  Future<List<Map<String, dynamic>>> searchNationalResults({
    required String examType,
    required String query,
    String? center,
  }) async {
    final centerQuery = center == null || center.trim().isEmpty
        ? ''
        : '&center=${Uri.encodeQueryComponent(center.trim())}';
    final data = await get(
      '/api/results/$examType?q=${Uri.encodeQueryComponent(query)}$centerQuery',
    );
    return (data['results'] as List? ?? const [])
        .whereType<Map>()
        .map((item) => Map<String, dynamic>.from(item))
        .toList();
  }

  Future<List<String>> nationalResultCenters({required String examType}) async {
    final data = await get('/api/results/$examType/centers');
    return (data['centers'] as List? ?? const [])
        .map((item) => '$item'.trim())
        .where((item) => item.isNotEmpty)
        .toList();
  }

  Future<List<Map<String, dynamic>>> offers() async {
    final data = await get('/api/offers');
    return (data['offers'] as List? ?? const [])
        .whereType<Map>()
        .map((item) => Map<String, dynamic>.from(item))
        .toList();
  }

  Future<Map<String, dynamic>> offerTextSection() async {
    final data = await get('/api/offers');
    final section = data['textSection'];
    return section is Map ? Map<String, dynamic>.from(section) : const {};
  }

  Future<int> uploadNationalResults({
    required String examType,
    required String filePath,
    required String fileName,
  }) async {
    final request = http.MultipartRequest(
      'POST',
      _uri('/api/results/$examType/upload'),
    );
    if (_token != null) {
      request.headers[HttpHeaders.authorizationHeader] = 'Bearer $_token';
    }
    request.files.add(
      await http.MultipartFile.fromPath('file', filePath, filename: fileName),
    );
    final streamed = await request.send();
    final response = await http.Response.fromStream(streamed);
    final data = _decode(response);
    return (data['rowsImported'] as num?)?.toInt() ?? 0;
  }

  Uri _uri(String path) {
    final root = baseUrl.endsWith('/')
        ? baseUrl.substring(0, baseUrl.length - 1)
        : baseUrl;
    return Uri.parse('$root$path');
  }

  Map<String, String> _headers({bool authenticated = true}) {
    final headers = {HttpHeaders.contentTypeHeader: 'application/json'};
    if (authenticated && _token != null) {
      headers[HttpHeaders.authorizationHeader] = 'Bearer $_token';
    }
    return headers;
  }

  Map<String, dynamic> _decode(http.Response response) {
    final decoded = response.body.isEmpty
        ? <String, dynamic>{}
        : jsonDecode(utf8.decode(response.bodyBytes)) as Map<String, dynamic>;
    if (response.statusCode < 200 || response.statusCode >= 300) {
      final message =
          decoded['message'] as String? ??
          decoded['error'] as String? ??
          'Request failed with status ${response.statusCode}.';
      throw ApiException(message);
    }
    return decoded;
  }
}
