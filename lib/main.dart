import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'dart:ui' show ImageFilter;

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:share_plus/share_plus.dart' as share;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:video_player/video_player.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:webview_flutter_android/webview_flutter_android.dart';
import 'package:webview_flutter_wkwebview/webview_flutter_wkwebview.dart';

import 'data/learn.dart';
import 'supabase_repository.dart';
import 'supabase_config.dart';
import 'ui/eps_theme.dart';
import 'ui/eps_widgets.dart';

part 'screens/auth.dart';
part 'screens/onboarding.dart';
part 'screens/forgot_password.dart';
part 'screens/student_home.dart';
part 'screens/my_subjects.dart';
part 'screens/lesson_live.dart';
part 'screens/quizzes.dart';
part 'screens/checkout.dart';
part 'screens/profile.dart';
part 'screens/admin.dart';

const epsilonBlue = Eps.blue;
const epsilonTeal = Eps.green;
const epsilonGold = Eps.orange;
const epsilonInk = Eps.ink;
const epsilonMuted = Eps.muted;
const epsilonSurface = Color(0xFFFFFFFF);
const epsilonSoft = Eps.bg;
const epsilonLine = Eps.line;

class PickedNativeFile {
  const PickedNativeFile({required this.path, required this.name});

  final String path;
  final String name;
}

class NativeFilePicker {
  const NativeFilePicker._();

  static const MethodChannel _channel = MethodChannel('epsilon/file_picker');

  static Future<PickedNativeFile?> pickImage() => _pickFile('image');

  static Future<PickedNativeFile?> pickExcel() => _pickFile('excel');

  static Future<PickedNativeFile?> _pickFile(String type) async {
    final result = await _channel.invokeMapMethod<String, Object?>(
      'pickFile',
      <String, Object?>{'type': type},
    );
    final path = result?['path']?.toString();
    if (path == null || path.trim().isEmpty) {
      return null;
    }
    final name = result?['name']?.toString().trim();
    return PickedNativeFile(
      path: path,
      name: name == null || name.isEmpty ? path.split('/').last : name,
    );
  }
}

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Supabase.initialize(
    url: SupabaseConfig.url,
    publishableKey: SupabaseConfig.publishableKey,
  );

  final backendStatus = await BackendBootstrap.initialize();
  runApp(EpsilonApp(backendStatus: backendStatus));
}

class BackendBootstrap {
  const BackendBootstrap({required this.isReady, this.errorMessage});

  final bool isReady;
  final String? errorMessage;

  static Future<BackendBootstrap> initialize() async {
    unawaited(
      PushNotifications.initialize().catchError((Object error) {
        debugPrint('Local notifications initialization skipped: $error');
      }),
    );
    try {
      final repository = SupabaseRepository();
      if (await repository.healthCheck()) {
        return const BackendBootstrap(isReady: true);
      }
      return const BackendBootstrap(
        isReady: false,
        errorMessage: 'Supabase غير جاهز. شغّل ملف SQL أولاً.',
      );
    } on Object catch (error) {
      return BackendBootstrap(isReady: false, errorMessage: error.toString());
    }
  }
}

class PushNotifications {
  const PushNotifications._();

  static const AndroidNotificationChannel _androidChannel =
      AndroidNotificationChannel(
        'epsilon_notifications',
        'إشعارات Epsilon',
        description: 'إشعارات الإدارة والدروس الجديدة',
        importance: Importance.high,
        playSound: true,
      );

  static final FlutterLocalNotificationsPlugin _localNotifications =
      FlutterLocalNotificationsPlugin();

  static Future<void> initialize() async {
    const androidSettings = AndroidInitializationSettings(
      '@mipmap/ic_launcher',
    );
    const iosSettings = DarwinInitializationSettings(
      requestAlertPermission: false,
      requestBadgePermission: false,
      requestSoundPermission: false,
    );

    await _localNotifications.initialize(
      settings: const InitializationSettings(
        android: androidSettings,
        iOS: iosSettings,
      ),
    );

    final androidNotifications = _localNotifications
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >();
    await androidNotifications?.createNotificationChannel(_androidChannel);
    await androidNotifications?.requestNotificationsPermission();

    final iosNotifications = _localNotifications
        .resolvePlatformSpecificImplementation<
          IOSFlutterLocalNotificationsPlugin
        >();
    await iosNotifications?.requestPermissions(
      alert: true,
      badge: true,
      sound: true,
    );
  }

  static Future<void> showLocalNotification({
    required String id,
    required String title,
    required String body,
  }) async {
    await _localNotifications.show(
      id: id.hashCode,
      title: title,
      body: body,
      notificationDetails: NotificationDetails(
        android: AndroidNotificationDetails(
          _androidChannel.id,
          _androidChannel.name,
          channelDescription: _androidChannel.description,
          importance: Importance.high,
          priority: Priority.high,
          playSound: true,
        ),
        iOS: const DarwinNotificationDetails(
          presentAlert: true,
          presentBadge: true,
          presentSound: true,
        ),
      ),
    );
  }
}

String friendlyApiError(Object error) {
  if (error is SupabaseAppException) {
    return error.message;
  }

  final rawText = error.toString();
  if (rawText.startsWith('SupabaseAppException: ')) {
    return rawText.replaceFirst('SupabaseAppException: ', '');
  }

  final text = error.toString().toLowerCase();

  if (text.contains('unauthenticated') || text.contains('not-signed-in')) {
    return 'انتهت جلسة الإدارة. سجل الخروج ثم ادخل من جديد وحاول مرة أخرى.';
  }
  if (text.contains('permission-denied')) {
    return 'هذا الحساب لا يملك صلاحية الإدارة.';
  }
  if (text.contains('phone-already-exists') ||
      text.contains('phone-already-in-use') ||
      text.contains('email-already-exists') ||
      text.contains('email-already-in-use')) {
    return 'رقم الهاتف مستخدم مسبقا.';
  }
  if (text.contains('invalid-phone') || text.contains('invalid-email')) {
    return 'رقم الهاتف غير صحيح.';
  }
  if (text.contains('weak-password')) {
    return 'كلمة المرور ضعيفة. اختر كلمة مرور أقوى.';
  }
  if (text.contains('network') || text.contains('unavailable')) {
    return 'تحقق من الاتصال بالإنترنت ثم حاول مرة أخرى.';
  }

  return 'حدث خطأ أثناء العملية. حاول مرة أخرى.';
}

enum UserRole { admin, teacher, student }

enum AdminType { developer, generalManager, schoolManager }

enum AccountStatus { pending, active, blocked, rejected }

class AppUser {
  AppUser({
    required this.id,
    required this.name,
    required this.phone,
    required this.password,
    required this.role,
    required this.status,
    this.classId,
    this.courseId,
    this.subject,
    List<String>? selectedSubjects,
    this.adminType = AdminType.schoolManager,
    List<String>? managedCourseIds,
    this.paymentProofPath,
    this.paymentSenderPhone,
    this.activeDeviceId,
    this.paymentAmount = '',
    this.subscriptionExpiresAt,
  }) : selectedSubjects = selectedSubjects ?? const [],
       managedCourseIds = managedCourseIds ?? const [];

  final String id;
  final String name;
  final String phone;
  final String password;
  final UserRole role;
  AccountStatus status;
  String? classId;
  String? courseId;
  String? subject;
  List<String> selectedSubjects;
  AdminType adminType;
  List<String> managedCourseIds;
  String? paymentProofPath;
  String? paymentSenderPhone;
  String? activeDeviceId;
  String paymentAmount;
  DateTime? subscriptionExpiresAt;

  bool get isSubscriptionExpired =>
      role == UserRole.student &&
      status == AccountStatus.active &&
      subscriptionExpiresAt != null &&
      subscriptionExpiresAt!.isBefore(DateTime.now());
}

class SchoolClass {
  const SchoolClass({
    required this.id,
    required this.name,
    required this.level,
  });

  final String id;
  final String name;
  final String level;
}

class Course {
  Course({
    required this.id,
    required this.title,
    required this.classId,
    this.description = 'دروس وتمارين وملخصات منظمة للطلاب',
    this.price = '',
    List<String>? subjects,
    Map<String, String>? subjectTeachers,
    Map<String, String>? subjectPrices,
    this.renewalMonths = 1,
    this.isActive = true,
  }) : subjects = subjects ?? const ['الرياضيات', 'الفيزياء', 'الكيمياء'],
       subjectTeachers = subjectTeachers ?? const {},
       subjectPrices = subjectPrices ?? const {};

  final String id;
  final String title;
  final String classId;
  String description;
  String price;
  List<String> subjects;
  Map<String, String> subjectTeachers;
  Map<String, String> subjectPrices;
  int renewalMonths;
  bool isActive;
}

class Lesson {
  Lesson({
    required this.id,
    required this.title,
    required this.url,
    required this.teacherId,
    required this.classId,
    required this.courseId,
    required this.subject,
    required this.createdAt,
    this.isPublished = true,
  });

  final String id;
  String title;
  String url;
  final String teacherId;
  String classId;
  String courseId;
  final String subject;
  final DateTime createdAt;
  bool isPublished;
}

class GuestContentItem {
  GuestContentItem({
    required this.id,
    required this.title,
    required this.url,
    this.description = '',
    this.courseId,
    required this.createdAt,
  });

  final String id;
  String title;
  String url;
  String description;
  String? courseId;
  final DateTime createdAt;
}

class AppNotification {
  const AppNotification({
    required this.id,
    required this.title,
    required this.body,
    required this.createdAt,
  });

  final String id;
  final String title;
  final String body;
  final DateTime createdAt;
}

class NationalExamResult {
  const NationalExamResult({
    required this.id,
    required this.examType,
    required this.candidateNumber,
    required this.fullName,
    required this.birthPlace,
    required this.birthDate,
    required this.wilaya,
    required this.moughataa,
    required this.centerName,
    required this.score,
    required this.decision,
    required this.rank,
    required this.rawData,
  });

  final String id;
  final String examType;
  final String candidateNumber;
  final String fullName;
  final String birthPlace;
  final String birthDate;
  final String wilaya;
  final String moughataa;
  final String centerName;
  final String score;
  final String decision;
  final String rank;
  final Map<String, dynamic> rawData;

  double? get numericScore {
    final normalized = score.trim().replaceAll(',', '.');
    return double.tryParse(normalized);
  }

  bool get hasConcoursPassingScore {
    return examType == 'concours' && (numericScore ?? 0) >= 85;
  }

  String get series {
    for (final key in [
      'SERIE',
      'Série',
      'Serie',
      'serie',
      'Type',
      'type',
      'الشعبة',
    ]) {
      final value = rawData[key];
      if (value != null && value.toString().trim().isNotEmpty) {
        return value.toString().trim();
      }
    }
    return '';
  }
}

class OfferSlide {
  const OfferSlide({
    required this.id,
    required this.title,
    required this.imageUrl,
    required this.durationSeconds,
  });

  final String id;
  final String title;
  final String imageUrl;
  final int durationSeconds;
}

class OfferTextSection {
  const OfferTextSection({
    required this.title,
    required this.body,
    required this.active,
  });

  final String title;
  final String body;
  final bool active;

  bool get shouldShow => active && body.trim().isNotEmpty;
}

class PaymentMethod {
  const PaymentMethod({
    required this.id,
    required this.name,
    required this.accountNumber,
    this.imageUrl = '',
  });

  final String id;
  final String name;
  final String accountNumber;
  final String imageUrl;
}

class ExpenseItem {
  const ExpenseItem({
    required this.id,
    required this.title,
    required this.amount,
    required this.category,
    required this.createdAt,
    this.courseId,
    this.courseTitle,
    this.note = '',
  });

  final String id;
  final String title;
  final String amount;
  final String category;
  final String note;
  final DateTime createdAt;
  final String? courseId;
  final String? courseTitle;

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'amount': amount,
      'category': category,
      'note': note,
      'createdAt': createdAt.toIso8601String(),
      if (courseId != null) 'courseId': courseId,
      if (courseTitle != null) 'courseTitle': courseTitle,
    };
  }
}

class PaymentRecord {
  const PaymentRecord({
    required this.id,
    required this.studentName,
    required this.amount,
    required this.type,
    required this.createdAt,
    this.courseId,
    this.courseTitle,
  });

  final String id;
  final String studentName;
  final String amount;
  final String type;
  final DateTime createdAt;
  final String? courseId;
  final String? courseTitle;

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'studentName': studentName,
      'amount': amount,
      'type': type,
      'createdAt': createdAt.toIso8601String(),
      if (courseId != null) 'courseId': courseId,
      if (courseTitle != null) 'courseTitle': courseTitle,
    };
  }
}

class CourseIncomeSummary {
  const CourseIncomeSummary({
    required this.course,
    required this.payments,
    required this.total,
  });

  final Course course;
  final List<PaymentRecord> payments;
  final double total;
}

class AdminAccessConfig {
  const AdminAccessConfig({
    required this.adminType,
    required this.managedCourseIds,
  });

  final AdminType adminType;
  final List<String> managedCourseIds;

  Map<String, dynamic> toJson(String userId) {
    return {
      'userId': userId,
      'adminType': adminTypeValue(adminType),
      'managedCourseIds': managedCourseIds,
    };
  }
}

class SchoolStore extends ChangeNotifier {
  SchoolStore({required this.backendEnabled}) {
    unawaited(_loadReadNotifications());
    if (backendEnabled) {
      _repository = SupabaseRepository();
      unawaited(_bindApi());
    } else {
      _seed();
    }
  }

  final bool backendEnabled;
  dynamic _repository;
  final List<StreamSubscription<Object?>> _subscriptions = [];
  StreamSubscription<Object?>? _usersSubscription;
  StreamSubscription<Object?>? _currentUserSubscription;
  StreamSubscription<Object?>? _coursesSubscription;
  StreamSubscription<Object?>? _lessonsSubscription;
  StreamSubscription<Object?>? _guestVideosSubscription;
  StreamSubscription<Object?>? _archiveFilesSubscription;
  Timer? _notificationPollTimer;
  final List<SchoolClass> classes = [];
  final List<Course> courses = [];
  final List<Lesson> lessons = [];
  final List<GuestContentItem> guestVideos = [];
  final List<GuestContentItem> archiveFiles = [];
  final List<PaymentMethod> paymentMethods = [];
  final List<ExpenseItem> expenses = [];
  final List<PaymentRecord> payments = [];
  final List<AppUser> users = [];
  final List<AppNotification> notifications = [];
  final Set<String> readNotificationIds = {};
  final Map<String, AdminAccessConfig> adminAccessByUserId = {};
  String paymentNumber = '22334455';
  String paymentAmount = 'غير محدد';
  ThemeMode themeMode = ThemeMode.light;
  String languageCode = 'ar';
  AppUser? currentUser;
  bool isLoading = false;
  bool _notificationsLoadedOnce = false;
  String? lastError;

  static const _readNotificationsKey = 'epsilon_read_notification_ids';

  int get unreadNotificationCount => notifications
      .where((notification) => !readNotificationIds.contains(notification.id))
      .length;

  Future<void> _loadReadNotifications() async {
    final prefs = await SharedPreferences.getInstance();
    readNotificationIds
      ..clear()
      ..addAll(prefs.getStringList(_readNotificationsKey) ?? const []);
    notifyListeners();
  }

  Future<void> markNotificationsRead() async {
    if (notifications.isEmpty) {
      return;
    }

    readNotificationIds.addAll(
      notifications.map((notification) => notification.id),
    );
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(
      _readNotificationsKey,
      readNotificationIds.toList(),
    );
    notifyListeners();
  }

  String get defaultClassId {
    if (classes.isEmpty) {
      if (backendEnabled) {
        return 'default';
      }
      createClass(name: 'عام', level: 'كل المستويات');
    }
    return classes.first.id;
  }

  Future<void> _bindApi() async {
    try {
      final repository = _repository as SupabaseRepository;
      await repository.initialize();
      await _loadPublicApiData();
      final userData = await repository.currentUser();
      if (userData != null) {
        currentUser = _userFromApi(userData);
        users
          ..clear()
          ..add(currentUser!);
        _applyAdminAccessToUsers();
        await _loadSignedInApiData();
        _startNotificationPolling();
      }
      notifyListeners();
    } on Object catch (error) {
      _rememberError(error);
      _seed();
    }
  }

  Future<void> _loadPublicApiData() async {
    final repository = _repository as SupabaseRepository;
    final settingsData = await repository.settings();
    _applySettingsFromApi(settingsData['settings']);

    final classesData = await repository.get('/api/classes');
    classes
      ..clear()
      ..addAll(
        (classesData['classes'] as List? ?? const []).whereType<Map>().map(
          (item) => _classFromApi(Map<String, dynamic>.from(item)),
        ),
      );

    final coursesData = await repository.get('/api/courses');
    courses
      ..clear()
      ..addAll(
        (coursesData['courses'] as List? ?? const []).whereType<Map>().map(
          (item) => _courseFromApi(Map<String, dynamic>.from(item)),
        ),
      );

    final guestData = await repository.get('/api/guest-videos');
    guestVideos
      ..clear()
      ..addAll(
        (guestData['items'] as List? ?? const []).whereType<Map>().map(
          (item) => _guestContentFromApi(Map<String, dynamic>.from(item)),
        ),
      );

    final archiveData = await repository.get('/api/archive-files');
    archiveFiles
      ..clear()
      ..addAll(
        (archiveData['items'] as List? ?? const []).whereType<Map>().map(
          (item) => _guestContentFromApi(Map<String, dynamic>.from(item)),
        ),
      );
  }

  void _applySettingsFromApi(Object? settings) {
    if (settings is Map) {
      final number = settings['paymentNumber'];
      if (number is String && number.trim().isNotEmpty) {
        paymentNumber = number;
      }
      final amount = settings['paymentAmount'];
      if (amount is String && amount.trim().isNotEmpty) {
        paymentAmount = amount;
      }
      final methods = settings['paymentMethods'];
      paymentMethods
        ..clear()
        ..addAll(_paymentMethodsFromApi(methods));
      if (paymentMethods.isEmpty && paymentNumber.trim().isNotEmpty) {
        paymentMethods.add(
          PaymentMethod(
            id: 'default',
            name: 'طريقة الدفع المتاحة',
            accountNumber: paymentNumber,
          ),
        );
      }
      final expenseItems = settings['expenses'];
      expenses
        ..clear()
        ..addAll(_expensesFromApi(expenseItems));
      final paymentItems = settings['payments'];
      payments
        ..clear()
        ..addAll(_paymentsFromApi(paymentItems));
      final adminAccessItems = settings['adminAccess'];
      adminAccessByUserId
        ..clear()
        ..addAll(_adminAccessFromApi(adminAccessItems));
      _applyAdminAccessToUsers();
      notifyListeners();
    }
  }

  Map<String, AdminAccessConfig> _adminAccessFromApi(Object? data) {
    if (data is! List) {
      return const {};
    }
    final access = <String, AdminAccessConfig>{};
    for (final item in data.whereType<Map>()) {
      final map = Map<String, dynamic>.from(item);
      final userId = '${map['userId'] ?? ''}'.trim();
      if (userId.isEmpty) {
        continue;
      }
      access[userId] = AdminAccessConfig(
        adminType: _adminTypeFromString('${map['adminType'] ?? ''}'),
        managedCourseIds: stringListFromDynamic(map['managedCourseIds']),
      );
    }
    return access;
  }

  void _applyAdminAccessToUsers() {
    for (final user in users) {
      if (user.role != UserRole.admin) {
        continue;
      }
      final access = adminAccessByUserId[user.id];
      if (access != null) {
        user.adminType = access.adminType;
        user.managedCourseIds = access.managedCourseIds;
      }
      if (user.phone.trim() == '34605765') {
        user.adminType = AdminType.developer;
        user.managedCourseIds = const [];
      }
    }
    final currentId = currentUser?.id;
    if (currentId != null) {
      currentUser = users.where((user) => user.id == currentId).firstOrNull;
    }
  }

  List<ExpenseItem> _expensesFromApi(Object? data) {
    if (data is! List) {
      return const [];
    }
    return data
        .whereType<Map>()
        .map((item) {
          final map = Map<String, dynamic>.from(item);
          return ExpenseItem(
            id: '${map['id'] ?? 'expense-${DateTime.now().microsecondsSinceEpoch}'}',
            title: '${map['title'] ?? ''}'.trim(),
            amount: '${map['amount'] ?? ''}'.trim(),
            category: '${map['category'] ?? 'عام'}'.trim(),
            note: '${map['note'] ?? ''}'.trim(),
            createdAt:
                DateTime.tryParse('${map['createdAt'] ?? ''}')?.toLocal() ??
                DateTime.now(),
            courseId: '${map['courseId'] ?? ''}'.trim().isEmpty
                ? null
                : '${map['courseId']}'.trim(),
            courseTitle: '${map['courseTitle'] ?? ''}'.trim().isEmpty
                ? null
                : '${map['courseTitle']}'.trim(),
          );
        })
        .where((item) => item.title.isNotEmpty)
        .toList()
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
  }

  List<PaymentRecord> _paymentsFromApi(Object? data) {
    if (data is! List) {
      return const [];
    }
    return data
        .whereType<Map>()
        .map((item) {
          final map = Map<String, dynamic>.from(item);
          return PaymentRecord(
            id: '${map['id'] ?? 'payment-${DateTime.now().microsecondsSinceEpoch}'}',
            studentName: '${map['studentName'] ?? ''}'.trim(),
            amount: '${map['amount'] ?? ''}'.trim(),
            type: '${map['type'] ?? 'تسجيل'}'.trim(),
            createdAt:
                DateTime.tryParse('${map['createdAt'] ?? ''}')?.toLocal() ??
                DateTime.now(),
            courseId: '${map['courseId'] ?? ''}'.trim().isEmpty
                ? null
                : '${map['courseId']}'.trim(),
            courseTitle: '${map['courseTitle'] ?? ''}'.trim().isEmpty
                ? null
                : '${map['courseTitle']}'.trim(),
          );
        })
        .where((item) => item.amount.isNotEmpty)
        .toList()
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
  }

  double get totalPaymentsAmount => payments
      .map((payment) => priceNumberFromText(payment.amount) ?? 0)
      .fold<double>(0, (runningTotal, amount) => runningTotal + amount);

  List<PaymentRecord> get visiblePayments {
    final user = currentUser;
    if (user == null || user.role != UserRole.admin) {
      return const [];
    }
    if (user.adminType == AdminType.developer) {
      return payments;
    }
    final allowedCourseIds = adminManagedCourseIds(user);
    if (allowedCourseIds.isEmpty) {
      return const [];
    }
    return payments
        .where(
          (payment) =>
              payment.courseId != null &&
              allowedCourseIds.contains(payment.courseId),
        )
        .toList();
  }

  double get visiblePaymentsAmount => visiblePayments
      .map((payment) => priceNumberFromText(payment.amount) ?? 0)
      .fold<double>(0, (runningTotal, amount) => runningTotal + amount);

  double get totalExpensesAmount => expenses
      .map((expense) => priceNumberFromText(expense.amount) ?? 0)
      .fold<double>(0, (runningTotal, amount) => runningTotal + amount);

  List<ExpenseItem> get visibleExpenses {
    final user = currentUser;
    if (user == null || user.role != UserRole.admin) {
      return const [];
    }
    if (user.adminType == AdminType.developer) {
      return expenses;
    }
    final allowedCourseIds = adminManagedCourseIds(user);
    if (allowedCourseIds.isEmpty) {
      return const [];
    }
    return expenses
        .where(
          (expense) =>
              expense.courseId != null &&
              allowedCourseIds.contains(expense.courseId),
        )
        .toList();
  }

  double get visibleExpensesAmount => visibleExpenses
      .map((expense) => priceNumberFromText(expense.amount) ?? 0)
      .fold<double>(0, (runningTotal, amount) => runningTotal + amount);

  double get totalBoxAmount => totalPaymentsAmount - totalExpensesAmount;

  double get visibleBoxAmount {
    final user = currentUser;
    if (user?.adminType == AdminType.developer) {
      return totalBoxAmount;
    }
    return visiblePaymentsAmount - visibleExpensesAmount;
  }

  double courseIncomeAmount(String courseId) => payments
      .where((payment) => payment.courseId == courseId)
      .map((payment) => priceNumberFromText(payment.amount) ?? 0)
      .fold<double>(0, (runningTotal, amount) => runningTotal + amount);

  double courseExpenseAmount(String courseId) => expenses
      .where((expense) => expense.courseId == courseId)
      .map((expense) => priceNumberFromText(expense.amount) ?? 0)
      .fold<double>(0, (runningTotal, amount) => runningTotal + amount);

  double courseBoxAmount(String courseId) =>
      courseIncomeAmount(courseId) - courseExpenseAmount(courseId);

  List<PaymentMethod> _paymentMethodsFromApi(Object? data) {
    if (data is! List) {
      return const [];
    }
    return data
        .whereType<Map>()
        .map((item) {
          return PaymentMethod(
            id: '${item['id'] ?? ''}',
            name: '${item['name'] ?? 'طريقة دفع'}',
            accountNumber:
                '${item['accountNumber'] ?? item['account_number'] ?? ''}',
            imageUrl: '${item['imageUrl'] ?? item['image_url'] ?? ''}',
          );
        })
        .where((method) {
          return method.name.trim().isNotEmpty &&
              method.accountNumber.trim().isNotEmpty;
        })
        .toList();
  }

  Future<void> _loadSignedInApiData() async {
    final repository = _repository as SupabaseRepository;
    final user = currentUser;
    if (user == null) {
      return;
    }

    await _loadPublicApiData();

    if (user.role == UserRole.admin) {
      final usersData = await repository.get('/api/users');
      users
        ..clear()
        ..addAll(
          (usersData['users'] as List? ?? const []).whereType<Map>().map(
            (item) => _userFromApi(Map<String, dynamic>.from(item)),
          ),
        );
      _applyAdminAccessToUsers();
      currentUser = users
          .where((candidate) => candidate.id == user.id)
          .cast<AppUser?>()
          .firstOrNull;
    } else {
      final allowedCourseId = user.courseId ?? user.classId;
      if (allowedCourseId != null && allowedCourseId.trim().isNotEmpty) {
        final visibleCourses = courses
            .where(
              (course) =>
                  course.id == allowedCourseId ||
                  course.classId == allowedCourseId,
            )
            .toList();
        final visibleClasses = classes
            .where(
              (schoolClass) =>
                  schoolClass.id == allowedCourseId ||
                  schoolClass.level == allowedCourseId,
            )
            .toList();
        courses
          ..clear()
          ..addAll(visibleCourses);
        classes
          ..clear()
          ..addAll(visibleClasses);
      }
    }

    final lessonsData = await repository.get('/api/lessons');
    lessons
      ..clear()
      ..addAll(
        (lessonsData['lessons'] as List? ?? const []).whereType<Map>().map(
          (item) => _lessonFromApi(Map<String, dynamic>.from(item)),
        ),
      );

    final notificationsData = await repository.get('/api/notifications');
    _replaceNotificationsFromApi(notificationsData, alertNew: false);
  }

  void _replaceNotificationsFromApi(
    Map<String, dynamic> notificationsData, {
    required bool alertNew,
  }) {
    final previousIds = notifications
        .map((notification) => notification.id)
        .toSet();
    final incoming = (notificationsData['notifications'] as List? ?? const [])
        .whereType<Map>()
        .map((item) => _notificationFromApi(Map<String, dynamic>.from(item)))
        .toList();

    final shouldAlert =
        alertNew &&
        _notificationsLoadedOnce &&
        currentUser?.role == UserRole.student;
    AppNotification? newestNotification;
    if (shouldAlert) {
      for (final notification in incoming) {
        if (!previousIds.contains(notification.id) &&
            !readNotificationIds.contains(notification.id)) {
          newestNotification = notification;
          break;
        }
      }
    }

    notifications
      ..clear()
      ..addAll(incoming);
    _notificationsLoadedOnce = true;

    if (newestNotification != null) {
      unawaited(
        PushNotifications.showLocalNotification(
          id: newestNotification.id,
          title: newestNotification.title,
          body: newestNotification.body,
        ),
      );
      SystemSound.play(SystemSoundType.alert);
      HapticFeedback.mediumImpact();
    }
  }

  void _startNotificationPolling() {
    _notificationPollTimer?.cancel();
    if (currentUser == null) {
      return;
    }
    _notificationPollTimer = Timer.periodic(const Duration(seconds: 30), (_) {
      unawaited(_pollNotifications());
    });
  }

  Future<void> _pollNotifications() async {
    if (!backendEnabled || currentUser == null) {
      return;
    }
    try {
      final repository = _repository as SupabaseRepository;
      final notificationsData = await repository.get('/api/notifications');
      _replaceNotificationsFromApi(notificationsData, alertNew: true);
      notifyListeners();
    } on Object catch (error) {
      debugPrint('Notification polling skipped: $error');
    }
  }

  void _rememberError(Object error) {
    lastError = error.toString();
    notifyListeners();
  }

  AppUser _userFromApi(Map<String, dynamic> data) {
    return AppUser(
      id: '${data['id'] ?? ''}',
      name:
          (data['name'] as String?) ??
          (data['username'] as String?) ??
          'مستخدم',
      phone: (data['phone'] as String?) ?? (data['email'] as String?) ?? '',
      password: '',
      role: _roleFromString(data['role'] as String?),
      status: _statusFromString(data['status'] as String?),
      classId: data['classId'] as String? ?? data['level'] as String?,
      courseId: data['courseId'] as String? ?? data['level'] as String?,
      subject: data['subject'] as String?,
      selectedSubjects: stringListFromDynamic(data['selectedSubjects']),
      adminType: _adminTypeFromString(data['adminType'] as String?),
      managedCourseIds: stringListFromDynamic(data['managedCourseIds']),
      paymentProofPath: data['paymentProofUrl'] as String?,
      paymentSenderPhone: data['paymentSenderPhone'] as String?,
      activeDeviceId: data['activeDeviceId'] as String?,
      paymentAmount: data['paymentAmount'] == null
          ? ''
          : '${data['paymentAmount']}',
      subscriptionExpiresAt: _dateFromApiOrNull(data['subscriptionExpiresAt']),
    );
  }

  SchoolClass _classFromApi(Map<String, dynamic> data) {
    return SchoolClass(
      id: '${data['id'] ?? data['level'] ?? ''}',
      name: (data['name'] as String?) ?? 'عام',
      level: (data['level'] as String?) ?? '${data['id'] ?? ''}',
    );
  }

  Course _courseFromApi(Map<String, dynamic> data) {
    final subjects = data['subjects'];
    final subjectDetails = data['subjectDetails'];
    final subjectTeachers = <String, String>{};
    final subjectPrices = <String, String>{};
    if (subjectDetails is List) {
      for (final item in subjectDetails) {
        if (item is Map) {
          final name = '${item['name'] ?? ''}'.trim();
          final teacherName = '${item['teacherName'] ?? ''}'.trim();
          final subjectPrice = '${item['price'] ?? ''}'.trim();
          if (name.isNotEmpty && teacherName.isNotEmpty) {
            subjectTeachers[name] = teacherName;
          }
          if (name.isNotEmpty && subjectPrice.isNotEmpty) {
            subjectPrices[name] = subjectPrice;
          }
        }
      }
    }
    return Course(
      id: '${data['id'] ?? data['code'] ?? ''}',
      title: (data['title'] as String?) ?? (data['name'] as String?) ?? 'قسم',
      classId:
          (data['classId'] as String?) ??
          (data['level'] as String?) ??
          '${data['code'] ?? data['id'] ?? ''}',
      description: (data['description'] as String?) ?? '',
      price: (data['price'] as String?) ?? '',
      subjects: subjects is List
          ? subjects.whereType<String>().toList()
          : const ['Math', 'Physique', 'Chimie'],
      subjectTeachers: subjectTeachers,
      subjectPrices: subjectPrices,
      renewalMonths: ((data['renewalMonths'] as num?)?.toInt() ?? 1).clamp(
        1,
        120,
      ),
      isActive: (data['isActive'] as bool?) ?? true,
    );
  }

  Lesson _lessonFromApi(Map<String, dynamic> data) {
    return Lesson(
      id: '${data['id'] ?? ''}',
      title: (data['title'] as String?) ?? 'درس',
      url:
          (data['url'] as String?) ??
          (data['videoUrl'] as String?) ??
          (data['pdfUrl'] as String?) ??
          '',
      teacherId: '${data['teacherId'] ?? ''}',
      classId: (data['classId'] as String?) ?? (data['level'] as String?) ?? '',
      courseId:
          (data['courseId'] as String?) ?? (data['level'] as String?) ?? '',
      subject: (data['subject'] as String?) ?? 'مادة عامة',
      createdAt: _dateFromApi(data['createdAt']),
      isPublished: (data['isPublished'] as bool?) ?? true,
    );
  }

  GuestContentItem _guestContentFromApi(Map<String, dynamic> data) {
    return GuestContentItem(
      id: '${data['id'] ?? ''}',
      title: (data['title'] as String?) ?? 'محتوى',
      url: (data['url'] as String?) ?? '',
      description: (data['description'] as String?) ?? '',
      courseId: data['courseId'] as String?,
      createdAt: _dateFromApi(data['createdAt']),
    );
  }

  AppNotification _notificationFromApi(Map<String, dynamic> data) {
    return AppNotification(
      id: '${data['id'] ?? ''}',
      title: (data['title'] as String?) ?? 'إشعار',
      body: (data['body'] as String?) ?? '',
      createdAt: _dateFromApi(data['createdAt']),
    );
  }

  NationalExamResult _nationalResultFromApi(Map<String, dynamic> data) {
    final rawData = data['rawData'];
    return NationalExamResult(
      id: '${data['id'] ?? ''}',
      examType: (data['examType'] as String?) ?? '',
      candidateNumber: (data['candidateNumber'] as String?) ?? '',
      fullName: (data['fullName'] as String?) ?? '',
      birthPlace: (data['birthPlace'] as String?) ?? '',
      birthDate: (data['birthDate'] as String?) ?? '',
      wilaya: (data['wilaya'] as String?) ?? '',
      moughataa: (data['moughataa'] as String?) ?? '',
      centerName: (data['centerName'] as String?) ?? '',
      score: (data['score'] as String?) ?? '',
      decision: (data['decision'] as String?) ?? '',
      rank: (data['rank'] as String?) ?? '',
      rawData: rawData is Map ? Map<String, dynamic>.from(rawData) : const {},
    );
  }

  OfferSlide _offerSlideFromApi(Map<String, dynamic> data) {
    final duration = (data['durationSeconds'] as num?)?.toInt() ?? 5;
    return OfferSlide(
      id: '${data['id'] ?? ''}',
      title: (data['title'] as String?) ?? '',
      imageUrl: (data['imageUrl'] as String?) ?? '',
      durationSeconds: duration.clamp(1, 120),
    );
  }

  OfferTextSection _offerTextFromApi(Map<String, dynamic> data) {
    return OfferTextSection(
      title: (data['title'] as String?) ?? '',
      body: (data['body'] as String?) ?? '',
      active: data['active'] != false,
    );
  }

  DateTime _dateFromApi(Object? value) {
    if (value is String) {
      return DateTime.tryParse(value)?.toLocal() ?? DateTime.now();
    }
    return DateTime.now();
  }

  DateTime? _dateFromApiOrNull(Object? value) {
    if (value is String && value.trim().isNotEmpty) {
      return DateTime.tryParse(value)?.toLocal();
    }
    return null;
  }

  UserRole _roleFromString(String? value) {
    return switch (value) {
      'admin' => UserRole.admin,
      'developer' => UserRole.admin,
      'teacher' => UserRole.teacher,
      _ => UserRole.student,
    };
  }

  AdminType _adminTypeFromString(String? value) {
    return switch (value) {
      'developer' => AdminType.developer,
      'general_manager' => AdminType.generalManager,
      _ => AdminType.schoolManager,
    };
  }

  AccountStatus _statusFromString(String? value) {
    return switch (value) {
      'active' => AccountStatus.active,
      'blocked' => AccountStatus.blocked,
      'rejected' => AccountStatus.rejected,
      _ => AccountStatus.pending,
    };
  }

  String _statusValue(AccountStatus status) {
    return switch (status) {
      AccountStatus.pending => 'pending',
      AccountStatus.active => 'active',
      AccountStatus.blocked => 'blocked',
      AccountStatus.rejected => 'rejected',
    };
  }

  @override
  void dispose() {
    for (final subscription in _subscriptions) {
      unawaited(subscription.cancel());
    }
    unawaited(_usersSubscription?.cancel() ?? Future<void>.value());
    unawaited(_currentUserSubscription?.cancel() ?? Future<void>.value());
    unawaited(_coursesSubscription?.cancel() ?? Future<void>.value());
    unawaited(_lessonsSubscription?.cancel() ?? Future<void>.value());
    unawaited(_guestVideosSubscription?.cancel() ?? Future<void>.value());
    unawaited(_archiveFilesSubscription?.cancel() ?? Future<void>.value());
    _notificationPollTimer?.cancel();
    super.dispose();
  }

  void _seed() {
    classes.addAll(const [
      SchoolClass(id: 'c1', name: 'عام', level: 'كل المستويات'),
    ]);

    users.addAll([
      AppUser(
        id: 'u-admin',
        name: 'إدارة المدرسة',
        phone: '22240000000',
        password: '123456',
        role: UserRole.admin,
        adminType: AdminType.developer,
        status: AccountStatus.active,
      ),
      AppUser(
        id: 'u-teacher',
        name: 'الأستاذ أحمد',
        phone: '22241111111',
        password: '123456',
        role: UserRole.teacher,
        status: AccountStatus.active,
        classId: 'c1',
        subject: 'الرياضيات',
      ),
      AppUser(
        id: 'u-student',
        name: 'الطالب محمد',
        phone: '22242222222',
        password: '123456',
        role: UserRole.student,
        status: AccountStatus.active,
        classId: 'c1',
        courseId: 'course-1',
      ),
    ]);

    courses.addAll([
      Course(
        id: 'course-1',
        title: 'البكالوريا',
        classId: 'c1',
        description:
            'قسم البكالوريا مع مواد الفيزياء والكيمياء والرياضيات والعلوم',
        price: 'غير محدد',
        subjects: ['الفيزياء', 'الكيمياء', 'الرياضيات', 'العلوم'],
      ),
      Course(
        id: 'course-2',
        title: 'شهادة التعليم المتوسط',
        classId: 'c1',
        description: 'مواد منظمة ودروس فيديو لطلاب التعليم المتوسط',
        price: 'غير محدد',
        subjects: ['الرياضيات', 'العلوم'],
      ),
    ]);

    lessons.add(
      Lesson(
        id: 'lesson-1',
        title: 'مقدمة في المعادلات',
        url: 'https://example.com/math-lesson',
        teacherId: 'u-teacher',
        classId: 'c1',
        courseId: 'course-1',
        subject: 'الرياضيات',
        createdAt: DateTime.now().subtract(const Duration(days: 1)),
      ),
    );

    guestVideos.add(
      GuestContentItem(
        id: 'guest-video-1',
        title: 'فيديو مجاني تجريبي',
        url: 'https://drive.google.com',
        description: 'أضف رابط Google Drive من لوحة الإدارة.',
        courseId: 'course-1',
        createdAt: DateTime.now(),
      ),
    );

    archiveFiles.add(
      GuestContentItem(
        id: 'archive-1',
        title: 'ملف PDF تجريبي',
        url: 'https://drive.google.com',
        description: 'أضف رابط ملف PDF من لوحة الإدارة.',
        courseId: 'course-1',
        createdAt: DateTime.now(),
      ),
    );

    notifications.add(
      AppNotification(
        id: 'n-welcome',
        title: 'مرحبا بكم في Epsilon',
        body: 'تابعوا صفحة المواد للحصول على آخر الدروس المنشورة.',
        createdAt: DateTime.now().subtract(const Duration(hours: 2)),
      ),
    );
  }

  Future<bool> login(String phone, String password) async {
    if (backendEnabled) {
      try {
        isLoading = true;
        lastError = null;
        notifyListeners();
        final userData = await (_repository as SupabaseRepository).signIn(
          phone: phone,
          password: password,
        );
        currentUser = _userFromApi(userData);
        users
          ..clear()
          ..add(currentUser!);
        await _loadSignedInApiData();
        _startNotificationPolling();
        return true;
      } on Object catch (error) {
        lastError = error.toString();
        unawaited((_repository as SupabaseRepository).signOut());
        return false;
      } finally {
        isLoading = false;
        notifyListeners();
      }
    }

    final normalizedPhone = phone.trim();
    final match = users.where(
      (user) => user.phone == normalizedPhone && user.password == password,
    );

    if (match.isEmpty) {
      return false;
    }

    currentUser = match.first;
    notifyListeners();
    return true;
  }

  void logout() {
    if (backendEnabled) {
      unawaited((_repository as SupabaseRepository).signOut());
    }
    currentUser = null;
    users.clear();
    lessons.clear();
    _notificationPollTimer?.cancel();
    _notificationPollTimer = null;
    notifyListeners();
  }

  Future<bool> changeCurrentPassword({
    required String currentPassword,
    required String newPassword,
  }) async {
    if (backendEnabled) {
      lastError = 'تغيير كلمة المرور غير متاح من التطبيق حالياً.';
      notifyListeners();
      return false;
    }

    final user = currentUser;
    if (user == null ||
        user.password != currentPassword ||
        newPassword.length < 6) {
      return false;
    }

    final index = users.indexOf(user);
    if (index == -1) {
      return false;
    }

    users[index] = AppUser(
      id: user.id,
      name: user.name,
      phone: user.phone,
      password: newPassword,
      role: user.role,
      status: user.status,
      classId: user.classId,
      courseId: user.courseId,
      subject: user.subject,
      selectedSubjects: user.selectedSubjects,
      adminType: user.adminType,
      managedCourseIds: user.managedCourseIds,
      paymentProofPath: user.paymentProofPath,
      paymentSenderPhone: user.paymentSenderPhone,
      paymentAmount: user.paymentAmount,
      subscriptionExpiresAt: user.subscriptionExpiresAt,
      activeDeviceId: user.activeDeviceId,
    );
    currentUser = users[index];
    notifyListeners();
    return true;
  }

  /// Redesigned signup: free account, verified by SMS code.
  Future<void> registerFreeStudent({
    required String name,
    required String phone,
    required String password,
    required String level,
  }) async {
    if (backendEnabled) {
      await (_repository as SupabaseRepository).registerFreeStudent(
        name: name,
        phone: phone,
        password: password,
        level: level,
      );
      return;
    }
    users.add(
      AppUser(
        id: 'local-${DateTime.now().microsecondsSinceEpoch}',
        name: name.trim(),
        phone: phone.trim(),
        password: password,
        role: UserRole.student,
        status: AccountStatus.active,
      ),
    );
  }

  Future<void> resendSignupCode(String phone) async {
    if (backendEnabled) {
      await (_repository as SupabaseRepository).requestOtp(
        phone: phone,
        purpose: 'signup',
      );
    }
  }

  /// Verifies the signup code, then signs the student in.
  Future<bool> verifySignupAndLogin({
    required String phone,
    required String code,
    required String password,
  }) async {
    if (backendEnabled) {
      await (_repository as SupabaseRepository).verifyOtp(
        phone: phone,
        code: code,
        purpose: 'signup',
      );
    }
    return login(phone, password);
  }

  Future<void> sendPasswordResetEmail(String phone) async {
    if (backendEnabled) {
      await (_repository as SupabaseRepository).sendPasswordResetOtp(
        phone: phone,
      );
      lastError = null;
      notifyListeners();
      return;
    }
  }

  Future<void> resetPasswordWithCode({
    required String phone,
    required String code,
    required String newPassword,
  }) async {
    if (backendEnabled) {
      await (_repository as SupabaseRepository).resetPasswordWithCode(
        phone: phone,
        code: code,
        newPassword: newPassword,
      );
      return;
    }

    final matches = users.where((user) => user.phone == phone.trim());
    if (matches.isEmpty) {
      throw const SupabaseAppException('رقم الهاتف غير مسجل.');
    }
    final user = matches.first;
    final index = users.indexOf(user);
    users[index] = AppUser(
      id: user.id,
      name: user.name,
      phone: user.phone,
      password: newPassword,
      role: user.role,
      status: user.status,
      classId: user.classId,
      courseId: user.courseId,
      subject: user.subject,
      selectedSubjects: user.selectedSubjects,
      adminType: user.adminType,
      managedCourseIds: user.managedCourseIds,
      paymentProofPath: user.paymentProofPath,
      paymentSenderPhone: user.paymentSenderPhone,
      paymentAmount: user.paymentAmount,
      subscriptionExpiresAt: user.subscriptionExpiresAt,
      activeDeviceId: user.activeDeviceId,
    );
    notifyListeners();
  }

  Future<void> registerStudent({
    required String name,
    required String phone,
    required String password,
    required String courseId,
    required String paymentProofPath,
    required List<String> selectedSubjects,
    required String paymentSenderPhone,
    required String paymentAmount,
  }) async {
    final course = courseById(courseId);
    if (backendEnabled) {
      if (course == null) {
        return;
      }
      await (_repository as SupabaseRepository).registerStudent(
        name: name,
        phone: phone,
        password: password,
        courseId: courseId,
        selectedSubjects: selectedSubjects,
        paymentProofPath: paymentProofPath,
        paymentSenderPhone: paymentSenderPhone,
        paymentAmount: paymentAmount,
      );
      await _loadPublicApiData();
      return;
    }

    users.add(
      AppUser(
        id: 'u-${DateTime.now().microsecondsSinceEpoch}',
        name: name.trim(),
        phone: phone.trim(),
        password: password,
        role: UserRole.student,
        status: AccountStatus.pending,
        classId: course?.classId,
        courseId: courseId,
        selectedSubjects: selectedSubjects,
        paymentProofPath: paymentProofPath,
        paymentSenderPhone: paymentSenderPhone.trim(),
        paymentAmount: paymentAmount.trim(),
      ),
    );
    notifyListeners();
  }

  Future<void> createStudentByAdmin({
    required String name,
    required String phone,
    required String password,
    required String courseId,
    String paymentAmount = '',
  }) async {
    final course = courseById(courseId);
    if (backendEnabled) {
      if (course == null) {
        return;
      }
      try {
        final expiresAt = addMonths(
          DateTime.now(),
          course.renewalMonths.clamp(1, 120),
        );
        await (_repository as SupabaseRepository).createUser(
          name: name,
          phone: phone,
          password: password,
          role: 'student',
          courseId: courseId,
          paymentAmount: paymentAmount.trim().isEmpty
              ? null
              : paymentAmount.trim(),
          subscriptionExpiresAt: expiresAt,
        );
        await _loadSignedInApiData();
        _recordPayment(
          studentName: name,
          amount: paymentAmount,
          type: 'تسجيل',
          courseId: courseId,
        );
      } on Object catch (error) {
        _rememberError(error);
      }
      return;
    }

    users.add(
      AppUser(
        id: 'u-${DateTime.now().microsecondsSinceEpoch}',
        name: name.trim(),
        phone: phone.trim(),
        password: password,
        role: UserRole.student,
        status: AccountStatus.active,
        classId: course?.classId,
        courseId: courseId,
        paymentAmount: paymentAmount.trim(),
        subscriptionExpiresAt: course == null
            ? null
            : addMonths(DateTime.now(), course.renewalMonths.clamp(1, 120)),
      ),
    );
    notifyListeners();
    _recordPayment(
      studentName: name,
      amount: paymentAmount,
      type: 'تسجيل',
      courseId: courseId,
    );
  }

  Future<void> createTeacher({
    required String name,
    required String phone,
    required String password,
    required String classId,
    required String courseId,
    required String subject,
  }) async {
    if (backendEnabled) {
      await (_repository as SupabaseRepository).createUser(
        name: name,
        phone: phone,
        password: password,
        role: 'teacher',
        courseId: courseId,
        subject: subject,
      );
      await _loadSignedInApiData();
      return;
    }

    users.add(
      AppUser(
        id: 'u-${DateTime.now().microsecondsSinceEpoch}',
        name: name.trim(),
        phone: phone.trim(),
        password: password,
        role: UserRole.teacher,
        status: AccountStatus.active,
        classId: classId,
        courseId: courseId,
        subject: subject.trim(),
      ),
    );
    notifyListeners();
  }

  Future<void> createAdmin({
    required String name,
    required String phone,
    required String password,
    required AdminType adminType,
    required List<String> managedCourseIds,
  }) async {
    final cleanCourseIds = managedCourseIds
        .map((id) => id.trim())
        .where((id) => id.isNotEmpty)
        .toSet()
        .toList();
    if (adminType != AdminType.developer && cleanCourseIds.isEmpty) {
      lastError = 'اختر قسما واحدا على الأقل لهذا الأدمن.';
      notifyListeners();
      return;
    }
    lastError = null;
    if (backendEnabled) {
      final data = await (_repository as SupabaseRepository).createAdmin(
        name: name,
        phone: phone,
        password: password,
      );
      final created = _userFromApi(
        Map<String, dynamic>.from(data['user'] as Map),
      );
      adminAccessByUserId[created.id] = AdminAccessConfig(
        adminType: adminType,
        managedCourseIds: cleanCourseIds,
      );
      await (_repository as SupabaseRepository).updateSettings(
        adminAccess: adminAccessByUserId.entries
            .map((entry) => entry.value.toJson(entry.key))
            .toList(),
      );
      await _loadSignedInApiData();
      notifyListeners();
      return;
    }

    final admin = AppUser(
      id: 'admin-${DateTime.now().microsecondsSinceEpoch}',
      name: name.trim(),
      phone: phone.trim(),
      password: password,
      role: UserRole.admin,
      status: AccountStatus.active,
      adminType: adminType,
      managedCourseIds: cleanCourseIds,
    );
    users.add(admin);
    adminAccessByUserId[admin.id] = AdminAccessConfig(
      adminType: adminType,
      managedCourseIds: cleanCourseIds,
    );
    notifyListeners();
  }

  void approveUser(AppUser user) {
    final expiresAt = subscriptionExpiryFor(user);
    if (backendEnabled) {
      unawaited(
        (_repository as SupabaseRepository)
            .updateAccountStatus(
              user.id,
              _statusValue(AccountStatus.active),
              subscriptionExpiresAt: expiresAt,
            )
            .then((_) => _loadSignedInApiData())
            .then(
              (_) => _recordPayment(
                studentName: user.name,
                amount: user.paymentAmount,
                type: 'تسجيل',
                courseId: user.courseId,
              ),
            )
            .catchError(_rememberError),
      );
      return;
    }
    user.status = AccountStatus.active;
    user.subscriptionExpiresAt = expiresAt;
    notifyListeners();
    _recordPayment(
      studentName: user.name,
      amount: user.paymentAmount,
      type: 'تسجيل',
      courseId: user.courseId,
    );
  }

  void blockUser(AppUser user) {
    if (backendEnabled) {
      unawaited(
        (_repository as SupabaseRepository)
            .updateAccountStatus(user.id, _statusValue(AccountStatus.blocked))
            .then((_) => _loadSignedInApiData())
            .catchError(_rememberError),
      );
      return;
    }
    user.status = AccountStatus.blocked;
    notifyListeners();
  }

  void rejectUser(AppUser user) {
    if (backendEnabled) {
      unawaited(
        (_repository as SupabaseRepository)
            .updateAccountStatus(user.id, _statusValue(AccountStatus.rejected))
            .then((_) => _loadSignedInApiData())
            .catchError(_rememberError),
      );
      return;
    }
    user.status = AccountStatus.rejected;
    notifyListeners();
  }

  void activateUser(AppUser user) {
    if (backendEnabled) {
      unawaited(
        (_repository as SupabaseRepository)
            .updateAccountStatus(user.id, _statusValue(AccountStatus.active))
            .then((_) => _loadSignedInApiData())
            .catchError(_rememberError),
      );
      return;
    }
    user.status = AccountStatus.active;
    notifyListeners();
  }

  Future<void> deleteUser(AppUser user) async {
    if (backendEnabled) {
      await (_repository as SupabaseRepository).deleteUserAccount(user.id);
      await _loadSignedInApiData();
      return;
    }

    users.remove(user);
    notifyListeners();
  }

  void createCourse({
    required String title,
    required String classId,
    required String description,
    required String price,
    required int renewalMonths,
    required List<Map<String, String>> subjects,
  }) {
    if (backendEnabled) {
      unawaited(
        (_repository as SupabaseRepository)
            .createCourse(
              title: title,
              classId: classId,
              description: description,
              price: price,
              renewalMonths: renewalMonths,
              subjects: subjects,
            )
            .then((_) => _loadPublicApiData())
            .catchError(_rememberError),
      );
      return;
    }

    courses.add(
      Course(
        id: 'course-${DateTime.now().microsecondsSinceEpoch}',
        title: title.trim(),
        classId: classId,
        description: description.trim(),
        price: price.trim(),
        renewalMonths: renewalMonths.clamp(1, 120),
        subjects: subjects.map((subject) => subject['name'] ?? '').toList(),
        subjectPrices: {
          for (final subject in subjects)
            if ((subject['name'] ?? '').trim().isNotEmpty &&
                (subject['price'] ?? '').trim().isNotEmpty)
              subject['name']!.trim(): subject['price']!.trim(),
        },
      ),
    );
    notifyListeners();
  }

  void updatePaymentNumber(String value) {
    if (backendEnabled) {
      paymentNumber = value.trim();
      notifyListeners();
      unawaited(
        (_repository as SupabaseRepository)
            .updateSettings(paymentNumber: paymentNumber)
            .then((data) => _applySettingsFromApi(data['settings']))
            .catchError(_rememberError),
      );
      return;
    }
    paymentNumber = value.trim();
    notifyListeners();
  }

  void updatePaymentAmount(String value) {
    if (backendEnabled) {
      paymentAmount = value.trim();
      notifyListeners();
      unawaited(
        (_repository as SupabaseRepository)
            .updateSettings(paymentAmount: paymentAmount)
            .then((data) => _applySettingsFromApi(data['settings']))
            .catchError(_rememberError),
      );
      return;
    }
    paymentAmount = value.trim();
    notifyListeners();
  }

  void createPaymentMethod({
    required String name,
    required String accountNumber,
    required String imageUrl,
  }) {
    final methodName = name.trim();
    final methodNumber = accountNumber.trim();
    if (methodName.isEmpty || methodNumber.isEmpty) {
      return;
    }
    if (backendEnabled) {
      unawaited(
        (_repository as SupabaseRepository)
            .createPaymentMethod(
              name: methodName,
              accountNumber: methodNumber,
              imageUrl: imageUrl.trim(),
            )
            .then((data) => _applySettingsFromApi(data['settings']))
            .catchError(_rememberError),
      );
      return;
    }
    paymentMethods.add(
      PaymentMethod(
        id: 'payment-${DateTime.now().microsecondsSinceEpoch}',
        name: methodName,
        accountNumber: methodNumber,
        imageUrl: imageUrl.trim(),
      ),
    );
    notifyListeners();
  }

  void deletePaymentMethod(PaymentMethod method) {
    if (backendEnabled) {
      unawaited(
        (_repository as SupabaseRepository)
            .deletePaymentMethod(method.id)
            .then((data) => _applySettingsFromApi(data['settings']))
            .catchError(_rememberError),
      );
      return;
    }
    paymentMethods.removeWhere((item) => item.id == method.id);
    notifyListeners();
  }

  void createExpense({
    required String title,
    required String amount,
    required String category,
    required String courseId,
    String note = '',
  }) {
    final cleanTitle = title.trim();
    final cleanAmount = amount.trim();
    final parsedAmount = priceNumberFromText(cleanAmount);
    final course = courseById(courseId);
    if (cleanTitle.isEmpty ||
        cleanAmount.isEmpty ||
        parsedAmount == null ||
        course == null) {
      lastError = 'اختر القسم واكتب مبلغا صحيحا.';
      notifyListeners();
      return;
    }
    final availableAmount = courseBoxAmount(courseId);
    if (availableAmount <= 0 || parsedAmount > availableAmount) {
      lastError = 'لا يوجد رصيد كاف في صندوق هذا القسم.';
      notifyListeners();
      return;
    }
    lastError = null;
    expenses.insert(
      0,
      ExpenseItem(
        id: 'expense-${DateTime.now().microsecondsSinceEpoch}',
        title: cleanTitle,
        amount: cleanAmount,
        category: category.trim().isEmpty ? 'عام' : category.trim(),
        note: note.trim(),
        createdAt: DateTime.now(),
        courseId: course.id,
        courseTitle: course.title,
      ),
    );
    notifyListeners();
    _syncExpenses();
  }

  void deleteExpense(ExpenseItem expense) {
    expenses.removeWhere((item) => item.id == expense.id);
    notifyListeners();
    _syncExpenses();
  }

  void _syncExpenses() {
    if (!backendEnabled) {
      return;
    }
    unawaited(
      (_repository as SupabaseRepository)
          .updateSettings(
            expenses: expenses.map((expense) => expense.toJson()).toList(),
          )
          .then((data) => _applySettingsFromApi(data['settings']))
          .catchError(_rememberError),
    );
  }

  void _recordPayment({
    required String studentName,
    required String amount,
    required String type,
    String? courseId,
  }) {
    final cleanAmount = amount.trim();
    if (cleanAmount.isEmpty || priceNumberFromText(cleanAmount) == null) {
      return;
    }
    final course = courseById(courseId);
    payments.insert(
      0,
      PaymentRecord(
        id: 'payment-${DateTime.now().microsecondsSinceEpoch}',
        studentName: studentName.trim(),
        amount: cleanAmount,
        type: type,
        createdAt: DateTime.now(),
        courseId: courseId,
        courseTitle: course?.title,
      ),
    );
    notifyListeners();
    _syncPayments();
  }

  void _syncPayments() {
    if (!backendEnabled) {
      return;
    }
    unawaited(
      (_repository as SupabaseRepository)
          .updateSettings(
            payments: payments.map((payment) => payment.toJson()).toList(),
          )
          .then((data) => _applySettingsFromApi(data['settings']))
          .catchError(_rememberError),
    );
  }

  Future<void> renewSubscription({
    required AppUser user,
    required String amount,
  }) async {
    final expiresAt = subscriptionExpiryFor(user);
    if (backendEnabled) {
      await (_repository as SupabaseRepository).updateStudentSubscription(
        user.id,
        subscriptionExpiresAt: expiresAt,
        paymentAmount: amount,
      );
      await _loadSignedInApiData();
    } else {
      user.status = AccountStatus.active;
      user.paymentAmount = amount.trim();
      user.subscriptionExpiresAt = expiresAt;
      notifyListeners();
    }
    _recordPayment(
      studentName: user.name,
      amount: amount,
      type: 'تجديد',
      courseId: user.courseId,
    );
  }

  DateTime subscriptionExpiryFor(AppUser user) {
    final course = courseById(user.courseId);
    final months = (course?.renewalMonths ?? 1).clamp(1, 120);
    return addMonths(DateTime.now(), months);
  }

  void createClass({required String name, required String level}) {
    if (backendEnabled) {
      unawaited(
        (_repository as SupabaseRepository)
            .post('/api/classes', {
              'name': name.trim(),
              'level': level.trim(),
              'title': name.trim(),
              'description': level.trim(),
            })
            .then((_) => _loadPublicApiData())
            .catchError(_rememberError),
      );
      return;
    }

    classes.add(
      SchoolClass(
        id: 'c-${DateTime.now().microsecondsSinceEpoch}',
        name: name.trim(),
        level: level.trim(),
      ),
    );
    notifyListeners();
  }

  void deleteCourse(Course course) {
    if (backendEnabled) {
      unawaited(
        (_repository as SupabaseRepository)
            .deleteCourse(course.id)
            .then((_) => _loadPublicApiData())
            .catchError(_rememberError),
      );
      return;
    }

    courses.remove(course);
    lessons.removeWhere((lesson) => lesson.courseId == course.id);
    for (final user in users) {
      if (user.courseId == course.id) {
        user.courseId = null;
      }
    }
    notifyListeners();
  }

  Future<void> updateCourseRenewalMonths({
    required Course course,
    required int renewalMonths,
  }) async {
    final cleanMonths = renewalMonths.clamp(1, 120);
    if (backendEnabled) {
      await (_repository as SupabaseRepository).updateCourseRenewalMonths(
        courseId: course.id,
        renewalMonths: cleanMonths,
      );
      await _loadPublicApiData();
      return;
    }

    course.renewalMonths = cleanMonths;
    notifyListeners();
  }

  void deleteClass(SchoolClass schoolClass) {
    if (backendEnabled) {
      deleteCourse(
        Course(
          id: schoolClass.id,
          title: schoolClass.name,
          classId: schoolClass.id,
        ),
      );
      return;
    }

    classes.remove(schoolClass);
    courses.removeWhere((course) => course.classId == schoolClass.id);
    lessons.removeWhere((lesson) => lesson.classId == schoolClass.id);
    for (final user in users) {
      if (user.classId == schoolClass.id) {
        user.classId = null;
        user.courseId = null;
      }
    }
    notifyListeners();
  }

  void createLesson({
    required String title,
    required String url,
    required String classId,
    required String courseId,
    AppUser? teacherOverride,
    String? subjectOverride,
  }) {
    final teacher = teacherOverride ?? currentUser;
    if (teacher == null) {
      return;
    }
    final lessonSubject = subjectOverride?.trim().isNotEmpty == true
        ? subjectOverride!.trim()
        : teacher.subject ?? 'مادة عامة';

    if (backendEnabled) {
      unawaited(
        (_repository as SupabaseRepository)
            .createLesson(
              title: title,
              url: url,
              classId: classId,
              courseId: courseId,
              subject: lessonSubject,
              teacherId: teacher.id,
            )
            .then((_) => _loadSignedInApiData())
            .catchError(_rememberError),
      );
      return;
    }

    lessons.add(
      Lesson(
        id: 'lesson-${DateTime.now().microsecondsSinceEpoch}',
        title: title.trim(),
        url: url.trim(),
        teacherId: teacher.id,
        classId: classId,
        courseId: courseId,
        subject: lessonSubject,
        createdAt: DateTime.now(),
      ),
    );
    notifyListeners();
  }

  void updateLesson({
    required Lesson lesson,
    required String title,
    required String url,
    required String courseId,
  }) {
    final course = courseById(courseId);
    if (backendEnabled) {
      if (course == null) {
        return;
      }
      unawaited(
        (_repository as SupabaseRepository)
            .updateLesson(lessonId: lesson.id, title: title, url: url)
            .then((_) => _loadSignedInApiData())
            .catchError(_rememberError),
      );
      return;
    }

    lesson.title = title.trim();
    lesson.url = url.trim();
    lesson.courseId = courseId;
    if (course != null) {
      lesson.classId = course.classId;
    }
    notifyListeners();
  }

  void deleteLesson(Lesson lesson) {
    if (backendEnabled) {
      unawaited(
        (_repository as SupabaseRepository)
            .deleteLesson(lesson.id)
            .then((_) => _loadSignedInApiData())
            .catchError(_rememberError),
      );
      return;
    }
    lessons.remove(lesson);
    notifyListeners();
  }

  void addGuestVideo({
    required String title,
    required String url,
    required String description,
    required String courseId,
  }) {
    if (backendEnabled) {
      unawaited(
        (_repository as SupabaseRepository)
            .createGuestContent(
              contentType: 'guest_video',
              title: title,
              url: url,
              description: description,
              courseId: courseId,
            )
            .then((_) => _loadPublicApiData())
            .catchError(_rememberError),
      );
      return;
    }

    guestVideos.insert(
      0,
      GuestContentItem(
        id: 'guest-video-${DateTime.now().microsecondsSinceEpoch}',
        title: title.trim(),
        url: url.trim(),
        description: description.trim(),
        courseId: courseId,
        createdAt: DateTime.now(),
      ),
    );
    notifyListeners();
  }

  void addArchiveFile({
    required String title,
    required String url,
    required String description,
    required String courseId,
  }) {
    if (backendEnabled) {
      unawaited(
        (_repository as SupabaseRepository)
            .createGuestContent(
              contentType: 'archive_file',
              title: title,
              url: url,
              description: description,
              courseId: courseId,
            )
            .then((_) => _loadPublicApiData())
            .catchError(_rememberError),
      );
      return;
    }

    archiveFiles.insert(
      0,
      GuestContentItem(
        id: 'archive-${DateTime.now().microsecondsSinceEpoch}',
        title: title.trim(),
        url: url.trim(),
        description: description.trim(),
        courseId: courseId,
        createdAt: DateTime.now(),
      ),
    );
    notifyListeners();
  }

  void deleteGuestVideo(GuestContentItem item) {
    if (backendEnabled) {
      unawaited(
        (_repository as SupabaseRepository)
            .deleteGuestContent(item.id)
            .then((_) => _loadPublicApiData())
            .catchError(_rememberError),
      );
      return;
    }

    guestVideos.remove(item);
    notifyListeners();
  }

  void updateGuestVideo({
    required GuestContentItem item,
    required String title,
    required String url,
    required String description,
    required String courseId,
  }) {
    if (backendEnabled) {
      unawaited(
        (_repository as SupabaseRepository)
            .updateGuestContent(
              id: item.id,
              title: title,
              url: url,
              description: description,
              courseId: courseId,
            )
            .then((_) => _loadPublicApiData())
            .catchError(_rememberError),
      );
      return;
    }

    item.title = title.trim();
    item.url = url.trim();
    item.description = description.trim();
    item.courseId = courseId;
    notifyListeners();
  }

  void deleteArchiveFile(GuestContentItem item) {
    if (backendEnabled) {
      unawaited(
        (_repository as SupabaseRepository)
            .deleteGuestContent(item.id)
            .then((_) => _loadPublicApiData())
            .catchError(_rememberError),
      );
      return;
    }

    archiveFiles.remove(item);
    notifyListeners();
  }

  void updateArchiveFile({
    required GuestContentItem item,
    required String title,
    required String url,
    required String description,
    required String courseId,
  }) {
    if (backendEnabled) {
      unawaited(
        (_repository as SupabaseRepository)
            .updateGuestContent(
              id: item.id,
              title: title,
              url: url,
              description: description,
              courseId: courseId,
            )
            .then((_) => _loadPublicApiData())
            .catchError(_rememberError),
      );
      return;
    }

    item.title = title.trim();
    item.url = url.trim();
    item.description = description.trim();
    item.courseId = courseId;
    notifyListeners();
  }

  Future<void> addNotification({
    required String title,
    required String body,
  }) async {
    if (backendEnabled) {
      try {
        await (_repository as SupabaseRepository).addNotification(
          title: title,
          body: body,
        );
        await _loadSignedInApiData();
        notifyListeners();
      } catch (error) {
        _rememberError(error);
        rethrow;
      }
      return;
    }

    notifications.insert(
      0,
      AppNotification(
        id: 'n-${DateTime.now().microsecondsSinceEpoch}',
        title: title.trim(),
        body: body.trim(),
        createdAt: DateTime.now(),
      ),
    );
    notifyListeners();
  }

  Future<void> updateNotification({
    required AppNotification notification,
    required String title,
    required String body,
  }) async {
    if (backendEnabled) {
      await (_repository as SupabaseRepository).updateNotification(
        id: notification.id,
        title: title,
        body: body,
      );
      await _loadSignedInApiData();
      notifyListeners();
      return;
    }

    final index = notifications.indexWhere(
      (item) => item.id == notification.id,
    );
    if (index == -1) {
      return;
    }

    notifications[index] = AppNotification(
      id: notification.id,
      title: title.trim(),
      body: body.trim(),
      createdAt: notification.createdAt,
    );
    notifyListeners();
  }

  Future<void> deleteNotification(AppNotification notification) async {
    if (backendEnabled) {
      await (_repository as SupabaseRepository).deleteNotification(
        notification.id,
      );
      await _loadSignedInApiData();
      notifyListeners();
      return;
    }

    notifications.removeWhere((item) => item.id == notification.id);
    notifyListeners();
  }

  Future<List<NationalExamResult>> searchNationalResults({
    required String examType,
    required String query,
    String? center,
  }) async {
    if (!backendEnabled) {
      return const [];
    }
    final items = await (_repository as SupabaseRepository)
        .searchNationalResults(
          examType: examType,
          query: query,
          center: center,
        );
    return items.map(_nationalResultFromApi).toList();
  }

  Future<List<String>> nationalResultCenters({required String examType}) async {
    if (!backendEnabled) {
      return const [];
    }
    return (_repository as SupabaseRepository).nationalResultCenters(
      examType: examType,
    );
  }

  Future<List<OfferSlide>> offers() async {
    if (!backendEnabled) {
      return const [];
    }
    final items = await (_repository as SupabaseRepository).offers();
    return items.map(_offerSlideFromApi).toList();
  }

  Future<OfferTextSection> offerTextSection() async {
    if (!backendEnabled) {
      return const OfferTextSection(title: '', body: '', active: false);
    }
    final data = await (_repository as SupabaseRepository).offerTextSection();
    return _offerTextFromApi(data);
  }

  Future<int> uploadNationalResults({
    required String examType,
    required String filePath,
    required String fileName,
  }) async {
    if (!backendEnabled) {
      return 0;
    }
    return (_repository as SupabaseRepository).uploadNationalResults(
      examType: examType,
      filePath: filePath,
      fileName: fileName,
    );
  }

  void setThemeMode(ThemeMode value) {
    themeMode = value;
    notifyListeners();
  }

  void setLanguageCode(String value) {
    languageCode = value;
    notifyListeners();
  }

  List<AppUser> get pendingStudents => users
      .where(
        (user) =>
            user.role == UserRole.student &&
            user.status == AccountStatus.pending,
      )
      .toList();

  List<AppUser> get teachers =>
      users.where((user) => user.role == UserRole.teacher).toList();

  List<AppUser> get admins =>
      users.where((user) => user.role == UserRole.admin).toList();

  List<AppUser> get students =>
      users.where((user) => user.role == UserRole.student).toList();

  List<AppUser> get visibleStudents {
    final user = currentUser;
    if (user == null || user.role != UserRole.admin) {
      return const [];
    }
    if (user.adminType == AdminType.developer) {
      return students;
    }
    final allowedCourseIds = adminManagedCourseIds(user);
    return students
        .where(
          (student) =>
              student.courseId != null &&
              allowedCourseIds.contains(student.courseId),
        )
        .toList();
  }

  List<AppUser> get visiblePendingStudents => visibleStudents
      .where((user) => user.status == AccountStatus.pending)
      .toList();

  bool get currentAdminIsDeveloper =>
      currentUser?.role == UserRole.admin &&
      currentUser?.adminType == AdminType.developer;

  Set<String> adminManagedCourseIds(AppUser admin) {
    if (admin.adminType == AdminType.developer) {
      return courses.map((course) => course.id).toSet();
    }
    final ids = <String>{...admin.managedCourseIds};
    if (admin.courseId != null && admin.courseId!.trim().isNotEmpty) {
      ids.add(admin.courseId!);
    }
    return ids;
  }

  List<Course> visibleFinancialCoursesFor(AppUser? admin) {
    if (admin == null || admin.role != UserRole.admin) {
      return const [];
    }
    if (admin.adminType == AdminType.developer) {
      return courses;
    }
    final allowedIds = adminManagedCourseIds(admin);
    return courses.where((course) => allowedIds.contains(course.id)).toList();
  }

  List<CourseIncomeSummary> get visibleCourseIncomeSummaries {
    final visibleCourses = visibleFinancialCoursesFor(currentUser);
    return visibleCourses.map((course) {
      final coursePayments = visiblePayments
          .where((payment) => payment.courseId == course.id)
          .toList();
      final total = coursePayments
          .map((payment) => priceNumberFromText(payment.amount) ?? 0)
          .fold<double>(0, (runningTotal, amount) => runningTotal + amount);
      final expensesTotal = courseExpenseAmount(course.id);
      return CourseIncomeSummary(
        course: course,
        payments: coursePayments,
        total: total - expensesTotal,
      );
    }).toList();
  }

  Future<void> updateAdminAccess({
    required AppUser admin,
    required AdminType adminType,
    required List<String> managedCourseIds,
  }) async {
    final cleanCourseIds = managedCourseIds
        .map((id) => id.trim())
        .where((id) => id.isNotEmpty)
        .toSet()
        .toList();
    if (backendEnabled) {
      adminAccessByUserId[admin.id] = AdminAccessConfig(
        adminType: adminType,
        managedCourseIds: cleanCourseIds,
      );
      await (_repository as SupabaseRepository).updateSettings(
        adminAccess: adminAccessByUserId.entries
            .map((entry) => entry.value.toJson(entry.key))
            .toList(),
      );
      await _loadSignedInApiData();
      notifyListeners();
      return;
    }
    admin.adminType = adminType;
    admin.managedCourseIds = cleanCourseIds;
    notifyListeners();
  }

  SchoolClass? classById(String? id) {
    if (id == null) {
      return null;
    }
    return classes.where((schoolClass) => schoolClass.id == id).firstOrNull;
  }

  Course? courseById(String? id) {
    if (id == null) {
      return null;
    }
    return courses.where((course) => course.id == id).firstOrNull;
  }
}

class StoreScope extends InheritedNotifier<SchoolStore> {
  const StoreScope({
    required SchoolStore super.notifier,
    required super.child,
    super.key,
  });

  static SchoolStore of(BuildContext context) {
    final scope = context.dependOnInheritedWidgetOfExactType<StoreScope>();
    assert(scope != null, 'StoreScope is missing');
    return scope!.notifier!;
  }
}

class EpsilonApp extends StatefulWidget {
  const EpsilonApp({required this.backendStatus, super.key});

  final BackendBootstrap backendStatus;

  @override
  State<EpsilonApp> createState() => _EpsilonAppState();
}

class _EpsilonAppState extends State<EpsilonApp> {
  late final SchoolStore store = SchoolStore(
    backendEnabled: widget.backendStatus.isReady,
  );
  late final LearnStore learn = LearnStore(
    enabled: widget.backendStatus.isReady,
  );

  @override
  Widget build(BuildContext context) {
    return StoreScope(
      notifier: store,
      child: LearnScope(
        notifier: learn,
        child: AnimatedBuilder(
          animation: store,
          builder: (context, _) {
            return MaterialApp(
              debugShowCheckedModeBanner: false,
              title: 'Epsilon Academy',
              locale: Locale(store.languageCode),
              themeMode: store.themeMode,
              builder: (context, child) {
                return Directionality(
                  textDirection: TextDirection.rtl,
                  child: child ?? const SizedBox.shrink(),
                );
              },
              theme: Eps.lightTheme(),
              darkTheme: Eps.darkTheme(),
              home: StartupSplashGate(backendStatus: widget.backendStatus),
            );
          },
        ),
      ),
    );
  }
}

class StartupSplashGate extends StatefulWidget {
  const StartupSplashGate({required this.backendStatus, super.key});

  final BackendBootstrap backendStatus;

  @override
  State<StartupSplashGate> createState() => _StartupSplashGateState();
}

class _StartupSplashGateState extends State<StartupSplashGate> {
  bool showSplash = true;
  Timer? splashTimer;

  @override
  void initState() {
    super.initState();
    splashTimer = Timer(const Duration(seconds: 4), () {
      if (mounted) {
        setState(() => showSplash = false);
      }
    });
  }

  @override
  void dispose() {
    splashTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (showSplash) {
      return StartupSplashScreen(
        onSkip: () {
          splashTimer?.cancel();
          setState(() => showSplash = false);
        },
      );
    }

    return OnboardingGate(backendStatus: widget.backendStatus);
  }
}

class OnboardingGate extends StatefulWidget {
  const OnboardingGate({required this.backendStatus, super.key});

  final BackendBootstrap backendStatus;

  @override
  State<OnboardingGate> createState() => _OnboardingGateState();
}

class _OnboardingGateState extends State<OnboardingGate> {
  static const _onboardingSeenKey = 'epsilon_onboarding_seen';
  bool onboardingDone = true;
  bool checkedOnboarding = false;

  @override
  void initState() {
    super.initState();
    loadOnboardingState();
  }

  Future<void> loadOnboardingState() async {
    final prefs = await SharedPreferences.getInstance();
    if (!mounted) {
      return;
    }
    setState(() {
      onboardingDone = prefs.getBool(_onboardingSeenKey) ?? false;
      checkedOnboarding = true;
    });
  }

  Future<void> finishOnboarding() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_onboardingSeenKey, true);
    if (!mounted) {
      return;
    }
    setState(() => onboardingDone = true);
  }

  @override
  Widget build(BuildContext context) {
    if (!checkedOnboarding) {
      return const Scaffold(
        backgroundColor: Colors.white,
        body: SizedBox.expand(),
      );
    }

    if (onboardingDone) {
      return AppShell(backendStatus: widget.backendStatus);
    }

    return EpsOnboarding(onFinish: finishOnboarding);
  }
}

class AppShell extends StatelessWidget {
  const AppShell({required this.backendStatus, super.key});

  final BackendBootstrap backendStatus;

  @override
  Widget build(BuildContext context) {
    final store = StoreScope.of(context);
    final user = store.currentUser;

    if (user == null) {
      return AuthScreen(backendStatus: backendStatus);
    }

    if (user.status == AccountStatus.pending) {
      return StatusScreen(
        title: 'حسابك بانتظار القبول',
        message: 'سيظهر لك محتوى قسمك بعد موافقة الإدارة على الحساب.',
        icon: Icons.hourglass_top_rounded,
        color: Colors.orange.shade700,
      );
    }

    if (user.status == AccountStatus.blocked) {
      return StatusScreen(
        title: 'تم تجميد الحساب',
        message: 'يرجى التواصل مع الإدارة لاستعادة صلاحية الدخول.',
        icon: Icons.block_rounded,
        color: Colors.red.shade700,
      );
    }

    if (user.status == AccountStatus.rejected) {
      return StatusScreen(
        title: 'تم رفض الحساب',
        message: 'لم يتم قبول إثبات الدفع أو بيانات التسجيل لهذا الحساب.',
        icon: Icons.cancel_rounded,
        color: Colors.red.shade700,
      );
    }

    if (user.isSubscriptionExpired) {
      return StatusScreen(
        title: 'انتهى الاشتراك',
        message: 'انتهت مدة اشتراكك. يرجى التواصل مع الإدارة لتجديد الحساب.',
        icon: Icons.event_busy_rounded,
        color: Colors.red.shade700,
      );
    }

    return switch (user.role) {
      UserRole.admin =>
        user.adminType == AdminType.schoolManager
            ? const AdminDashboard()
            : const AdminConsole(),
      UserRole.teacher => const TeacherDashboard(),
      UserRole.student => const StudentShell(),
    };
  }
}

class EpsilonBackground extends StatelessWidget {
  const EpsilonBackground({required this.child, super.key});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final base = isDark ? const Color(0xFF0F172A) : epsilonSoft;

    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topRight,
          end: Alignment.bottomLeft,
          colors: [base, isDark ? const Color(0xFF111827) : Colors.white, base],
        ),
      ),
      child: child,
    );
  }
}

class AboutPage extends StatelessWidget {
  const AboutPage({super.key});

  @override
  Widget build(BuildContext context) {
    return const InfoContentPage(
      title: 'من نحن',
      icon: Icons.school_rounded,
      paragraphs: [
        'Epsilon Education تطبيق تعليمي يجمع الطلاب والأساتذة والإدارة في مكان واحد.',
        'هدفنا تنظيم الدروس حسب الأقسام والمواد، وتسهيل متابعة المحتوى التعليمي بطريقة واضحة وآمنة.',
      ],
    );
  }
}

class PrivacyPolicyPage extends StatelessWidget {
  const PrivacyPolicyPage({super.key});

  static final Uri privacyPolicyUrl = Uri.parse(
    'https://epsilon-academy-said-42b07.web.app/privacy-policy/',
  );
  static final Uri deleteAccountUrl = Uri.parse(
    'https://epsilon-academy-said-42b07.web.app/delete-account/',
  );

  Future<void> openUrl(Uri url) async {
    await launchUrl(url, mode: LaunchMode.externalApplication);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF7F9FF),
      appBar: const EpsilonAppBar(title: 'سياسة الخصوصية', showLogout: false),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
        children: [
          const HeaderPanel(
            title: 'سياسة الخصوصية',
            subtitle: 'Epsilon Education',
            icon: Icons.privacy_tip_rounded,
          ),
          const SizedBox(height: 16),
          SectionCard(
            title: 'سياسة الخصوصية',
            icon: Icons.privacy_tip_rounded,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Text(
                  'نستخدم بيانات الحساب فقط لإدارة الدخول، الأقسام، المواد، والدروس داخل التطبيق.',
                  style: TextStyle(
                    color: Color(0xFF374151),
                    height: 1.55,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 10),
                const Text(
                  'صور إثبات الدفع تحفظ للتحقق الإداري ولا تظهر إلا للإدارة المختصة.',
                  style: TextStyle(
                    color: Color(0xFF374151),
                    height: 1.55,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 10),
                const Text(
                  'لا نشارك بيانات المستخدمين مع جهات خارجية داخل هذا الإصدار من التطبيق.',
                  style: TextStyle(
                    color: Color(0xFF374151),
                    height: 1.55,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 16),
                _PolicyLinkButton(
                  icon: Icons.open_in_new_rounded,
                  title: 'رابط سياسة الخصوصية',
                  subtitle: privacyPolicyUrl.toString(),
                  onTap: () => openUrl(privacyPolicyUrl),
                ),
                const SizedBox(height: 10),
                _PolicyLinkButton(
                  icon: Icons.delete_outline_rounded,
                  title: 'رابط طلب حذف الحساب',
                  subtitle: deleteAccountUrl.toString(),
                  onTap: () => openUrl(deleteAccountUrl),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _PolicyLinkButton extends StatelessWidget {
  const _PolicyLinkButton({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return OutlinedButton(
      style: OutlinedButton.styleFrom(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.all(12),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
      onPressed: onTap,
      child: Row(
        textDirection: TextDirection.rtl,
        children: [
          Icon(icon, color: const Color(0xFF2457D6)),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    color: Color(0xFF172033),
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  textDirection: TextDirection.ltr,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Color(0xFF5C6575),
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          const Icon(Icons.arrow_back_ios_new_rounded, size: 16),
        ],
      ),
    );
  }
}

class ContactUsPage extends StatelessWidget {
  const ContactUsPage({super.key});

  Future<void> openWhatsApp() async {
    final uri = Uri.parse(
      'https://wa.me/22249677414?text=${Uri.encodeComponent('السلام عليكم، أريد التواصل مع إدارة Epsilon Education')}',
    );
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF7F9FF),
      appBar: const EpsilonAppBar(title: 'تواصل معنا', showLogout: false),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
        children: [
          const HeaderPanel(
            title: 'تواصل معنا',
            subtitle: 'نحن قريبون منك متى احتجت إلى مساعدة',
            icon: Icons.support_agent_rounded,
          ),
          const SizedBox(height: 16),
          SectionCard(
            title: 'الدعم والمساعدة',
            icon: Icons.favorite_rounded,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Text(
                  'نسعد برسائلكم وملاحظاتكم، فكل سؤال منكم يساعدنا على جعل تجربة التعلم أوضح وأسهل وأقرب لاحتياجاتكم.',
                  style: TextStyle(
                    color: Color(0xFF374151),
                    height: 1.6,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 16),
                FilledButton.icon(
                  style: FilledButton.styleFrom(
                    backgroundColor: const Color(0xFF25D366),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  onPressed: openWhatsApp,
                  icon: const Icon(Icons.chat_rounded),
                  label: const Text(
                    'التواصل عبر واتساب',
                    style: TextStyle(fontWeight: FontWeight.w900),
                  ),
                ),
                const SizedBox(height: 10),
                const Text(
                  '49677414',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Color(0xFF0F766E),
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 18),
          const DeveloperCredit(),
        ],
      ),
    );
  }
}

class DeveloperCredit extends StatelessWidget {
  const DeveloperCredit({super.key});

  @override
  Widget build(BuildContext context) {
    return const Text(
      'تم التطوير بواسطة المطور محمد سعيد مختار الله',
      textAlign: TextAlign.center,
      style: TextStyle(
        color: Color(0xFF6B7280),
        fontSize: 12,
        fontWeight: FontWeight.w700,
      ),
    );
  }
}

class GuestPage extends StatelessWidget {
  const GuestPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF7F9FF),
      appBar: const EpsilonAppBar(title: 'الدخول كزائر', showLogout: false),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
        children: [
          const HeaderPanel(
            title: 'مرحبا بك كزائر',
            subtitle: 'تصفح فكرة التطبيق قبل إنشاء حسابك',
            icon: Icons.person_search_rounded,
          ),
          const SizedBox(height: 16),
          GuestActionCard(
            title: 'الفيديوهات المجانية',
            subtitle: 'شاهد محتوى تعليمي متاح للجميع',
            icon: Icons.play_circle_rounded,
            color: const Color(0xFF2F5BEA),
            onTap: () => Navigator.of(
              context,
            ).push(MaterialPageRoute(builder: (_) => const FreeVideosPage())),
          ),
          const SizedBox(height: 12),
          GuestActionCard(
            title: 'الأرشيف',
            subtitle: 'ملفات ومحتوى محفوظ سننظمه لاحقا',
            icon: Icons.archive_rounded,
            color: const Color(0xFF0F766E),
            onTap: () => Navigator.of(
              context,
            ).push(MaterialPageRoute(builder: (_) => const ArchivePage())),
          ),
        ],
      ),
    );
  }
}

class NationalResultsPage extends StatelessWidget {
  const NationalResultsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: const EpsilonAppBar(
        title: 'نتائج المسابقات الوطنية',
        showLogout: false,
      ),
      body: LayoutBuilder(
        builder: (context, constraints) {
          final contentWidth = min(constraints.maxWidth - 32, 420.0);
          final tileWidth = min((contentWidth - 12) / 2, 204.0);

          return SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 24),
            child: Center(
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  minHeight: max(0, constraints.maxHeight - 32),
                  maxWidth: 420,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const ResultsOffersSection(),
                    const SizedBox(height: 18),
                    Wrap(
                      spacing: 12,
                      runSpacing: 12,
                      alignment: WrapAlignment.center,
                      children: [
                        NationalResultButton(
                          title: 'كونكور',
                          examType: 'concours',
                          icon: Icons.school_rounded,
                          color: const Color(0xFF2457D6),
                          width: tileWidth,
                        ),
                        NationalResultButton(
                          title: 'ابريفة',
                          examType: 'brevet',
                          icon: Icons.menu_book_rounded,
                          color: const Color(0xFF2457D6),
                          width: tileWidth,
                        ),
                        NationalResultButton(
                          title: 'الباكالوريا الدورة الأولى',
                          examType: 'bac-first',
                          icon: Icons.workspace_premium_rounded,
                          color: const Color(0xFF2457D6),
                          width: contentWidth,
                        ),
                        NationalResultButton(
                          title: 'الباكالوريا الدورة التكميلية',
                          examType: 'bac-second',
                          icon: Icons.verified_rounded,
                          color: const Color(0xFF2457D6),
                          width: contentWidth,
                        ),
                        NationalResultButton(
                          title: 'مسابقة الامتياز',
                          examType: 'excellence',
                          icon: Icons.star_rounded,
                          color: const Color(0xFF2457D6),
                          width: contentWidth,
                        ),
                      ],
                    ),
                    const SizedBox(height: 18),
                    const ResultsTextSection(),
                    const SizedBox(height: 18),
                    FilledButton.icon(
                      onPressed: () => Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => const ContactUsPage(),
                        ),
                      ),
                      style: FilledButton.styleFrom(
                        backgroundColor: const Color(0xFF2457D6),
                        foregroundColor: Colors.white,
                        minimumSize: const Size.fromHeight(54),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                      ),
                      icon: const Icon(Icons.support_agent_rounded),
                      label: const Text(
                        'طلب التواصل',
                        style: TextStyle(fontWeight: FontWeight.w900),
                      ),
                    ),
                    const SizedBox(height: 12),
                    const Text(
                      'epsilon | dev. med said mohameden',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: Color(0xFF64748B),
                        fontSize: 13,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

class ResultsOffersSection extends StatefulWidget {
  const ResultsOffersSection({super.key});

  @override
  State<ResultsOffersSection> createState() => _ResultsOffersSectionState();
}

class _ResultsOffersSectionState extends State<ResultsOffersSection> {
  List<OfferSlide> offers = [];
  Timer? timer;
  int index = 0;
  bool didLoad = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!didLoad) {
      didLoad = true;
      unawaited(loadOffers());
    }
  }

  @override
  void dispose() {
    timer?.cancel();
    super.dispose();
  }

  Future<void> loadOffers() async {
    try {
      final loaded = await StoreScope.of(context).offers();
      if (!mounted) {
        return;
      }
      setState(() {
        offers = loaded.where((slide) => slide.imageUrl.isNotEmpty).toList();
        index = 0;
      });
      scheduleNext();
    } catch (_) {
      if (mounted) {
        setState(() => offers = const []);
      }
    }
  }

  void scheduleNext() {
    timer?.cancel();
    if (offers.length < 2) {
      return;
    }
    final current = offers[index];
    timer = Timer(Duration(seconds: current.durationSeconds), () {
      if (!mounted || offers.isEmpty) {
        return;
      }
      setState(() => index = (index + 1) % offers.length);
      scheduleNext();
    });
  }

  @override
  Widget build(BuildContext context) {
    if (offers.isEmpty) {
      return Row(
        children: const [
          Expanded(
            child: ResultsImageCard(
              title: 'العروض',
              image: 'assets/onboarding/content.jpeg',
            ),
          ),
          SizedBox(width: 12),
          Expanded(
            child: ResultsImageCard(
              title: 'تعريف بنا',
              image: 'assets/onboarding/welcome.jpeg',
            ),
          ),
        ],
      );
    }

    final offer = offers[index];
    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: Stack(
        alignment: Alignment.bottomCenter,
        children: [
          SizedBox(
            height: 156,
            width: double.infinity,
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 450),
              child: Image.network(
                offer.imageUrl,
                key: ValueKey(offer.id),
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) => Container(
                  color: const Color(0xFFEFF3FF),
                  alignment: Alignment.center,
                  child: const Icon(
                    Icons.image_not_supported_rounded,
                    color: Color(0xFF2F5BEA),
                    size: 42,
                  ),
                ),
              ),
            ),
          ),
          Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.transparent,
                    Colors.black.withValues(alpha: 0.52),
                  ],
                ),
              ),
            ),
          ),
          if (offers.length > 1)
            Positioned(
              bottom: 10,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(min(offers.length, 8), (dotIndex) {
                  final active = dotIndex == index;
                  return AnimatedContainer(
                    duration: const Duration(milliseconds: 250),
                    width: active ? 18 : 7,
                    height: 7,
                    margin: const EdgeInsets.symmetric(horizontal: 3),
                    decoration: BoxDecoration(
                      color: active
                          ? Colors.white
                          : Colors.white.withValues(alpha: 0.55),
                      borderRadius: BorderRadius.circular(20),
                    ),
                  );
                }),
              ),
            ),
        ],
      ),
    );
  }
}

class ResultsTextSection extends StatefulWidget {
  const ResultsTextSection({super.key});

  @override
  State<ResultsTextSection> createState() => _ResultsTextSectionState();
}

class _ResultsTextSectionState extends State<ResultsTextSection> {
  OfferTextSection? section;
  bool didLoad = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!didLoad) {
      didLoad = true;
      unawaited(loadSection());
    }
  }

  Future<void> loadSection() async {
    try {
      final loaded = await StoreScope.of(context).offerTextSection();
      if (mounted) {
        setState(() => section = loaded);
      }
    } catch (_) {
      if (mounted) {
        setState(
          () => section = const OfferTextSection(
            title: '',
            body: '',
            active: false,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final current = section;
    if (current == null || !current.shouldShow) {
      return const SizedBox.shrink();
    }
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFF),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFDDE6FF)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (current.title.trim().isNotEmpty) ...[
            Text(
              current.title,
              textAlign: TextAlign.right,
              style: const TextStyle(
                color: Color(0xFF1E3A8A),
                fontSize: 17,
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 6),
          ],
          Text(
            current.body,
            textAlign: TextAlign.right,
            style: const TextStyle(
              color: Color(0xFF334155),
              fontSize: 14,
              height: 1.45,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class ResultsImageCard extends StatelessWidget {
  const ResultsImageCard({required this.title, required this.image, super.key});

  final String title;
  final String image;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: Stack(
        alignment: Alignment.bottomCenter,
        children: [
          AspectRatio(
            aspectRatio: 1,
            child: Image.asset(image, fit: BoxFit.cover),
          ),
          Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.transparent,
                    Colors.black.withValues(alpha: 0.56),
                  ],
                ),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(12),
            child: Text(
              title,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class NationalResultButton extends StatelessWidget {
  const NationalResultButton({
    required this.title,
    required this.examType,
    required this.icon,
    required this.color,
    required this.width,
    super.key,
  });

  final String title;
  final String examType;
  final IconData icon;
  final Color color;
  final double width;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: width,
      height: 96,
      child: Material(
        color: color,
        borderRadius: BorderRadius.circular(18),
        elevation: 0,
        child: InkWell(
          onTap: () => Navigator.of(context).push(
            MaterialPageRoute(
              builder: (_) => NationalResultSearchPage(
                examType: examType,
                title: title,
                icon: icon,
              ),
            ),
          ),
          borderRadius: BorderRadius.circular(18),
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Row(
              textDirection: TextDirection.rtl,
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.16),
                    borderRadius: BorderRadius.circular(15),
                  ),
                  child: Icon(icon, color: Colors.white, size: 28),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    title,
                    textAlign: TextAlign.right,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 17,
                      fontWeight: FontWeight.w900,
                      height: 1.2,
                    ),
                  ),
                ),
                const SizedBox(width: 6),
                const Icon(
                  Icons.arrow_back_rounded,
                  color: Colors.white,
                  size: 20,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class NationalResultSearchPage extends StatefulWidget {
  const NationalResultSearchPage({
    required this.examType,
    required this.title,
    required this.icon,
    super.key,
  });

  final String examType;
  final String title;
  final IconData icon;

  @override
  State<NationalResultSearchPage> createState() =>
      _NationalResultSearchPageState();
}

class _NationalResultSearchPageState extends State<NationalResultSearchPage> {
  final queryController = TextEditingController();
  final centerController = TextEditingController();
  late final AudioPlayer applausePlayer;
  Timer? celebrationTimer;
  List<NationalExamResult> results = [];
  List<String> concoursCenters = [];
  String? selectedConcoursCenter;
  bool isSearching = false;
  bool isUploading = false;
  bool isLoadingCenters = false;
  bool didRequestConcoursCenters = false;
  bool showCelebration = false;
  String? message;

  @override
  void initState() {
    super.initState();
    applausePlayer = AudioPlayer();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (widget.examType == 'concours' && !didRequestConcoursCenters) {
      didRequestConcoursCenters = true;
      unawaited(loadConcoursCenters());
    }
  }

  @override
  void dispose() {
    celebrationTimer?.cancel();
    applausePlayer.dispose();
    queryController.dispose();
    centerController.dispose();
    super.dispose();
  }

  bool get canUpload {
    final user = StoreScope.of(context).currentUser;
    return user?.role == UserRole.admin;
  }

  bool isSuccessfulResult(NationalExamResult result) {
    final decision = result.decision.trim().toLowerCase();
    return result.hasConcoursPassingScore ||
        decision.contains('admis') ||
        decision.contains('ناجح');
  }

  Future<void> loadConcoursCenters() async {
    setState(() => isLoadingCenters = true);
    try {
      final centers = await StoreScope.of(
        context,
      ).nationalResultCenters(examType: widget.examType);
      if (!mounted) {
        return;
      }
      setState(() {
        concoursCenters = centers;
        selectedConcoursCenter = centers.contains(selectedConcoursCenter)
            ? selectedConcoursCenter
            : null;
        if (selectedConcoursCenter == null) {
          centerController.clear();
        }
      });
    } catch (error) {
      if (mounted) {
        setState(() => message = error.toString());
      }
    } finally {
      if (mounted) {
        setState(() => isLoadingCenters = false);
      }
    }
  }

  Future<void> triggerCelebration() async {
    celebrationTimer?.cancel();
    setState(() => showCelebration = true);
    try {
      await applausePlayer.stop();
      await applausePlayer.setVolume(1);
      await applausePlayer.play(AssetSource('sounds/applause.wav'));
    } catch (error) {
      debugPrint('Celebration sound skipped: $error');
    }
    celebrationTimer = Timer(const Duration(milliseconds: 5200), () {
      if (mounted) {
        setState(() => showCelebration = false);
      }
    });
  }

  Future<void> search() async {
    final query = queryController.text.trim();
    final isNumberQuery = RegExp(r'^\d+$').hasMatch(query);
    final typedCenter = centerController.text.trim();
    final concoursCenter =
        selectedConcoursCenter?.trim() ??
        (concoursCenters.contains(typedCenter) ? typedCenter : null);
    if (widget.examType == 'concours' &&
        (concoursCenter == null || concoursCenter.isEmpty)) {
      setState(() {
        message = 'اختر مركز الامتحان أولا.';
        results = [];
      });
      return;
    }
    if (!isNumberQuery && query.length < 2) {
      setState(() {
        message = 'اكتب رقم المترشح أو جزءا من الاسم الكامل.';
        results = [];
      });
      return;
    }
    setState(() {
      isSearching = true;
      message = null;
    });
    try {
      final found = await StoreScope.of(context).searchNationalResults(
        examType: widget.examType,
        query: query,
        center: widget.examType == 'concours' ? concoursCenter : null,
      );
      final displayResults = widget.examType == 'concours' && isNumberQuery
          ? found.take(1).toList()
          : found;
      setState(() {
        results = displayResults;
        message = displayResults.isEmpty
            ? 'لم يتم العثور على نتيجة مطابقة.'
            : null;
      });
      if (displayResults.any(isSuccessfulResult)) {
        await triggerCelebration();
      }
    } catch (error) {
      setState(() => message = error.toString());
    } finally {
      if (mounted) {
        setState(() => isSearching = false);
      }
    }
  }

  Future<void> uploadExcel() async {
    final store = StoreScope.of(context);
    final file = await NativeFilePicker.pickExcel();
    if (file == null) {
      return;
    }

    setState(() {
      isUploading = true;
      message = null;
    });
    try {
      final count = await store.uploadNationalResults(
        examType: widget.examType,
        filePath: file.path,
        fileName: file.name,
      );
      setState(() {
        results = [];
        queryController.clear();
        message = 'تم استيراد $count نتيجة بنجاح.';
      });
    } catch (error) {
      setState(() => message = error.toString());
    } finally {
      if (mounted) {
        setState(() => isUploading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF7F9FF),
      appBar: EpsilonAppBar(title: widget.title, showLogout: false),
      body: Stack(
        children: [
          ListView(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
            children: [
              HeaderPanel(
                title: 'نتائج ${widget.title}',
                subtitle: 'ابحث برقم المترشح أو الاسم الكامل',
                icon: widget.icon,
              ),
              const SizedBox(height: 16),
              SectionCard(
                title: 'البحث عن نتيجة',
                icon: Icons.search_rounded,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    if (widget.examType == 'concours') ...[
                      Autocomplete<String>(
                        optionsBuilder: (textEditingValue) {
                          final query = textEditingValue.text.trim();
                          final matches = query.isEmpty
                              ? concoursCenters
                              : concoursCenters.where(
                                  (center) => center.contains(query),
                                );
                          return matches.take(30);
                        },
                        onSelected: (value) {
                          setState(() {
                            selectedConcoursCenter = value;
                            centerController.text = value;
                            results = [];
                            message = null;
                          });
                        },
                        fieldViewBuilder:
                            (
                              context,
                              textEditingController,
                              focusNode,
                              onFieldSubmitted,
                            ) {
                              if (textEditingController.text !=
                                  centerController.text) {
                                textEditingController.text =
                                    centerController.text;
                              }
                              return TextField(
                                controller: textEditingController,
                                focusNode: focusNode,
                                enabled: !isLoadingCenters,
                                textInputAction: TextInputAction.next,
                                onChanged: (value) {
                                  centerController.text = value;
                                  if (value.trim() != selectedConcoursCenter) {
                                    selectedConcoursCenter = null;
                                  }
                                },
                                decoration: InputDecoration(
                                  labelText: isLoadingCenters
                                      ? 'جاري تحميل مراكز الامتحان...'
                                      : 'مركز الامتحان',
                                  prefixIcon: const Icon(
                                    Icons.account_balance_rounded,
                                  ),
                                ),
                              );
                            },
                      ),
                      const SizedBox(height: 12),
                    ],
                    TextField(
                      controller: queryController,
                      textInputAction: TextInputAction.search,
                      onSubmitted: (_) => search(),
                      decoration: const InputDecoration(
                        labelText: 'رقم المترشح أو الاسم الكامل',
                        prefixIcon: Icon(Icons.badge_rounded),
                      ),
                    ),
                    const SizedBox(height: 12),
                    FilledButton.icon(
                      onPressed: isSearching ? null : search,
                      icon: isSearching
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.search_rounded),
                      label: const Text('بحث'),
                    ),
                    if (canUpload) ...[
                      const SizedBox(height: 10),
                      OutlinedButton.icon(
                        onPressed: isUploading ? null : uploadExcel,
                        icon: isUploading
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              )
                            : const Icon(Icons.upload_file_rounded),
                        label: const Text('رفع ملف Excel للنتائج'),
                      ),
                    ],
                  ],
                ),
              ),
              if (message != null) ...[
                const SizedBox(height: 14),
                EmptyState(text: message!),
              ],
              if (results.isNotEmpty) ...[
                const SizedBox(height: 16),
                ...results.map(
                  (result) => Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: NationalResultCard(result: result),
                  ),
                ),
              ],
            ],
          ),
          if (showCelebration) const CelebrationOverlay(),
        ],
      ),
    );
  }
}

class NationalResultCard extends StatelessWidget {
  const NationalResultCard({required this.result, super.key});

  final NationalExamResult result;

  ResultDecisionStyle get decisionStyle {
    if (result.hasConcoursPassingScore) {
      return const ResultDecisionStyle(
        title: 'منصة ابسيلون تبارك لك',
        subtitle: 'وتهنئك على نجاحك',
        color: Color(0xFF149255),
        background: Color(0xFFEFFAF3),
        border: Color(0xFFBFE8CF),
        icon: Icons.verified_rounded,
      );
    }
    final normalized = result.decision.trim().toLowerCase();
    if (normalized.contains('sessionnaire')) {
      return const ResultDecisionStyle(
        title: 'منصة ابسيلون تتمنى لك حظاً أوفر',
        subtitle: 'في الدورة التكميلية',
        color: Color(0xFF2563EB),
        background: Color(0xFFEFF6FF),
        border: Color(0xFFBFDBFE),
        icon: Icons.auto_awesome_rounded,
      );
    }
    if (normalized.contains('admis') || normalized.contains('ناجح')) {
      return const ResultDecisionStyle(
        title: 'منصة ابسيلون تبارك لك',
        subtitle: 'وتهنئك على نجاحك',
        color: Color(0xFF149255),
        background: Color(0xFFEFFAF3),
        border: Color(0xFFBFE8CF),
        icon: Icons.verified_rounded,
      );
    }
    return const ResultDecisionStyle(
      title: 'منصة ابسيلون تتمنى لك',
      subtitle: 'حظاً أوفر',
      color: Color(0xFFB45309),
      background: Color(0xFFFFF7ED),
      border: Color(0xFFFED7AA),
      icon: Icons.favorite_rounded,
    );
  }

  @override
  Widget build(BuildContext context) {
    final hasDecision = result.decision.trim().isNotEmpty;
    final style = hasDecision || result.hasConcoursPassingScore
        ? decisionStyle
        : null;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (style != null) ...[
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: style.background,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: style.border),
            ),
            child: Row(
              textDirection: TextDirection.rtl,
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(13),
                  child: Container(
                    width: 44,
                    height: 44,
                    color: Colors.white,
                    child: Image.asset(
                      'assets/onboarding/epsilon_logo.jpeg',
                      fit: BoxFit.cover,
                    ),
                  ),
                ),
                const SizedBox(width: 11),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        style.title,
                        textAlign: TextAlign.right,
                        style: TextStyle(
                          color: style.color,
                          fontSize: 17,
                          fontWeight: FontWeight.w900,
                          height: 1.15,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        style.subtitle,
                        textAlign: TextAlign.right,
                        style: const TextStyle(
                          color: Color(0xFF475569),
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          height: 1.2,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  width: 30,
                  height: 30,
                  decoration: BoxDecoration(
                    color: style.color,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(style.icon, color: Colors.white, size: 19),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
        ],
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: const Color(0xFFE2E8F0)),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF0F172A).withValues(alpha: 0.04),
                blurRadius: 18,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                textDirection: TextDirection.rtl,
                children: [
                  const Icon(
                    Icons.badge_rounded,
                    color: Color(0xFF2457D6),
                    size: 22,
                  ),
                  const SizedBox(width: 8),
                  const Text(
                    'بيانات المترشح',
                    textAlign: TextAlign.right,
                    style: TextStyle(
                      color: Color(0xFF1E3A8A),
                      fontSize: 17,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              ResultDataRow(
                icon: Icons.person_outline_rounded,
                label: 'الاسم الكامل',
                value: result.fullName,
              ),
              ResultDataRow(
                icon: Icons.confirmation_number_outlined,
                label: 'رقم المترشح',
                value: result.candidateNumber,
              ),
              ResultDataRow(
                icon: Icons.school_outlined,
                label: 'الشعبة',
                value: result.series,
              ),
              ResultDataRow(
                icon: Icons.account_balance_rounded,
                label: 'مركز الامتحان',
                value: result.centerName,
              ),
              ResultDataRow(
                icon: Icons.location_on_outlined,
                label: 'الولاية',
                value: result.wilaya,
              ),
              ResultDataRow(
                icon: Icons.query_stats_rounded,
                label: 'المعدل',
                value: result.score,
              ),
              ResultDataRow(
                icon: Icons.fact_check_outlined,
                label: 'القرار',
                value: result.decision,
              ),
              ResultDataRow(
                icon: Icons.workspace_premium_outlined,
                label: 'الرتبة',
                value: result.rank,
                isLast: true,
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class CelebrationOverlay extends StatefulWidget {
  const CelebrationOverlay({super.key});

  @override
  State<CelebrationOverlay> createState() => _CelebrationOverlayState();
}

class _CelebrationOverlayState extends State<CelebrationOverlay>
    with SingleTickerProviderStateMixin {
  late final AnimationController controller;

  @override
  void initState() {
    super.initState();
    controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 4600),
    )..forward();
  }

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: AnimatedBuilder(
        animation: controller,
        builder: (context, _) {
          return CustomPaint(
            painter: CelebrationPainter(progress: controller.value),
            size: Size.infinite,
          );
        },
      ),
    );
  }
}

class CelebrationPainter extends CustomPainter {
  const CelebrationPainter({required this.progress});

  final double progress;

  static const colors = [
    Color(0xFF149255),
    Color(0xFF2457D6),
    Color(0xFFF59E0B),
    Color(0xFFEF4444),
    Color(0xFF8B5CF6),
    Color(0xFF06B6D4),
  ];

  @override
  void paint(Canvas canvas, Size size) {
    if (size.isEmpty) {
      return;
    }
    final fadeIn = (progress / 0.12).clamp(0.0, 1.0);
    final fadeOut = ((1 - progress) / 0.22).clamp(0.0, 1.0);
    final opacity = min(fadeIn, fadeOut);
    final paint = Paint();

    for (var i = 0; i < 190; i++) {
      final random = Random(i * 97);
      final delay = random.nextDouble() * 0.34;
      final local = ((progress - delay) / (1 - delay)).clamp(0.0, 1.0);
      if (local <= 0) {
        continue;
      }
      final drift = sin((local * 2.8 + random.nextDouble()) * pi) * 26;
      final x = size.width * random.nextDouble() + drift;
      final y =
          -32 +
          size.height * (0.18 + random.nextDouble() * 0.84) * local +
          24 * sin((local + random.nextDouble()) * pi * 2);
      final angle = local * pi * (2 + random.nextDouble() * 6);
      final width = 5.0 + random.nextDouble() * 10;
      final height = 4.0 + random.nextDouble() * 12;
      final alpha = opacity * (0.55 + random.nextDouble() * 0.45);

      paint.color = colors[i % colors.length].withValues(alpha: alpha);
      canvas.save();
      canvas.translate(x, y);
      canvas.rotate(angle);
      if (i % 3 == 0) {
        canvas.drawCircle(Offset.zero, width * 0.55, paint);
      } else if (i % 7 == 0) {
        paint
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2.2;
        canvas.drawCircle(Offset.zero, width * 0.72, paint);
        paint.style = PaintingStyle.fill;
      } else {
        canvas.drawRRect(
          RRect.fromRectAndRadius(
            Rect.fromCenter(center: Offset.zero, width: width, height: height),
            const Radius.circular(1.5),
          ),
          paint,
        );
      }
      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(covariant CelebrationPainter oldDelegate) {
    return oldDelegate.progress != progress;
  }
}

class ResultDecisionStyle {
  const ResultDecisionStyle({
    required this.title,
    required this.subtitle,
    required this.color,
    required this.background,
    required this.border,
    required this.icon,
  });

  final String title;
  final String subtitle;
  final Color color;
  final Color background;
  final Color border;
  final IconData icon;
}

class ResultDataRow extends StatelessWidget {
  const ResultDataRow({
    required this.icon,
    required this.label,
    required this.value,
    this.isLast = false,
    super.key,
  });

  final IconData icon;
  final String label;
  final String value;
  final bool isLast;

  @override
  Widget build(BuildContext context) {
    if (value.trim().isEmpty) {
      return const SizedBox.shrink();
    }
    return Container(
      padding: EdgeInsets.only(bottom: isLast ? 0 : 10, top: isLast ? 0 : 2),
      margin: EdgeInsets.only(bottom: isLast ? 0 : 10),
      decoration: BoxDecoration(
        border: isLast
            ? null
            : const Border(bottom: BorderSide(color: Color(0xFFE5E7EB))),
      ),
      child: Row(
        textDirection: TextDirection.rtl,
        children: [
          Icon(icon, color: const Color(0xFF2457D6), size: 20),
          const SizedBox(width: 8),
          SizedBox(
            width: 108,
            child: Text(
              label,
              textAlign: TextAlign.right,
              style: const TextStyle(
                color: Color(0xFF475569),
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              value,
              textAlign: TextAlign.left,
              style: const TextStyle(
                color: Color(0xFF111827),
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class ResultInfoRow extends StatelessWidget {
  const ResultInfoRow({required this.label, required this.value, super.key});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    if (value.trim().isEmpty) {
      return const SizedBox.shrink();
    }
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        textDirection: TextDirection.rtl,
        children: [
          Text(
            '$label:',
            style: const TextStyle(
              color: Color(0xFF64748B),
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              value,
              textAlign: TextAlign.right,
              style: const TextStyle(
                color: Color(0xFF111827),
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class GuestActionCard extends StatelessWidget {
  const GuestActionCard({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.color,
    required this.onTap,
    super.key,
  });

  final String title;
  final String subtitle;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: const Color(0xFFE8EEFF)),
          ),
          child: Row(
            children: [
              Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: color, size: 30),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        color: Color(0xFF111827),
                        fontSize: 17,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      style: const TextStyle(
                        color: Color(0xFF6B7280),
                        height: 1.35,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(Icons.arrow_back_ios_new_rounded, size: 18),
            ],
          ),
        ),
      ),
    );
  }
}

class FreeVideosPage extends StatelessWidget {
  const FreeVideosPage({super.key});

  @override
  Widget build(BuildContext context) {
    final store = StoreScope.of(context);

    return GuestContentPage(
      title: 'الفيديوهات المجانية',
      subtitle: 'محتوى مجاني متاح للزوار',
      icon: Icons.play_circle_rounded,
      emptyText: 'لا توجد فيديوهات مجانية حاليا.',
      items: store.guestVideos,
      viewerKind: SecureContentKind.video,
    );
  }
}

class ArchivePage extends StatelessWidget {
  const ArchivePage({super.key});

  @override
  Widget build(BuildContext context) {
    final store = StoreScope.of(context);

    return GuestContentPage(
      title: 'الأرشيف',
      subtitle: 'ملفات PDF محفوظة للزوار',
      icon: Icons.archive_rounded,
      emptyText: 'لا توجد ملفات في الأرشيف حاليا.',
      items: store.archiveFiles,
      viewerKind: SecureContentKind.pdf,
    );
  }
}

class GuestContentPage extends StatefulWidget {
  const GuestContentPage({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.emptyText,
    required this.items,
    required this.viewerKind,
    super.key,
  });

  final String title;
  final String subtitle;
  final IconData icon;
  final String emptyText;
  final List<GuestContentItem> items;
  final SecureContentKind viewerKind;

  @override
  State<GuestContentPage> createState() => _GuestContentPageState();
}

class _GuestContentPageState extends State<GuestContentPage> {
  String? selectedCourseId;

  @override
  Widget build(BuildContext context) {
    final store = StoreScope.of(context);
    final courses = [...store.courses]
      ..sort((a, b) => a.title.compareTo(b.title));
    final filteredItems = selectedCourseId == null
        ? <GuestContentItem>[]
        : widget.items
              .where((item) => item.courseId == selectedCourseId)
              .toList();

    return Scaffold(
      backgroundColor: const Color(0xFFF7F9FF),
      appBar: EpsilonAppBar(title: widget.title, showLogout: false),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
        children: [
          HeaderPanel(
            title: widget.title,
            subtitle: widget.subtitle,
            icon: widget.icon,
          ),
          const SizedBox(height: 16),
          SectionCard(
            title: 'اختر القسم',
            icon: Icons.menu_book_rounded,
            child: courses.isEmpty
                ? const EmptyState(text: 'لا توجد أقسام متاحة حاليا.')
                : DropdownButtonFormField<String>(
                    initialValue: selectedCourseId,
                    decoration: const InputDecoration(
                      labelText: 'القسم',
                      prefixIcon: Icon(Icons.school_rounded),
                    ),
                    items: courses
                        .map(
                          (course) => DropdownMenuItem(
                            value: course.id,
                            child: Text(course.title),
                          ),
                        )
                        .toList(),
                    onChanged: (value) =>
                        setState(() => selectedCourseId = value),
                  ),
          ),
          const SizedBox(height: 16),
          SectionCard(
            title: selectedCourseId == null
                ? 'محتوى القسم'
                : store.courseById(selectedCourseId)?.title ?? widget.title,
            icon: widget.icon,
            child: selectedCourseId == null
                ? const EmptyState(text: 'اختر القسم لعرض المحتوى الخاص به.')
                : filteredItems.isEmpty
                ? EmptyState(text: widget.emptyText)
                : Column(
                    children: filteredItems
                        .map(
                          (item) => GuestContentTile(
                            item: item,
                            icon: widget.icon,
                            viewerKind: widget.viewerKind,
                          ),
                        )
                        .toList(),
                  ),
          ),
        ],
      ),
    );
  }
}

class GuestContentTile extends StatelessWidget {
  const GuestContentTile({
    required this.item,
    required this.icon,
    required this.viewerKind,
    super.key,
  });

  final GuestContentItem item;
  final IconData icon;
  final SecureContentKind viewerKind;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: Icon(icon, color: const Color(0xFF2F5BEA)),
      title: Text(
        item.title,
        style: const TextStyle(fontWeight: FontWeight.w900),
      ),
      subtitle: Text(
        item.description.trim().isEmpty ? 'اضغط للعرض' : item.description,
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
      ),
      trailing: const Icon(Icons.arrow_back_ios_new_rounded, size: 16),
      onTap: () => Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => SecureContentViewerPage(
            title: item.title,
            url: item.url,
            kind: viewerKind,
          ),
        ),
      ),
    );
  }
}

class InfoContentPage extends StatelessWidget {
  const InfoContentPage({
    required this.title,
    required this.icon,
    required this.paragraphs,
    super.key,
  });

  final String title;
  final IconData icon;
  final List<String> paragraphs;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF7F9FF),
      appBar: EpsilonAppBar(title: title, showLogout: false),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
        children: [
          HeaderPanel(title: title, subtitle: 'Epsilon Education', icon: icon),
          const SizedBox(height: 16),
          SectionCard(
            title: title,
            icon: icon,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: paragraphs
                  .map(
                    (paragraph) => Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: Text(
                        paragraph,
                        style: const TextStyle(
                          color: Color(0xFF374151),
                          height: 1.55,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  )
                  .toList(),
            ),
          ),
        ],
      ),
    );
  }
}

class StudentCourseSelectionPage extends StatefulWidget {
  const StudentCourseSelectionPage({
    required this.name,
    required this.phone,
    required this.password,
    super.key,
  });

  final String name;
  final String phone;
  final String password;

  @override
  State<StudentCourseSelectionPage> createState() =>
      _StudentCourseSelectionPageState();
}

class _StudentCourseSelectionPageState
    extends State<StudentCourseSelectionPage> {
  String query = '';

  @override
  Widget build(BuildContext context) {
    final store = StoreScope.of(context);
    final courses = store.courses.where((course) {
      final normalizedQuery = query.trim().toLowerCase();
      if (normalizedQuery.isEmpty) return true;
      final haystack = [
        course.title,
        course.description,
        ...course.subjects,
        ...course.subjectTeachers.values,
      ].join(' ').toLowerCase();
      return haystack.contains(normalizedQuery);
    }).toList();

    return Scaffold(
      backgroundColor: const Color(0xFFF7F9FF),
      appBar: AppBar(
        backgroundColor: const Color(0xFFF7F9FF),
        surfaceTintColor: const Color(0xFFF7F9FF),
        elevation: 0,
        centerTitle: true,
        leading: IconButton(
          tooltip: 'رجوع',
          onPressed: () => Navigator.of(context).pop(),
          icon: const Icon(Icons.arrow_back_rounded),
        ),
        title: const Text(
          'اختر قسمك',
          style: TextStyle(fontWeight: FontWeight.w900),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(14, 6, 14, 24),
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: const Color(0xFFDDE7FF)),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF2F5BEA).withValues(alpha: 0.06),
                  blurRadius: 24,
                  offset: const Offset(0, 12),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                TextField(
                  onChanged: (value) => setState(() => query = value),
                  textDirection: TextDirection.rtl,
                  decoration: InputDecoration(
                    hintText: 'ابحث باسم القسم أو المادة أو الأستاذ',
                    prefixIcon: const Icon(Icons.search_rounded),
                    filled: true,
                    fillColor: const Color(0xFFF4F7FF),
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 12,
                    ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: BorderSide.none,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 18),
          Row(
            textDirection: TextDirection.rtl,
            children: [
              Container(
                width: 4,
                height: 24,
                decoration: BoxDecoration(
                  color: const Color(0xFF2F5BEA),
                  borderRadius: BorderRadius.circular(99),
                ),
              ),
              const SizedBox(width: 8),
              Text(
                'الأقسام المتاحة',
                style: Theme.of(
                  context,
                ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w900),
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (store.courses.isEmpty)
            const SectionCard(
              title: 'لا توجد أقسام',
              icon: Icons.menu_book_rounded,
              child: EmptyState(text: 'انتظر الإدارة حتى تضيف قسما متاحا.'),
            )
          else if (courses.isEmpty)
            const SectionCard(
              title: 'لا توجد نتائج',
              icon: Icons.search_off_rounded,
              child: EmptyState(text: 'جرّب كلمة بحث مختلفة.'),
            )
          else
            Column(
              children: courses.map((course) {
                return Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: StudentCourseCard(
                    course: course,
                    onFullCourse: () {
                      final subjects = course.subjects;
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => StudentPaymentPage(
                            name: widget.name,
                            phone: widget.phone,
                            password: widget.password,
                            courseId: course.id,
                            selectedSubjects: subjects,
                            subscriptionLabel: 'القسم كامل',
                            paymentAmount: course.price.trim().isEmpty
                                ? store.paymentAmount
                                : course.price.trim(),
                          ),
                        ),
                      );
                    },
                    onPickSubjects: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => StudentSubjectSelectionPage(
                            name: widget.name,
                            phone: widget.phone,
                            password: widget.password,
                            course: course,
                          ),
                        ),
                      );
                    },
                  ),
                );
              }).toList(),
            ),
        ],
      ),
    );
  }
}

class StudentCourseCard extends StatelessWidget {
  const StudentCourseCard({
    required this.course,
    required this.onFullCourse,
    required this.onPickSubjects,
    super.key,
  });

  final Course course;
  final VoidCallback onFullCourse;
  final VoidCallback onPickSubjects;

  @override
  Widget build(BuildContext context) {
    final store = StoreScope.of(context);
    final schoolClass = store.classById(course.classId);
    final accent = courseAccent(course.title);
    final teacherCount = course.subjectTeachers.values.toSet().length;
    final subtitle = courseTitleLine(course.title, schoolClass?.level);

    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        onTap: onPickSubjects,
        borderRadius: BorderRadius.circular(18),
        child: Ink(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: accent.withValues(alpha: 0.22)),
            boxShadow: [
              BoxShadow(
                color: accent.withValues(alpha: 0.07),
                blurRadius: 22,
                offset: const Offset(0, 12),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          course.title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: accent,
                            fontSize: 22,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        const SizedBox(height: 5),
                        Text(
                          subtitle,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: epsilonInk,
                            fontWeight: FontWeight.w800,
                            height: 1.25,
                          ),
                        ),
                        if (course.description.trim().isNotEmpty) ...[
                          const SizedBox(height: 6),
                          Text(
                            course.description,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: epsilonMuted,
                              height: 1.35,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 7,
                    ),
                    decoration: BoxDecoration(
                      color: accent.withValues(alpha: 0.10),
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Text(
                      course.price.trim().isEmpty
                          ? 'سعر القسم غير محدد'
                          : 'القسم كامل: ${course.price}',
                      style: TextStyle(
                        color: accent,
                        fontWeight: FontWeight.w900,
                        fontSize: 12,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  InfoChip(
                    icon: Icons.subject_rounded,
                    text: '${course.subjects.length} مواد',
                    color: accent,
                  ),
                  InfoChip(
                    icon: Icons.person_rounded,
                    text: teacherCount == 0
                        ? 'بانتظار أستاذ'
                        : '$teacherCount أساتذة',
                    color: epsilonTeal,
                  ),
                ],
              ),
              const SizedBox(height: 14),
              if (course.subjects.isNotEmpty) ...[
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF8FAFF),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: const Color(0xFFE4EBFB)),
                  ),
                  child: Column(
                    children: [
                      for (final subject in course.subjects.take(3))
                        Padding(
                          padding: const EdgeInsets.only(bottom: 7),
                          child: Row(
                            children: [
                              Container(
                                width: 7,
                                height: 7,
                                decoration: BoxDecoration(
                                  color: accent,
                                  borderRadius: BorderRadius.circular(99),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  subject,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    color: epsilonInk,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Flexible(
                                child: Text(
                                  course.subjectPrices[subject]
                                              ?.trim()
                                              .isEmpty ??
                                          true
                                      ? 'سعر غير محدد'
                                      : course.subjectPrices[subject]!,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    color:
                                        course.subjectPrices[subject]
                                                ?.trim()
                                                .isEmpty ??
                                            true
                                        ? epsilonMuted
                                        : accent,
                                    fontSize: 12,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                    ],
                  ),
                ),
                const SizedBox(height: 14),
              ],
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: course.subjects.isEmpty
                          ? null
                          : onPickSubjects,
                      style: OutlinedButton.styleFrom(
                        foregroundColor: accent,
                        side: BorderSide(color: accent.withValues(alpha: 0.55)),
                        minimumSize: const Size.fromHeight(44),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(13),
                        ),
                      ),
                      icon: const Icon(Icons.tune_rounded, size: 18),
                      label: const Text('اختيار مواد'),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: FilledButton.icon(
                      onPressed: onFullCourse,
                      style: FilledButton.styleFrom(
                        backgroundColor: accent,
                        minimumSize: const Size.fromHeight(44),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(13),
                        ),
                      ),
                      icon: const Icon(Icons.done_all_rounded, size: 18),
                      label: const Text('القسم كامل'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class InfoChip extends StatelessWidget {
  const InfoChip({
    required this.icon,
    required this.text,
    required this.color,
    super.key,
  });

  final IconData icon;
  final String text;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 15, color: color),
          const SizedBox(width: 5),
          Text(
            text,
            style: TextStyle(
              color: color,
              fontSize: 12,
              fontWeight: FontWeight.w900,
            ),
          ),
        ],
      ),
    );
  }
}

class StudentSubjectSelectionPage extends StatefulWidget {
  const StudentSubjectSelectionPage({
    required this.name,
    required this.phone,
    required this.password,
    required this.course,
    super.key,
  });

  final String name;
  final String phone;
  final String password;
  final Course course;

  @override
  State<StudentSubjectSelectionPage> createState() =>
      _StudentSubjectSelectionPageState();
}

class _StudentSubjectSelectionPageState
    extends State<StudentSubjectSelectionPage> {
  late final Set<String> selectedSubjects = <String>{};
  String? error;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF7F9FF),
      appBar: const EpsilonAppBar(title: 'اختيار المواد', showLogout: false),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
        children: [
          SubjectSelectionHero(course: widget.course),
          const SizedBox(height: 16),
          SectionCard(
            title: 'المواد المتاحة',
            icon: Icons.subject_rounded,
            child: Column(
              children: [
                for (final subject in widget.course.subjects) ...[
                  _SubjectChoiceTile(
                    subject: subject,
                    teacherName: widget.course.subjectTeachers[subject],
                    price: widget.course.subjectPrices[subject],
                    selected: selectedSubjects.contains(subject),
                    accent: courseAccent(widget.course.title),
                    onChanged: (value) {
                      setState(() {
                        if (value == true) {
                          selectedSubjects.add(subject);
                        } else {
                          selectedSubjects.remove(subject);
                        }
                        error = null;
                      });
                    },
                  ),
                  const SizedBox(height: 10),
                ],
                if (widget.course.subjects.isEmpty)
                  const EmptyState(text: 'لم تتم إضافة مواد لهذا القسم بعد.'),
                if (widget.course.subjects.isNotEmpty)
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: courseAccent(
                        widget.course.title,
                      ).withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          Icons.touch_app_rounded,
                          color: courseAccent(widget.course.title),
                          size: 18,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'يمكنك اختيار مادة واحدة أو أكثر حسب حاجتك.',
                            style: TextStyle(
                              color: courseAccent(widget.course.title),
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                if (selectedSubjects.isNotEmpty) ...[
                  const SizedBox(height: 10),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: const Color(0xFFDDE7FF)),
                    ),
                    child: Row(
                      children: [
                        const Icon(
                          Icons.payments_rounded,
                          color: Color(0xFF2F5BEA),
                        ),
                        const SizedBox(width: 8),
                        const Expanded(
                          child: Text(
                            'المبلغ المتوقع',
                            style: TextStyle(
                              color: epsilonInk,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                        ),
                        Text(
                          selectedSubjectsAmount(
                            widget.course,
                            selectedSubjects,
                          ),
                          style: const TextStyle(
                            color: Color(0xFF2F5BEA),
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
                if (error != null) ...[
                  const SizedBox(height: 8),
                  Text(error!, style: TextStyle(color: Colors.red.shade700)),
                ],
                const SizedBox(height: 12),
                FilledButton.icon(
                  onPressed: () {
                    if (selectedSubjects.isEmpty) {
                      setState(() => error = 'اختر مادة واحدة على الأقل.');
                      return;
                    }
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => StudentPaymentPage(
                          name: widget.name,
                          phone: widget.phone,
                          password: widget.password,
                          courseId: widget.course.id,
                          selectedSubjects: selectedSubjects.toList(),
                          subscriptionLabel: 'مواد مختارة',
                          paymentAmount: selectedSubjectsAmount(
                            widget.course,
                            selectedSubjects,
                          ),
                        ),
                      ),
                    );
                  },
                  icon: const Icon(Icons.arrow_back_rounded),
                  label: const Text('التالي'),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class SubjectSelectionHero extends StatelessWidget {
  const SubjectSelectionHero({required this.course, super.key});

  final Course course;

  @override
  Widget build(BuildContext context) {
    final accent = courseAccent(course.title);

    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF111B3D),
        borderRadius: BorderRadius.circular(22),
        boxShadow: [
          BoxShadow(
            color: accent.withValues(alpha: 0.20),
            blurRadius: 28,
            offset: const Offset(0, 16),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Stack(
        children: [
          Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: AlignmentDirectional.topStart,
                  end: AlignmentDirectional.bottomEnd,
                  colors: [
                    const Color(0xFF111B3D),
                    accent.withValues(alpha: 0.94),
                    epsilonTeal.withValues(alpha: 0.86),
                  ],
                ),
              ),
            ),
          ),
          PositionedDirectional(
            top: -18,
            end: -28,
            child: Transform.rotate(
              angle: -0.32,
              child: Container(
                width: 150,
                height: 54,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.10),
                  borderRadius: BorderRadius.circular(999),
                ),
              ),
            ),
          ),
          PositionedDirectional(
            bottom: -14,
            start: -24,
            child: Transform.rotate(
              angle: -0.32,
              child: Container(
                width: 180,
                height: 42,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(999),
                ),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(18),
            child: Row(
              children: [
                Container(
                  width: 58,
                  height: 58,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(18),
                  ),
                  child: Icon(
                    Icons.fact_check_rounded,
                    color: accent,
                    size: 32,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        course.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 25,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 0,
                        ),
                      ),
                      const SizedBox(height: 8),
                      const TypewriterLine(
                        text: 'اختر المواد التي تريد الاشتراك فيها',
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class TypewriterLine extends StatefulWidget {
  const TypewriterLine({required this.text, super.key});

  final String text;

  @override
  State<TypewriterLine> createState() => _TypewriterLineState();
}

class _TypewriterLineState extends State<TypewriterLine> {
  Timer? timer;
  int visibleCharacters = 0;
  bool showCursor = true;

  @override
  void initState() {
    super.initState();
    timer = Timer.periodic(const Duration(milliseconds: 45), (timer) {
      if (!mounted) {
        return;
      }
      if (visibleCharacters >= widget.text.characters.length) {
        setState(() => showCursor = !showCursor);
        return;
      }
      setState(() => visibleCharacters += 1);
    });
  }

  @override
  void dispose() {
    timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final text = widget.text.characters.take(visibleCharacters).toString();

    return AnimatedSize(
      duration: const Duration(milliseconds: 120),
      alignment: AlignmentDirectional.centerStart,
      child: Text(
        '$text${showCursor ? '|' : ''}',
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
          color: Colors.white.withValues(alpha: 0.92),
          fontSize: 14,
          height: 1.4,
          fontWeight: FontWeight.w800,
          letterSpacing: 0,
        ),
      ),
    );
  }
}

class _SubjectChoiceTile extends StatelessWidget {
  const _SubjectChoiceTile({
    required this.subject,
    required this.selected,
    required this.accent,
    required this.onChanged,
    this.teacherName,
    this.price,
  });

  final String subject;
  final String? teacherName;
  final String? price;
  final bool selected;
  final Color accent;
  final ValueChanged<bool?> onChanged;

  @override
  Widget build(BuildContext context) {
    final teacher = teacherName?.trim();
    final subjectPrice = price?.trim();

    return InkWell(
      onTap: () => onChanged(!selected),
      borderRadius: BorderRadius.circular(16),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        curve: Curves.easeOut,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: selected ? accent.withValues(alpha: 0.09) : Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: selected ? accent : const Color(0xFFE1E8F8),
            width: selected ? 1.6 : 1,
          ),
        ),
        child: Row(
          children: [
            Checkbox(
              value: selected,
              activeColor: accent,
              onChanged: onChanged,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(5),
              ),
            ),
            const SizedBox(width: 6),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    subject,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: epsilonInk,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    teacher == null || teacher.isEmpty
                        ? 'لم يتم تعيين أستاذ بعد'
                        : 'الأستاذ: $teacher',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: teacher == null || teacher.isEmpty
                          ? epsilonMuted
                          : accent,
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ],
              ),
            ),
            if (subjectPrice != null && subjectPrice.isNotEmpty) ...[
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
                decoration: BoxDecoration(
                  color: accent.withValues(alpha: 0.10),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  subjectPrice,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: accent,
                    fontSize: 12,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
            ],
            AnimatedScale(
              duration: const Duration(milliseconds: 180),
              scale: selected ? 1 : 0.85,
              child: Icon(
                selected ? Icons.check_circle_rounded : Icons.circle_outlined,
                color: selected ? accent : const Color(0xFFCBD5E1),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class StudentPaymentPage extends StatefulWidget {
  const StudentPaymentPage({
    required this.name,
    required this.phone,
    required this.password,
    required this.courseId,
    required this.selectedSubjects,
    required this.subscriptionLabel,
    required this.paymentAmount,
    super.key,
  });

  final String name;
  final String phone;
  final String password;
  final String courseId;
  final List<String> selectedSubjects;
  final String subscriptionLabel;
  final String paymentAmount;

  @override
  State<StudentPaymentPage> createState() => _StudentPaymentPageState();
}

class _StudentPaymentPageState extends State<StudentPaymentPage>
    with SingleTickerProviderStateMixin {
  final paymentSenderPhoneController = TextEditingController();
  late final AnimationController attentionController;
  late final Animation<double> pulseAnimation;
  PickedNativeFile? proofImage;
  String? selectedPaymentMethodId;
  bool submitted = false;
  String? error;

  @override
  void initState() {
    super.initState();
    attentionController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1100),
    )..repeat(reverse: true);
    pulseAnimation = Tween<double>(begin: 0.96, end: 1.04).animate(
      CurvedAnimation(parent: attentionController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    paymentSenderPhoneController.dispose();
    attentionController.dispose();
    super.dispose();
  }

  Future<void> pickProofImage() async {
    final image = await NativeFilePicker.pickImage();
    if (image == null) {
      return;
    }

    setState(() {
      proofImage = image;
      error = null;
    });
  }

  Future<void> submitRequest() async {
    final image = proofImage;
    if (image == null) {
      setState(() => error = 'يرجى إرسال صورة إثبات الدفع أولا.');
      return;
    }
    if (paymentSenderPhoneController.text.trim().isEmpty) {
      setState(() => error = 'اكتب الرقم الذي تم إرسال المبلغ منه.');
      return;
    }

    final store = StoreScope.of(context);
    final paymentAmount = widget.paymentAmount.trim().isNotEmpty
        ? widget.paymentAmount.trim()
        : store.paymentAmount;

    try {
      final proofDataUri = await paymentProofDataUri(image.path, image.name);
      await store.registerStudent(
        name: widget.name,
        phone: widget.phone,
        password: widget.password,
        courseId: widget.courseId,
        paymentProofPath: proofDataUri,
        selectedSubjects: widget.selectedSubjects,
        paymentSenderPhone: paymentSenderPhoneController.text,
        paymentAmount: paymentAmount,
      );
      if (!mounted) {
        return;
      }
      setState(() {
        submitted = true;
        error = null;
      });
      await showPendingAccountMessage();
    } on Object catch (exception) {
      if (!mounted) {
        return;
      }
      setState(() => error = 'تعذر إرسال الطلب: $exception');
    }
  }

  Future<void> showPendingAccountMessage() async {
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (_) => const AlertDialog(
        icon: Icon(Icons.hourglass_top_rounded, color: epsilonBlue, size: 42),
        title: Text('تم إنشاء الحساب'),
        content: Text(
          'حسابك الآن بانتظار الإدارة. قد يستغرق الأمر بضع دقائق، لا تقلق. تواصل مع المرشد 34605765.',
          textAlign: TextAlign.center,
        ),
      ),
    );
    await Future<void>.delayed(const Duration(milliseconds: 3200));
    if (!mounted) {
      return;
    }
    Navigator.of(context, rootNavigator: true).pop();
    Navigator.of(context).popUntil((route) => route.isFirst);
  }

  @override
  Widget build(BuildContext context) {
    final store = StoreScope.of(context);
    final course = store.courseById(widget.courseId);
    final availablePaymentMethods = store.paymentMethods.isEmpty
        ? [
            PaymentMethod(
              id: 'default',
              name: 'طريقة الدفع المتاحة',
              accountNumber: store.paymentNumber,
            ),
          ]
        : store.paymentMethods;
    if (selectedPaymentMethodId == null && availablePaymentMethods.isNotEmpty) {
      selectedPaymentMethodId = availablePaymentMethods.first.id;
    }
    final selectedPaymentMethod = availablePaymentMethods.firstWhere(
      (method) => method.id == selectedPaymentMethodId,
      orElse: () => availablePaymentMethods.first,
    );

    return Scaffold(
      backgroundColor: const Color(0xFFF7F9FF),
      appBar: const EpsilonAppBar(title: 'الدفع', showLogout: false),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
        children: [
          AdminPageHeader(
            title: 'إثبات الدفع',
            subtitle: 'ادفع عبر الرقم التالي ثم أرسل صورة الإثبات',
            icon: Icons.receipt_long_rounded,
            color: const Color(0xFF2F5BEA),
          ),
          const SizedBox(height: 16),
          PaymentAttentionCard(
            paymentMethod: selectedPaymentMethod,
            pulseAnimation: pulseAnimation,
          ),
          const SizedBox(height: 16),
          SectionCard(
            title: 'طرق الدفع المتوفرة',
            icon: Icons.account_balance_wallet_rounded,
            child: Column(
              children: [
                for (final method in availablePaymentMethods) ...[
                  PaymentMethodTile(
                    method: method,
                    selected: method.id == selectedPaymentMethod.id,
                    onTap: submitted
                        ? null
                        : () {
                            setState(() {
                              selectedPaymentMethodId = method.id;
                            });
                          },
                  ),
                  const SizedBox(height: 10),
                ],
              ],
            ),
          ),
          const SizedBox(height: 16),
          SectionCard(
            title: 'بيانات الطلب',
            icon: Icons.person_outline_rounded,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                InfoRow(label: 'الاسم', value: widget.name),
                InfoRow(label: 'رقم الهاتف', value: widget.phone),
                InfoRow(label: 'القسم', value: course?.title ?? 'غير محدد'),
                InfoRow(label: 'نوع الاشتراك', value: widget.subscriptionLabel),
                InfoRow(
                  label: 'المواد',
                  value: widget.selectedSubjects.join('، '),
                ),
                TextField(
                  controller: paymentSenderPhoneController,
                  enabled: !submitted,
                  keyboardType: TextInputType.phone,
                  decoration: const InputDecoration(
                    labelText: 'الرقم الذي أرسلت منه المبلغ',
                    hintText: 'مثال: 49677414',
                    prefixIcon: Icon(Icons.phone_iphone_rounded),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          SectionCard(
            title: 'صورة إثبات الدفع',
            icon: Icons.image_outlined,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                PaymentProofPreview(imagePath: proofImage?.path),
                const SizedBox(height: 12),
                OutlinedButton.icon(
                  onPressed: submitted ? null : pickProofImage,
                  icon: const Icon(Icons.upload_file_rounded),
                  label: Text(
                    proofImage == null
                        ? 'اختيار صورة إثبات الدفع'
                        : 'تغيير الصورة',
                  ),
                ),
                if (error != null) ...[
                  const SizedBox(height: 10),
                  Text(error!, style: TextStyle(color: Colors.red.shade700)),
                ],
                const SizedBox(height: 12),
                FilledButton.icon(
                  onPressed: submitted ? null : submitRequest,
                  icon: const Icon(Icons.send_rounded),
                  label: const Text('إرسال الطلب للإدارة'),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class PaymentAttentionCard extends StatelessWidget {
  const PaymentAttentionCard({
    required this.paymentMethod,
    required this.pulseAnimation,
    super.key,
  });

  final PaymentMethod paymentMethod;
  final Animation<double> pulseAnimation;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: const Color(0xFF2F5BEA),
        borderRadius: BorderRadius.circular(22),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF2F5BEA).withValues(alpha: 0.24),
            blurRadius: 26,
            offset: const Offset(0, 14),
          ),
        ],
      ),
      child: Row(
        children: [
          ScaleTransition(
            scale: pulseAnimation,
            child: Container(
              width: 62,
              height: 62,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.18),
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: Colors.white24),
              ),
              clipBehavior: Clip.antiAlias,
              child: paymentMethod.imageUrl.trim().isEmpty
                  ? const Icon(
                      Icons.payments_rounded,
                      color: Colors.white,
                      size: 34,
                    )
                  : Image.network(
                      paymentMethod.imageUrl,
                      fit: BoxFit.cover,
                      errorBuilder: (_, _, _) => const Icon(
                        Icons.payments_rounded,
                        color: Colors.white,
                        size: 34,
                      ),
                    ),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  paymentMethod.name.trim().isEmpty
                      ? 'رقم الدفع'
                      : paymentMethod.name,
                  style: const TextStyle(
                    color: Color(0xFFE8EEFF),
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 8),
                SelectableText(
                  paymentMethod.accountNumber.isEmpty
                      ? 'لم تضفه الإدارة بعد'
                      : paymentMethod.accountNumber,
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.94),
                    fontSize: 26,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 0,
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  'انسخ الرقم، ادفع عليه، ثم ارفع صورة الإيصال.',
                  style: TextStyle(color: Color(0xFFE8EEFF), height: 1.35),
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          IconButton.filled(
            tooltip: 'نسخ الرقم',
            onPressed: paymentMethod.accountNumber.trim().isEmpty
                ? null
                : () {
                    Clipboard.setData(
                      ClipboardData(text: paymentMethod.accountNumber.trim()),
                    );
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('تم نسخ رقم الدفع')),
                    );
                  },
            icon: const Icon(Icons.copy_rounded),
          ),
        ],
      ),
    );
  }
}

class PaymentMethodTile extends StatelessWidget {
  const PaymentMethodTile({
    required this.method,
    required this.selected,
    required this.onTap,
    super.key,
  });

  final PaymentMethod method;
  final bool selected;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: selected
              ? const Color(0xFF2F5BEA).withValues(alpha: 0.08)
              : Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: selected ? const Color(0xFF2F5BEA) : const Color(0xFFE1E8F8),
            width: selected ? 1.6 : 1,
          ),
        ),
        child: Row(
          children: [
            PaymentMethodLogo(method: method, size: 48),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    method.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: epsilonInk,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 4),
                  SelectableText(
                    method.accountNumber.isEmpty
                        ? 'لم تضفه الإدارة بعد'
                        : method.accountNumber,
                    style: const TextStyle(
                      color: epsilonMuted,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ],
              ),
            ),
            Icon(
              selected ? Icons.check_circle_rounded : Icons.circle_outlined,
              color: selected
                  ? const Color(0xFF2F5BEA)
                  : const Color(0xFFCBD5E1),
            ),
          ],
        ),
      ),
    );
  }
}

class PaymentMethodLogo extends StatelessWidget {
  const PaymentMethodLogo({required this.method, this.size = 42, super.key});

  final PaymentMethod method;
  final double size;

  @override
  Widget build(BuildContext context) {
    final imageUrl = method.imageUrl.trim();

    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: const Color(0xFFEAF1FF),
        borderRadius: BorderRadius.circular(14),
      ),
      clipBehavior: Clip.antiAlias,
      child: imageUrl.isEmpty
          ? const Icon(
              Icons.account_balance_wallet_rounded,
              color: Color(0xFF2F5BEA),
            )
          : Image.network(
              imageUrl,
              fit: BoxFit.cover,
              errorBuilder: (_, _, _) => const Icon(
                Icons.account_balance_wallet_rounded,
                color: Color(0xFF2F5BEA),
              ),
            ),
    );
  }
}

class InfoRow extends StatelessWidget {
  const InfoRow({required this.label, required this.value, super.key});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        children: [
          Text(
            '$label:',
            style: const TextStyle(
              color: Color(0xFF6B7280),
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(fontWeight: FontWeight.w800),
            ),
          ),
        ],
      ),
    );
  }
}

Future<String> paymentProofDataUri(String path, String fileName) async {
  final bytes = await File(path).readAsBytes();
  final extension = fileName.split('.').last.toLowerCase();
  final mimeType = switch (extension) {
    'png' => 'image/png',
    'webp' => 'image/webp',
    _ => 'image/jpeg',
  };
  return 'data:$mimeType;base64,${base64Encode(bytes)}';
}

Uint8List? imageBytesFromDataUri(String value) {
  final marker = RegExp(r'^data:image/[^;]+;base64,');
  if (!marker.hasMatch(value)) {
    return null;
  }
  try {
    return base64Decode(value.replaceFirst(marker, ''));
  } on Object {
    return null;
  }
}

class PaymentProofPreview extends StatelessWidget {
  const PaymentProofPreview({
    required this.imagePath,
    this.emptyText = 'لم يتم اختيار صورة بعد',
    this.height = 190,
    super.key,
  });

  final String? imagePath;
  final String emptyText;
  final double height;

  @override
  Widget build(BuildContext context) {
    final path = imagePath;
    final image = path == null ? null : _PaymentProofImage(path: path);

    return InkWell(
      borderRadius: BorderRadius.circular(14),
      onTap: image == null
          ? null
          : () => Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => PaymentProofDetailsPage(imagePath: path!),
              ),
            ),
      child: Container(
        constraints: BoxConstraints(
          minHeight: 130,
          maxHeight: height,
          maxWidth: MediaQuery.sizeOf(context).width - 32,
        ),
        decoration: BoxDecoration(
          color: const Color(0xFFF3F6FF),
          border: Border.all(color: const Color(0xFFD8E2FF)),
          borderRadius: BorderRadius.circular(14),
        ),
        clipBehavior: Clip.antiAlias,
        child: SizedBox(
          height: height,
          width: double.infinity,
          child:
              image ??
              Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(
                    Icons.add_photo_alternate_rounded,
                    size: 42,
                    color: Color(0xFF2F5BEA),
                  ),
                  const SizedBox(height: 8),
                  Text(emptyText),
                ],
              ),
        ),
      ),
    );
  }
}

class _PaymentProofImage extends StatelessWidget {
  const _PaymentProofImage({required this.path});

  final String path;

  @override
  Widget build(BuildContext context) {
    final dataUriBytes = imageBytesFromDataUri(path);
    final image = dataUriBytes != null
        ? Image.memory(
            dataUriBytes,
            fit: BoxFit.contain,
            width: double.infinity,
            height: double.infinity,
            errorBuilder: (_, _, _) => const PaymentProofLoadError(),
          )
        : path.startsWith('http')
        ? Image.network(
            path,
            fit: BoxFit.contain,
            width: double.infinity,
            height: double.infinity,
            errorBuilder: (_, _, _) => const PaymentProofLoadError(),
          )
        : Image.file(
            File(path),
            fit: BoxFit.contain,
            width: double.infinity,
            height: double.infinity,
            errorBuilder: (_, _, _) => const PaymentProofLoadError(),
          );

    return ColoredBox(
      color: const Color(0xFFF8FAFF),
      child: Padding(
        padding: const EdgeInsets.all(8),
        child: Center(child: image),
      ),
    );
  }
}

class PaymentProofLoadError extends StatelessWidget {
  const PaymentProofLoadError({super.key});

  @override
  Widget build(BuildContext context) {
    return const Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(Icons.broken_image_outlined, size: 38, color: Color(0xFF64748B)),
        SizedBox(height: 8),
        Text(
          'تعذر عرض الصورة',
          style: TextStyle(color: epsilonMuted, fontWeight: FontWeight.w800),
        ),
      ],
    );
  }
}

class PaymentProofDetailsImage extends StatelessWidget {
  const PaymentProofDetailsImage({required this.imagePath, super.key});

  final String imagePath;

  @override
  Widget build(BuildContext context) {
    final dataUriBytes = imageBytesFromDataUri(imagePath);
    if (dataUriBytes != null) {
      return Image.memory(
        dataUriBytes,
        fit: BoxFit.contain,
        width: double.infinity,
        height: double.infinity,
        errorBuilder: (_, _, _) => const PaymentProofLoadError(),
      );
    }

    if (imagePath.startsWith('http')) {
      return Image.network(
        imagePath,
        fit: BoxFit.contain,
        width: double.infinity,
        height: double.infinity,
        errorBuilder: (_, _, _) => const PaymentProofLoadError(),
      );
    }

    return Image.file(
      File(imagePath),
      fit: BoxFit.contain,
      width: double.infinity,
      height: double.infinity,
      errorBuilder: (_, _, _) => const PaymentProofLoadError(),
    );
  }
}

class PaymentProofDetailsPage extends StatelessWidget {
  const PaymentProofDetailsPage({required this.imagePath, super.key});

  final String imagePath;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        title: const Text('إثبات الدفع'),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(8),
          child: InteractiveViewer(
            minScale: 0.6,
            maxScale: 5,
            child: SizedBox.expand(
              child: PaymentProofDetailsImage(imagePath: imagePath),
            ),
          ),
        ),
      ),
    );
  }
}

class BackendSetupBanner extends StatelessWidget {
  const BackendSetupBanner({required this.message, super.key});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFFFFBEB),
        border: Border.all(color: const Color(0xFFFACC15)),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.info_outline_rounded, color: Color(0xFFA16207)),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              message,
              style: const TextStyle(color: Color(0xFF713F12)),
            ),
          ),
        ],
      ),
    );
  }
}

class StatusScreen extends StatelessWidget {
  const StatusScreen({
    required this.title,
    required this.message,
    required this.icon,
    required this.color,
    super.key,
  });

  final String title;
  final String message;
  final IconData icon;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: EpsilonAppBar(title: title),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 72, color: color),
              const SizedBox(height: 16),
              Text(
                title,
                style: Theme.of(context).textTheme.headlineSmall,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(message, textAlign: TextAlign.center),
            ],
          ),
        ),
      ),
    );
  }
}

class AdminDashboard extends StatelessWidget {
  const AdminDashboard({super.key});

  @override
  Widget build(BuildContext context) {
    final store = StoreScope.of(context);
    final admin = store.currentUser;
    final actions = [
      AdminQuickActionData(
        title: 'الحسابات',
        metric: '${store.visibleStudents.length}',
        icon: Icons.manage_accounts_rounded,
        color: const Color(0xFFB63B65),
        onTap: () => Navigator.of(
          context,
        ).push(MaterialPageRoute(builder: (_) => const AdminAccountsPage())),
      ),
      AdminQuickActionData(
        title: 'طلبات الدفع',
        metric: '${store.visiblePendingStudents.length}',
        icon: Icons.fact_check_rounded,
        color: const Color(0xFFF59E0B),
        onTap: () => Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => const AdminPaymentRequestsPage()),
        ),
      ),
      AdminQuickActionData(
        title: 'كشف الطلاب',
        metric: '${store.visibleStudents.length}',
        icon: Icons.table_chart_rounded,
        color: const Color(0xFF3F8069),
        onTap: () => Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => const AdminStudentsReportPage()),
        ),
      ),
      AdminQuickActionData(
        title: 'المصاريف',
        metric: '0',
        icon: Icons.receipt_long_rounded,
        color: const Color(0xFFF2A51A),
        onTap: () => Navigator.of(
          context,
        ).push(MaterialPageRoute(builder: (_) => const AdminExpensesPage())),
      ),
      AdminQuickActionData(
        title: 'طرق الدفع',
        metric: '${store.paymentMethods.length}',
        icon: Icons.account_balance_wallet_rounded,
        color: const Color(0xFF2457E6),
        onTap: () => Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => const AdminPaymentSettingsPage()),
        ),
      ),
      AdminQuickActionData(
        title: 'الأساتذة',
        metric: '${store.teachers.length}',
        icon: Icons.co_present_rounded,
        color: const Color(0xFF1F2A44),
        onTap: () => Navigator.of(
          context,
        ).push(MaterialPageRoute(builder: (_) => const AdminTeachersPage())),
      ),
      AdminQuickActionData(
        title: 'الأقسام',
        metric: '${store.courses.length}',
        icon: Icons.menu_book_rounded,
        color: const Color(0xFFD9472F),
        onTap: () => Navigator.of(
          context,
        ).push(MaterialPageRoute(builder: (_) => const AdminCoursesPage())),
      ),
      AdminQuickActionData(
        title: 'رفع درس',
        metric: '${store.lessons.length}',
        icon: Icons.cloud_upload_rounded,
        color: const Color(0xFF6D38C9),
        onTap: () => Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => const AdminUploadLessonPage()),
        ),
      ),
      AdminQuickActionData(
        title: 'إضافة أستاذ',
        metric: 'جديد',
        icon: Icons.person_add_alt_1_rounded,
        color: const Color(0xFF0E8B8D),
        onTap: () => Navigator.of(
          context,
        ).push(MaterialPageRoute(builder: (_) => const AdminAddTeacherPage())),
      ),
      if (store.currentAdminIsDeveloper)
        AdminQuickActionData(
          title: 'صلاحيات الإدارة',
          metric: '${store.admins.length}',
          icon: Icons.admin_panel_settings_rounded,
          color: const Color(0xFF334155),
          onTap: () => Navigator.of(
            context,
          ).push(MaterialPageRoute(builder: (_) => const AdminAccessPage())),
        ),
    ];

    return Scaffold(
      backgroundColor: const Color(0xFFF2F8F6),
      appBar: const EpsilonAppBar(title: 'لوحة الإدارة'),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(18, 14, 18, 28),
        children: [
          AdminFinanceCard(
            adminName: admin?.name ?? 'الإدارة',
            totalAmount: '${formatBoxAmount(store.visibleBoxAmount)} أوقية',
            pendingCount: store.visiblePendingStudents.length,
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const AdminIncomeDetailsPage()),
            ),
          ),
          const SizedBox(height: 22),
          Row(
            children: [
              Text(
                'الإدارة السريعة',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  color: epsilonInk,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 11,
                  vertical: 7,
                ),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(999),
                  border: Border.all(color: const Color(0xFFDDEBE8)),
                ),
                child: Text(
                  '${actions.length} أزرار',
                  style: const TextStyle(
                    color: Color(0xFF475569),
                    fontWeight: FontWeight.w800,
                    fontSize: 12,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          LayoutBuilder(
            builder: (context, constraints) {
              final columns = constraints.maxWidth > 560 ? 4 : 3;
              final spacing = constraints.maxWidth > 560 ? 14.0 : 12.0;
              final width =
                  (constraints.maxWidth - spacing * (columns - 1)) / columns;

              return Wrap(
                spacing: spacing,
                runSpacing: 18,
                children: actions
                    .map(
                      (action) => SizedBox(
                        width: width,
                        child: AdminQuickActionButton(action: action),
                      ),
                    )
                    .toList(),
              );
            },
          ),
        ],
      ),
    );
  }
}

class AdminQuickActionData {
  const AdminQuickActionData({
    required this.title,
    required this.metric,
    required this.icon,
    required this.color,
    required this.onTap,
  });

  final String title;
  final String metric;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;
}

class AdminFinanceCard extends StatelessWidget {
  const AdminFinanceCard({
    required this.adminName,
    required this.totalAmount,
    required this.pendingCount,
    required this.onTap,
    super.key,
  });

  final String adminName;
  final String totalAmount;
  final int pendingCount;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(26),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(26),
        child: Ink(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              begin: AlignmentDirectional.topStart,
              end: AlignmentDirectional.bottomEnd,
              colors: [Color(0xFF2457E6), Color(0xFF1D75D8), Color(0xFF0F9F7A)],
            ),
            borderRadius: BorderRadius.circular(26),
            boxShadow: [
              BoxShadow(
                color: epsilonBlue.withValues(alpha: 0.20),
                blurRadius: 28,
                offset: const Offset(0, 16),
              ),
            ],
          ),
          child: Stack(
            children: [
              PositionedDirectional(
                top: -54,
                start: 64,
                child: Icon(
                  Icons.account_balance_wallet_rounded,
                  size: 178,
                  color: Colors.white.withValues(alpha: 0.055),
                ),
              ),
              PositionedDirectional(
                bottom: -34,
                end: -26,
                child: Container(
                  width: 126,
                  height: 126,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: epsilonGold.withValues(alpha: 0.18),
                  ),
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(13),
                        child: Image.asset(
                          'assets/onboarding/epsilon_logo.jpeg',
                          width: 46,
                          height: 46,
                          fit: BoxFit.cover,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'أهلا بكم',
                              style: TextStyle(
                                color: Color(0xFFEAF4FF),
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            Text(
                              adminName,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 20,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.16),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.chevron_left_rounded,
                          color: Colors.white,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 26),
                  Container(
                    padding: const EdgeInsets.all(18),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.18),
                      borderRadius: BorderRadius.circular(22),
                      border: Border.all(color: Colors.white30),
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 48,
                          height: 48,
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.18),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.visibility_off_rounded,
                            color: Colors.white,
                          ),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'إجمالي الموجود في الصندوق',
                                style: TextStyle(
                                  color: Color(0xFFEAF4FF),
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                totalAmount,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 26,
                                  fontWeight: FontWeight.w900,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 11,
                            vertical: 8,
                          ),
                          decoration: BoxDecoration(
                            color: epsilonGold,
                            borderRadius: BorderRadius.circular(999),
                          ),
                          child: Text(
                            '$pendingCount طلب',
                            style: const TextStyle(
                              color: Color(0xFF1F2937),
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class AdminIncomeDetailsPage extends StatelessWidget {
  const AdminIncomeDetailsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final store = StoreScope.of(context);
    final summaries = store.visibleCourseIncomeSummaries;

    return Scaffold(
      backgroundColor: const Color(0xFFF7F9FF),
      appBar: const EpsilonAppBar(title: 'تفاصيل المداخيل'),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
        children: [
          AdminPageHeader(
            title: 'دخل الأقسام',
            subtitle: 'تفصيل المبالغ حسب القسم أو الدورة المرتبطة بحسابك',
            icon: Icons.account_balance_wallet_rounded,
            color: const Color(0xFF0F9F7A),
          ),
          const SizedBox(height: 16),
          SectionCard(
            title: 'الإجمالي',
            icon: Icons.payments_rounded,
            child: InfoRow(
              label: 'المبلغ الظاهر',
              value: '${formatBoxAmount(store.visibleBoxAmount)} أوقية',
            ),
          ),
          const SizedBox(height: 16),
          SectionCard(
            title: 'حسب القسم',
            icon: Icons.menu_book_rounded,
            child: summaries.isEmpty
                ? const EmptyState(text: 'لا توجد مداخيل مرتبطة بالأقسام بعد.')
                : Column(
                    children: [
                      for (final summary in summaries) ...[
                        CourseIncomeTile(summary: summary),
                        const SizedBox(height: 10),
                      ],
                    ],
                  ),
          ),
        ],
      ),
    );
  }
}

class CourseIncomeTile extends StatelessWidget {
  const CourseIncomeTile({required this.summary, super.key});

  final CourseIncomeSummary summary;

  @override
  Widget build(BuildContext context) {
    final store = StoreScope.of(context);
    final accent = courseAccent(summary.course.title);
    final income = store.courseIncomeAmount(summary.course.id);
    final expenses = store.courseExpenseAmount(summary.course.id);
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFFAFBFF),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: accent.withValues(alpha: 0.18)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Icon(courseIcon(summary.course.title), color: accent),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  summary.course.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: epsilonInk,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
              Text(
                '${formatBoxAmount(summary.total)} أوقية',
                style: TextStyle(color: accent, fontWeight: FontWeight.w900),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: InfoRow(
                  label: 'الدخل',
                  value: '${formatBoxAmount(income)} أوقية',
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: InfoRow(
                  label: 'المصاريف',
                  value: '${formatBoxAmount(expenses)} أوقية',
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            'الصافي - ${summary.payments.length} عملية دفع',
            style: const TextStyle(
              color: epsilonMuted,
              fontSize: 12,
              fontWeight: FontWeight.w700,
            ),
          ),
          if (summary.payments.isNotEmpty) ...[
            const SizedBox(height: 10),
            for (final payment in summary.payments.take(5))
              Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        '${payment.studentName} - ${payment.type}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontWeight: FontWeight.w700),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      payment.amount,
                      style: const TextStyle(fontWeight: FontWeight.w900),
                    ),
                  ],
                ),
              ),
          ],
        ],
      ),
    );
  }
}

class AdminAccessPage extends StatelessWidget {
  const AdminAccessPage({super.key});

  @override
  Widget build(BuildContext context) {
    final store = StoreScope.of(context);

    return Scaffold(
      backgroundColor: const Color(0xFFF7F9FF),
      appBar: const EpsilonAppBar(title: 'صلاحيات الإدارة'),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
        children: [
          AdminPageHeader(
            title: 'أنواع الأدمن',
            subtitle: 'الدفلوبر يحدد نوع كل أدمن والأقسام المالية الظاهرة له',
            icon: Icons.admin_panel_settings_rounded,
            color: const Color(0xFF334155),
          ),
          const SizedBox(height: 16),
          const CreateAdminForm(),
          const SizedBox(height: 16),
          SectionCard(
            title: 'حسابات الإدارة',
            icon: Icons.manage_accounts_rounded,
            child: store.admins.isEmpty
                ? const EmptyState(text: 'لا توجد حسابات إدارة.')
                : Column(
                    children: [
                      for (final admin in store.admins) ...[
                        AdminAccessTile(admin: admin),
                        const SizedBox(height: 12),
                      ],
                    ],
                  ),
          ),
        ],
      ),
    );
  }
}

class CreateAdminForm extends StatefulWidget {
  const CreateAdminForm({super.key});

  @override
  State<CreateAdminForm> createState() => _CreateAdminFormState();
}

class _CreateAdminFormState extends State<CreateAdminForm> {
  final nameController = TextEditingController();
  final phoneController = TextEditingController();
  final passwordController = TextEditingController(text: '123456');
  AdminType adminType = AdminType.schoolManager;
  final Set<String> selectedCourseIds = {};
  String? message;
  bool isSaving = false;

  @override
  void dispose() {
    nameController.dispose();
    phoneController.dispose();
    passwordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final store = StoreScope.of(context);
    return SectionCard(
      title: 'إنشاء حساب أدمن',
      icon: Icons.person_add_alt_1_rounded,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TextField(
            controller: nameController,
            decoration: const InputDecoration(labelText: 'اسم الأدمن'),
          ),
          const SizedBox(height: 10),
          TextField(
            controller: phoneController,
            keyboardType: TextInputType.phone,
            decoration: const InputDecoration(
              labelText: 'رقم الهاتف',
              prefixIcon: Icon(Icons.phone_iphone_rounded),
            ),
          ),
          const SizedBox(height: 10),
          TextField(
            controller: passwordController,
            decoration: const InputDecoration(labelText: 'كلمة المرور'),
          ),
          const SizedBox(height: 10),
          DropdownButtonFormField<AdminType>(
            initialValue: adminType,
            decoration: const InputDecoration(labelText: 'نوع الأدمن'),
            items: AdminType.values
                .where((type) => type != AdminType.developer)
                .map(
                  (type) => DropdownMenuItem(
                    value: type,
                    child: Text(adminTypeLabel(type)),
                  ),
                )
                .toList(),
            onChanged: (value) {
              if (value != null) {
                setState(() => adminType = value);
              }
            },
          ),
          const SizedBox(height: 10),
          store.courses.isEmpty
              ? const EmptyState(text: 'أنشئ أقساما قبل إنشاء أدمن محدود.')
              : Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: store.courses.map((course) {
                    final selected = selectedCourseIds.contains(course.id);
                    return FilterChip(
                      selected: selected,
                      label: Text(course.title),
                      avatar: Icon(courseIcon(course.title), size: 18),
                      onSelected: (value) {
                        setState(() {
                          if (value) {
                            selectedCourseIds.add(course.id);
                          } else {
                            selectedCourseIds.remove(course.id);
                          }
                        });
                      },
                    );
                  }).toList(),
                ),
          if (message != null) ...[
            const SizedBox(height: 10),
            Text(
              message!,
              style: TextStyle(
                color: message!.startsWith('تم')
                    ? Colors.green.shade700
                    : Colors.red.shade700,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
          const SizedBox(height: 12),
          Align(
            alignment: Alignment.centerLeft,
            child: FilledButton.icon(
              onPressed: isSaving
                  ? null
                  : () async {
                      if (nameController.text.trim().isEmpty ||
                          phoneController.text.trim().isEmpty ||
                          passwordController.text.length < 6) {
                        setState(
                          () => message =
                              'أكمل البيانات وتأكد أن كلمة المرور 6 أحرف على الأقل.',
                        );
                        return;
                      }
                      if (selectedCourseIds.isEmpty) {
                        setState(() => message = 'اختر قسما واحدا على الأقل.');
                        return;
                      }
                      setState(() {
                        isSaving = true;
                        message = null;
                      });
                      try {
                        await store.createAdmin(
                          name: nameController.text,
                          phone: phoneController.text,
                          password: passwordController.text,
                          adminType: adminType,
                          managedCourseIds: selectedCourseIds.toList(),
                        );
                        if (!mounted) {
                          return;
                        }
                        if (store.lastError != null) {
                          setState(() => message = store.lastError);
                          return;
                        }
                        nameController.clear();
                        phoneController.clear();
                        selectedCourseIds.clear();
                        setState(() => message = 'تم إنشاء حساب الأدمن.');
                      } on Object catch (error) {
                        if (!mounted) {
                          return;
                        }
                        setState(
                          () => message =
                              'فشل إنشاء الأدمن: ${friendlyApiError(error)}',
                        );
                      } finally {
                        if (mounted) {
                          setState(() => isSaving = false);
                        }
                      }
                    },
              icon: const Icon(Icons.add_rounded),
              label: Text(isSaving ? 'جار الإنشاء...' : 'إنشاء الأدمن'),
            ),
          ),
        ],
      ),
    );
  }
}

class AdminAccessTile extends StatefulWidget {
  const AdminAccessTile({required this.admin, super.key});

  final AppUser admin;

  @override
  State<AdminAccessTile> createState() => _AdminAccessTileState();
}

class _AdminAccessTileState extends State<AdminAccessTile> {
  late AdminType adminType = widget.admin.adminType;
  late final Set<String> selectedCourseIds = {
    ...widget.admin.managedCourseIds,
    if (widget.admin.courseId != null) widget.admin.courseId!,
  };
  bool isSaving = false;

  @override
  Widget build(BuildContext context) {
    final store = StoreScope.of(context);
    final isSelf = store.currentUser?.id == widget.admin.id;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE3E9FF)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          UserTile(user: widget.admin, compact: true),
          const SizedBox(height: 10),
          DropdownButtonFormField<AdminType>(
            initialValue: adminType,
            decoration: const InputDecoration(labelText: 'نوع الأدمن'),
            items: AdminType.values
                .map(
                  (type) => DropdownMenuItem(
                    value: type,
                    child: Text(adminTypeLabel(type)),
                  ),
                )
                .toList(),
            onChanged: isSelf
                ? null
                : (value) {
                    if (value != null) {
                      setState(() => adminType = value);
                    }
                  },
          ),
          const SizedBox(height: 10),
          if (adminType == AdminType.developer)
            const EmptyState(text: 'الدفلوبر يرى كل المداخيل تلقائيا.')
          else if (store.courses.isEmpty)
            const EmptyState(text: 'لا توجد أقسام للربط.')
          else
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: store.courses.map((course) {
                final selected = selectedCourseIds.contains(course.id);
                return FilterChip(
                  selected: selected,
                  label: Text(course.title),
                  avatar: Icon(courseIcon(course.title), size: 18),
                  onSelected: (value) {
                    setState(() {
                      if (value) {
                        selectedCourseIds.add(course.id);
                      } else {
                        selectedCourseIds.remove(course.id);
                      }
                    });
                  },
                );
              }).toList(),
            ),
          const SizedBox(height: 12),
          Align(
            alignment: Alignment.centerLeft,
            child: FilledButton.icon(
              onPressed: isSelf || isSaving
                  ? null
                  : () async {
                      setState(() => isSaving = true);
                      await store.updateAdminAccess(
                        admin: widget.admin,
                        adminType: adminType,
                        managedCourseIds: selectedCourseIds.toList(),
                      );
                      if (!context.mounted) {
                        return;
                      }
                      setState(() => isSaving = false);
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('تم حفظ الصلاحيات')),
                      );
                    },
              icon: const Icon(Icons.save_rounded),
              label: Text(isSaving ? 'جار الحفظ...' : 'حفظ الصلاحيات'),
            ),
          ),
        ],
      ),
    );
  }
}

class AdminQuickActionButton extends StatelessWidget {
  const AdminQuickActionButton({required this.action, super.key});

  final AdminQuickActionData action;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: action.onTap,
        borderRadius: BorderRadius.circular(22),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: Column(
            children: [
              Container(
                width: 74,
                height: 74,
                decoration: BoxDecoration(
                  color: action.color,
                  borderRadius: BorderRadius.circular(24),
                  boxShadow: [
                    BoxShadow(
                      color: action.color.withValues(alpha: 0.25),
                      blurRadius: 16,
                      offset: const Offset(0, 9),
                    ),
                  ],
                ),
                child: Icon(action.icon, color: Colors.white, size: 34),
              ),
              const SizedBox(height: 9),
              Text(
                action.title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: Color(0xFF2D3748),
                  fontSize: 15,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 3),
              Text(
                action.metric,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: action.color,
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class AdminExpensesPage extends StatefulWidget {
  const AdminExpensesPage({super.key});

  @override
  State<AdminExpensesPage> createState() => _AdminExpensesPageState();
}

class _AdminExpensesPageState extends State<AdminExpensesPage> {
  final titleController = TextEditingController();
  final amountController = TextEditingController();
  final noteController = TextEditingController();
  String category = 'رواتب';
  String? courseId;
  String? error;

  static const categories = [
    'رواتب',
    'إيجار',
    'إنترنت',
    'إعلانات',
    'معدات',
    'صيانة',
    'أخرى',
  ];

  @override
  void dispose() {
    titleController.dispose();
    amountController.dispose();
    noteController.dispose();
    super.dispose();
  }

  void submit(SchoolStore store) {
    if (titleController.text.trim().isEmpty ||
        amountController.text.trim().isEmpty ||
        courseId == null) {
      setState(() => error = 'اختر القسم واكتب اسم المصروف والمبلغ أولا.');
      return;
    }
    store.createExpense(
      title: titleController.text,
      amount: amountController.text,
      category: category,
      courseId: courseId!,
      note: noteController.text,
    );
    if (store.lastError != null) {
      setState(() => error = store.lastError);
      return;
    }
    titleController.clear();
    amountController.clear();
    noteController.clear();
    setState(() => error = null);
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('تمت إضافة المصروف')));
  }

  @override
  Widget build(BuildContext context) {
    final store = StoreScope.of(context);
    final courses = store.visibleFinancialCoursesFor(store.currentUser);
    if (courses.isNotEmpty && !courses.any((course) => course.id == courseId)) {
      courseId = courses.first.id;
    }
    final selectedCourse = store.courseById(courseId);
    final selectedCourseBox = courseId == null
        ? 0.0
        : store.courseBoxAmount(courseId!);
    final total = store.visibleExpenses
        .map((expense) => priceNumberFromText(expense.amount) ?? 0)
        .fold<double>(0, (runningTotal, amount) => runningTotal + amount);
    final totalText = total == total.roundToDouble()
        ? total.round().toString()
        : total.toStringAsFixed(2);

    return Scaffold(
      backgroundColor: const Color(0xFFF7F9FF),
      appBar: const EpsilonAppBar(title: 'المصاريف', showLogout: false),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
        children: [
          AdminPageHeader(
            title: 'المصاريف',
            subtitle: 'سجل مصاريف المدرسة وتابع الإجمالي',
            icon: Icons.receipt_long_rounded,
            color: const Color(0xFFF2A51A),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: ExpenseSummaryCard(
                  title: 'إجمالي المصاريف',
                  value: '$totalText أوقية',
                  icon: Icons.payments_rounded,
                  color: const Color(0xFFF2A51A),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: ExpenseSummaryCard(
                  title: 'عدد العمليات',
                  value: store.visibleExpenses.length.toString(),
                  icon: Icons.list_alt_rounded,
                  color: epsilonBlue,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          SectionCard(
            title: 'إضافة مصروف',
            icon: Icons.add_card_rounded,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                TextField(
                  controller: titleController,
                  decoration: const InputDecoration(
                    labelText: 'اسم المصروف',
                    hintText: 'مثال: راتب أستاذ، إعلان، إنترنت',
                    prefixIcon: Icon(Icons.edit_note_rounded),
                  ),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: amountController,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: 'المبلغ',
                    hintText: 'مثال: 5000',
                    prefixIcon: Icon(Icons.payments_rounded),
                  ),
                ),
                const SizedBox(height: 10),
                courses.isEmpty
                    ? const EmptyState(text: 'لا توجد أقسام مرتبطة بحسابك.')
                    : DropdownButtonFormField<String>(
                        initialValue: courseId,
                        decoration: const InputDecoration(
                          labelText: 'القسم',
                          prefixIcon: Icon(Icons.menu_book_rounded),
                        ),
                        items: courses
                            .map(
                              (course) => DropdownMenuItem(
                                value: course.id,
                                child: Text(course.title),
                              ),
                            )
                            .toList(),
                        onChanged: (value) => setState(() {
                          courseId = value;
                          error = null;
                        }),
                      ),
                if (selectedCourse != null) ...[
                  const SizedBox(height: 8),
                  InfoRow(
                    label: 'رصيد ${selectedCourse.title}',
                    value: '${formatBoxAmount(selectedCourseBox)} أوقية',
                  ),
                ],
                const SizedBox(height: 10),
                DropdownButtonFormField<String>(
                  initialValue: category,
                  decoration: const InputDecoration(
                    labelText: 'التصنيف',
                    prefixIcon: Icon(Icons.category_rounded),
                  ),
                  items: categories
                      .map(
                        (item) =>
                            DropdownMenuItem(value: item, child: Text(item)),
                      )
                      .toList(),
                  onChanged: (value) {
                    if (value != null) {
                      setState(() => category = value);
                    }
                  },
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: noteController,
                  minLines: 2,
                  maxLines: 3,
                  decoration: const InputDecoration(
                    labelText: 'ملاحظة اختيارية',
                    prefixIcon: Icon(Icons.notes_rounded),
                  ),
                ),
                if (error != null) ...[
                  const SizedBox(height: 10),
                  Text(error!, style: TextStyle(color: Colors.red.shade700)),
                ],
                const SizedBox(height: 12),
                FilledButton.icon(
                  onPressed: () => submit(store),
                  icon: const Icon(Icons.add_rounded),
                  label: const Text('إضافة المصروف'),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          SectionCard(
            title: 'سجل المصاريف',
            icon: Icons.history_rounded,
            child: store.visibleExpenses.isEmpty
                ? const EmptyState(text: 'لا توجد مصاريف مسجلة بعد.')
                : Column(
                    children: [
                      for (final expense in store.visibleExpenses)
                        ExpenseTile(expense: expense),
                    ],
                  ),
          ),
        ],
      ),
    );
  }
}

class ExpenseSummaryCard extends StatelessWidget {
  const ExpenseSummaryCard({
    required this.title,
    required this.value,
    required this.icon,
    required this.color,
    super.key,
  });

  final String title;
  final String value;
  final IconData icon;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withValues(alpha: 0.16)),
      ),
      child: Column(
        children: [
          Icon(icon, color: color),
          const SizedBox(height: 8),
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: color,
              fontSize: 18,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: epsilonMuted,
              fontSize: 12,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}

class ExpenseTile extends StatelessWidget {
  const ExpenseTile({required this.expense, super.key});

  final ExpenseItem expense;

  @override
  Widget build(BuildContext context) {
    final store = StoreScope.of(context);

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFF),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: epsilonLine),
      ),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: const Color(0xFFF2A51A).withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(14),
            ),
            child: const Icon(
              Icons.receipt_long_rounded,
              color: Color(0xFFF2A51A),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  expense.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: epsilonInk,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '${expense.category} - ${formatArabicDate(expense.createdAt)}',
                  style: const TextStyle(
                    color: epsilonMuted,
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                if (expense.courseTitle?.trim().isNotEmpty == true) ...[
                  const SizedBox(height: 3),
                  Text(
                    'القسم: ${expense.courseTitle}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: epsilonMuted,
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
                if (expense.note.trim().isNotEmpty) ...[
                  const SizedBox(height: 3),
                  Text(
                    expense.note,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(color: epsilonMuted, fontSize: 12),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(width: 8),
          Text(
            expense.amount,
            style: const TextStyle(
              color: Color(0xFFF2A51A),
              fontWeight: FontWeight.w900,
            ),
          ),
          IconButton(
            tooltip: 'حذف',
            onPressed: () => store.deleteExpense(expense),
            icon: const Icon(Icons.delete_outline_rounded),
          ),
        ],
      ),
    );
  }
}

class AdminPaymentSettingsPage extends StatelessWidget {
  const AdminPaymentSettingsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF7F9FF),
      appBar: const EpsilonAppBar(title: 'طرق الدفع', showLogout: false),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
        children: const [
          AdminPageHeader(
            title: 'طرق الدفع',
            subtitle: 'إدارة أرقام الدفع والطرق التي تظهر للطلاب',
            icon: Icons.account_balance_wallet_rounded,
            color: epsilonBlue,
          ),
          SizedBox(height: 16),
          PaymentNumberForm(),
        ],
      ),
    );
  }
}

class AdminAddTeacherPage extends StatelessWidget {
  const AdminAddTeacherPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF7F9FF),
      appBar: const EpsilonAppBar(title: 'إضافة أستاذ', showLogout: false),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
        children: const [CreateTeacherForm()],
      ),
    );
  }
}

class AdminUploadLessonPage extends StatefulWidget {
  const AdminUploadLessonPage({super.key});

  @override
  State<AdminUploadLessonPage> createState() => _AdminUploadLessonPageState();
}

class _AdminUploadLessonPageState extends State<AdminUploadLessonPage> {
  final titleController = TextEditingController();
  final urlController = TextEditingController();
  String? teacherId;
  String? courseId;
  String? subject;
  String? error;

  @override
  void dispose() {
    titleController.dispose();
    urlController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final store = StoreScope.of(context);
    final visibleCourses = store.visibleFinancialCoursesFor(store.currentUser);
    final visibleCourseIds = visibleCourses.map((course) => course.id).toSet();
    final teachers = store.teachers.where((teacher) {
      final teacherCourseId = teacher.courseId;
      return teacherCourseId != null &&
          visibleCourseIds.contains(teacherCourseId);
    }).toList();
    if (teacherId != null &&
        !teachers.any((teacher) => teacher.id == teacherId)) {
      teacherId = null;
    }
    final selectedTeacher = teachers.where((item) => item.id == teacherId);
    final teacher = selectedTeacher.isEmpty ? null : selectedTeacher.first;
    final availableCourses = teacher == null
        ? visibleCourses
        : visibleCourses
              .where(
                (course) =>
                    course.id == teacher.courseId &&
                    course.subjects.contains(teacher.subject),
              )
              .toList();
    if (courseId == null && availableCourses.isNotEmpty) {
      courseId = availableCourses.first.id;
    }
    if (!availableCourses.any((course) => course.id == courseId)) {
      courseId = availableCourses.isEmpty ? null : availableCourses.first.id;
    }
    final selectedCourse = store.courseById(courseId);
    final availableSubjects = teacher?.subject == null
        ? selectedCourse?.subjects ?? <String>[]
        : <String>[teacher!.subject!];
    if (!availableSubjects.contains(subject)) {
      subject = availableSubjects.firstOrNull;
    }

    return Scaffold(
      backgroundColor: const Color(0xFFF7F9FF),
      appBar: const EpsilonAppBar(title: 'رفع درس', showLogout: false),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
        children: [
          AdminPageHeader(
            title: 'رفع درس',
            subtitle: 'اختر القسم والمادة، ويمكن ربط الدرس بأستاذ عند توفره',
            icon: Icons.cloud_upload_rounded,
            color: const Color(0xFF6D38C9),
          ),
          const SizedBox(height: 16),
          SectionCard(
            title: 'بيانات الدرس',
            icon: Icons.add_link_rounded,
            child: availableCourses.isEmpty
                ? const EmptyState(text: 'أنشئ قسما قبل رفع الدروس.')
                : Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      if (teachers.isNotEmpty) ...[
                        DropdownButtonFormField<String?>(
                          initialValue: teacherId,
                          decoration: const InputDecoration(
                            labelText: 'الأستاذ',
                            prefixIcon: Icon(Icons.co_present_rounded),
                          ),
                          items: [
                            const DropdownMenuItem<String?>(
                              value: null,
                              child: Text('رفع مباشر من الإدارة'),
                            ),
                            ...teachers.map(
                              (teacher) => DropdownMenuItem<String?>(
                                value: teacher.id,
                                child: Text(
                                  '${teacher.name} - ${teacher.subject ?? 'مادة عامة'}',
                                ),
                              ),
                            ),
                          ],
                          onChanged: (value) {
                            setState(() {
                              teacherId = value;
                              courseId = null;
                              subject = null;
                              error = null;
                            });
                          },
                        ),
                        const SizedBox(height: 10),
                      ],
                      DropdownButtonFormField<String>(
                        initialValue: courseId,
                        decoration: const InputDecoration(
                          labelText: 'القسم',
                          prefixIcon: Icon(Icons.menu_book_rounded),
                        ),
                        items: availableCourses
                            .map(
                              (course) => DropdownMenuItem(
                                value: course.id,
                                child: Text(course.title),
                              ),
                            )
                            .toList(),
                        onChanged: teacher == null
                            ? (value) => setState(() {
                                courseId = value;
                                subject = null;
                              })
                            : null,
                      ),
                      const SizedBox(height: 10),
                      DropdownButtonFormField<String>(
                        initialValue: subject,
                        decoration: const InputDecoration(
                          labelText: 'المادة',
                          prefixIcon: Icon(Icons.subject_rounded),
                        ),
                        items: availableSubjects
                            .map(
                              (item) => DropdownMenuItem(
                                value: item,
                                child: Text(item),
                              ),
                            )
                            .toList(),
                        onChanged: teacher == null
                            ? (value) => setState(() => subject = value)
                            : null,
                      ),
                      const SizedBox(height: 10),
                      TextField(
                        controller: titleController,
                        decoration: const InputDecoration(
                          labelText: 'عنوان الدرس',
                          prefixIcon: Icon(Icons.title_rounded),
                        ),
                      ),
                      const SizedBox(height: 10),
                      TextField(
                        controller: urlController,
                        keyboardType: TextInputType.url,
                        decoration: const InputDecoration(
                          labelText: 'رابط فيديو Google Drive',
                          prefixIcon: Icon(Icons.link_rounded),
                        ),
                      ),
                      if (error != null) ...[
                        const SizedBox(height: 10),
                        Text(
                          error!,
                          style: TextStyle(color: Colors.red.shade700),
                        ),
                      ],
                      const SizedBox(height: 12),
                      FilledButton.icon(
                        onPressed: () {
                          final pickedTeacher = teacher;
                          final pickedCourse = courseId == null
                              ? null
                              : store.courseById(courseId);
                          if (pickedCourse == null ||
                              subject == null ||
                              titleController.text.trim().isEmpty ||
                              urlController.text.trim().isEmpty) {
                            setState(
                              () => error =
                                  'أكمل القسم والمادة والعنوان والرابط.',
                            );
                            return;
                          }
                          store.createLesson(
                            title: titleController.text,
                            url: urlController.text,
                            classId:
                                pickedTeacher?.classId ?? pickedCourse.classId,
                            courseId: pickedCourse.id,
                            teacherOverride: pickedTeacher,
                            subjectOverride: subject,
                          );
                          titleController.clear();
                          urlController.clear();
                          setState(() => error = null);
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('تم نشر الدرس')),
                          );
                        },
                        icon: const Icon(Icons.publish_rounded),
                        label: const Text('نشر الدرس'),
                      ),
                    ],
                  ),
          ),
        ],
      ),
    );
  }
}

class AdminStudentsReportPage extends StatefulWidget {
  const AdminStudentsReportPage({super.key});

  @override
  State<AdminStudentsReportPage> createState() =>
      _AdminStudentsReportPageState();
}

class _AdminStudentsReportPageState extends State<AdminStudentsReportPage> {
  static const allCoursesFilter = 'all';
  String selectedCourseId = allCoursesFilter;

  @override
  Widget build(BuildContext context) {
    final store = StoreScope.of(context);
    final courses = [...store.visibleFinancialCoursesFor(store.currentUser)]
      ..sort((a, b) => a.title.compareTo(b.title));
    final students = [...store.visibleStudents]
      ..sort((a, b) {
        final courseA = store.courseById(a.courseId)?.title ?? 'غير محدد';
        final courseB = store.courseById(b.courseId)?.title ?? 'غير محدد';
        final courseCompare = courseA.compareTo(courseB);
        if (courseCompare != 0) {
          return courseCompare;
        }
        return a.name.compareTo(b.name);
      });
    final filteredStudents = selectedCourseId == allCoursesFilter
        ? students
        : students
              .where((student) => student.courseId == selectedCourseId)
              .toList();

    return Scaffold(
      backgroundColor: const Color(0xFFF7F9FF),
      appBar: const EpsilonAppBar(title: 'كشف طلابنا', showLogout: false),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
        children: [
          AdminPageHeader(
            title: 'كشف طلابنا',
            subtitle: 'جدول منظم لجميع الطلاب مع فلترة حسب القسم',
            icon: Icons.table_chart_rounded,
            color: const Color(0xFF0891B2),
          ),
          const SizedBox(height: 16),
          SectionCard(
            title: 'فلترة الكشف',
            icon: Icons.filter_alt_rounded,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                DropdownButtonFormField<String>(
                  initialValue: selectedCourseId,
                  decoration: const InputDecoration(
                    labelText: 'القسم',
                    prefixIcon: Icon(Icons.menu_book_rounded),
                  ),
                  items: [
                    const DropdownMenuItem(
                      value: allCoursesFilter,
                      child: Text('كل الأقسام'),
                    ),
                    ...courses.map(
                      (course) => DropdownMenuItem(
                        value: course.id,
                        child: Text(course.title),
                      ),
                    ),
                  ],
                  onChanged: (value) {
                    if (value == null) {
                      return;
                    }
                    setState(() => selectedCourseId = value);
                  },
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: ReportStatCard(
                        label: 'إجمالي الطلاب',
                        value: students.length.toString(),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: ReportStatCard(
                        label: 'المعروض الآن',
                        value: filteredStudents.length.toString(),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          SectionCard(
            title: 'جدول الطلاب',
            icon: Icons.grid_on_rounded,
            child: filteredStudents.isEmpty
                ? const EmptyState(text: 'لا توجد حسابات طلاب في هذا القسم.')
                : LayoutBuilder(
                    builder: (context, constraints) {
                      return SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: ConstrainedBox(
                          constraints: BoxConstraints(
                            minWidth: max(760, constraints.maxWidth),
                          ),
                          child: DataTable(
                            headingRowColor: WidgetStateProperty.all(
                              const Color(0xFFEAF6FB),
                            ),
                            border: TableBorder.all(
                              color: const Color(0xFFE2E8F0),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            columns: const [
                              DataColumn(label: Text('#')),
                              DataColumn(label: Text('الاسم')),
                              DataColumn(label: Text('رقم الهاتف')),
                              DataColumn(label: Text('القسم')),
                              DataColumn(label: Text('الحالة')),
                              DataColumn(label: Text('رقم الدفع')),
                            ],
                            rows: [
                              for (
                                var index = 0;
                                index < filteredStudents.length;
                                index++
                              )
                                _studentReportRow(
                                  store,
                                  filteredStudents[index],
                                  index + 1,
                                ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  DataRow _studentReportRow(SchoolStore store, AppUser student, int index) {
    final course = store.courseById(student.courseId);

    return DataRow(
      cells: [
        DataCell(Text(index.toString())),
        DataCell(Text(student.name)),
        DataCell(Text(student.phone)),
        DataCell(Text(course?.title ?? 'غير محدد')),
        DataCell(Text(statusLabel(student.status))),
        DataCell(Text(student.paymentSenderPhone ?? '-')),
      ],
    );
  }
}

class ReportStatCard extends StatelessWidget {
  const ReportStatCard({required this.label, required this.value, super.key});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: const Color(0xFFEAF6FB),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFFCDEAF4)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(
              color: Color(0xFF0E7490),
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
              color: const Color(0xFF164E63),
              fontWeight: FontWeight.w900,
            ),
          ),
        ],
      ),
    );
  }
}

class AdminHeroPanel extends StatelessWidget {
  const AdminHeroPanel({
    required this.title,
    required this.subtitle,
    required this.value,
    super.key,
  });

  final String title;
  final String subtitle;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFF2F5BEA),
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF2F5BEA).withValues(alpha: 0.22),
            blurRadius: 24,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  subtitle,
                  style: const TextStyle(
                    color: Color(0xFFE8EEFF),
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
          Container(
            width: 70,
            height: 70,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.16),
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: Colors.white24),
            ),
            child: Center(
              child: Text(
                value,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 28,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class AdminNavButton extends StatelessWidget {
  const AdminNavButton({
    required this.title,
    required this.metric,
    required this.subtitle,
    required this.icon,
    required this.color,
    required this.onTap,
    super.key,
  });

  final String title;
  final String metric;
  final String subtitle;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(16),
      shadowColor: const Color(0xFF1F2937).withValues(alpha: 0.08),
      elevation: 6,
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      color: color.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Icon(icon, color: color),
                  ),
                  const Spacer(),
                  const Icon(
                    Icons.arrow_back_rounded,
                    color: Color(0xFF9CA3AF),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Text(
                title,
                style: Theme.of(
                  context,
                ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w900),
              ),
              const SizedBox(height: 6),
              Text(
                metric,
                style: TextStyle(color: color, fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 8),
              Text(
                subtitle,
                style: const TextStyle(color: Color(0xFF6B7280), height: 1.4),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class AdminPageHeader extends StatelessWidget {
  const AdminPageHeader({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.color,
    super.key,
  });

  final String title;
  final String subtitle;
  final IconData icon;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFE8EEFF)),
      ),
      child: Row(
        children: [
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Icon(icon, color: color, size: 28),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  subtitle,
                  style: const TextStyle(
                    color: Color(0xFF6B7280),
                    height: 1.35,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class AccountStatusFilters extends StatelessWidget {
  const AccountStatusFilters({required this.students, super.key});

  final List<AppUser> students;

  int count(AccountStatus status) {
    return students.where((student) => student.status == status).length;
  }

  @override
  Widget build(BuildContext context) {
    final chips = [
      StatusFilterData(
        label: 'بانتظار الدفع',
        value: count(AccountStatus.pending),
        color: const Color(0xFFF59E0B),
      ),
      StatusFilterData(
        label: 'نشط',
        value: count(AccountStatus.active),
        color: const Color(0xFF10B981),
      ),
      StatusFilterData(
        label: 'مجمد',
        value: count(AccountStatus.blocked),
        color: const Color(0xFF64748B),
      ),
      StatusFilterData(
        label: 'مرفوض',
        value: count(AccountStatus.rejected),
        color: const Color(0xFFEF4444),
      ),
    ];

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: chips
            .map(
              (chip) => Padding(
                padding: const EdgeInsets.only(left: 8),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 9,
                  ),
                  decoration: BoxDecoration(
                    color: chip.color.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(999),
                    border: Border.all(
                      color: chip.color.withValues(alpha: 0.18),
                    ),
                  ),
                  child: Row(
                    children: [
                      Text(
                        chip.value.toString(),
                        style: TextStyle(
                          color: chip.color,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        chip.label,
                        style: const TextStyle(
                          color: Color(0xFF374151),
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            )
            .toList(),
      ),
    );
  }
}

class StatusFilterData {
  const StatusFilterData({
    required this.label,
    required this.value,
    required this.color,
  });

  final String label;
  final int value;
  final Color color;
}

class AdminAccountsPage extends StatelessWidget {
  const AdminAccountsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final store = StoreScope.of(context);
    final students = store.visibleStudents;

    return Scaffold(
      backgroundColor: const Color(0xFFF7F9FF),
      appBar: const EpsilonAppBar(title: 'الحسابات'),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
        children: [
          AdminPageHeader(
            title: 'حسابات الطلاب',
            subtitle: 'متابعة حالات الطلاب وتفعيل أو تجميد الحسابات',
            icon: Icons.people_alt_rounded,
            color: const Color(0xFFB63B65),
          ),
          const SizedBox(height: 16),
          AccountStatusFilters(students: students),
          const SizedBox(height: 16),
          SectionCard(
            title: 'كل حسابات الطلاب',
            icon: Icons.people_alt_rounded,
            child: students.isEmpty
                ? const EmptyState(text: 'لا توجد حسابات طلاب بعد.')
                : Column(
                    children: students
                        .map(
                          (student) => UserTile(
                            user: student,
                            trailing: AccountActionButton(user: student),
                          ),
                        )
                        .toList(),
                  ),
          ),
        ],
      ),
    );
  }
}

class AdminPaymentRequestsPage extends StatelessWidget {
  const AdminPaymentRequestsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final store = StoreScope.of(context);
    final pendingStudents = store.visiblePendingStudents;

    return Scaffold(
      backgroundColor: const Color(0xFFF7F9FF),
      appBar: const EpsilonAppBar(title: 'طلبات الدفع', showLogout: false),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
        children: [
          AdminPageHeader(
            title: 'طلبات الطلاب وإثباتات الدفع',
            subtitle: 'راجع صورة الدفع ورقم المرسل ثم قرر قبول الحساب',
            icon: Icons.fact_check_rounded,
            color: const Color(0xFFF59E0B),
          ),
          const SizedBox(height: 16),
          SectionCard(
            title: 'طلبات بانتظار المراجعة',
            icon: Icons.receipt_long_rounded,
            child: pendingStudents.isEmpty
                ? const EmptyState(text: 'لا توجد طلبات دفع بانتظار المراجعة.')
                : Column(
                    children: pendingStudents
                        .map((student) => PaymentReviewTile(user: student))
                        .toList(),
                  ),
          ),
        ],
      ),
    );
  }
}

class PaymentReviewTile extends StatelessWidget {
  const PaymentReviewTile({required this.user, super.key});

  final AppUser user;

  @override
  Widget build(BuildContext context) {
    final store = StoreScope.of(context);

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFFAFBFF),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE3E9FF)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          UserTile(user: user, compact: true),
          InfoRow(
            label: 'رقم المرسل',
            value: user.paymentSenderPhone?.trim().isNotEmpty == true
                ? user.paymentSenderPhone!
                : 'غير مضاف',
          ),
          InfoRow(
            label: 'المبلغ',
            value: user.paymentAmount.trim().isNotEmpty
                ? user.paymentAmount
                : 'غير محدد',
          ),
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 10),
            child: PaymentProofPreview(
              imagePath: user.paymentProofPath,
              emptyText: 'لم تصل صورة إثبات دفع',
              height: 150,
            ),
          ),
          Row(
            children: [
              Expanded(
                child: FilledButton.icon(
                  onPressed: () => store.approveUser(user),
                  icon: const Icon(Icons.check_rounded),
                  label: const Text('قبول'),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => store.blockUser(user),
                  icon: const Icon(Icons.pause_circle_outline_rounded),
                  label: const Text('تجميد'),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => store.rejectUser(user),
                  icon: const Icon(Icons.close_rounded),
                  label: const Text('رفض'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class CreateStudentForm extends StatefulWidget {
  const CreateStudentForm({super.key});

  @override
  State<CreateStudentForm> createState() => _CreateStudentFormState();
}

class _CreateStudentFormState extends State<CreateStudentForm> {
  final nameController = TextEditingController();
  final phoneController = TextEditingController();
  final passwordController = TextEditingController(text: '123456');
  final amountController = TextEditingController();
  String? courseId;

  @override
  void dispose() {
    nameController.dispose();
    phoneController.dispose();
    passwordController.dispose();
    amountController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final store = StoreScope.of(context);
    final availableCourses = store.visibleFinancialCoursesFor(
      store.currentUser,
    );
    if (availableCourses.isNotEmpty &&
        !availableCourses.any((course) => course.id == courseId)) {
      courseId = availableCourses.first.id;
    }

    return SectionCard(
      title: 'إنشاء حساب طالب',
      icon: Icons.person_add_alt_1_rounded,
      child: Column(
        children: [
          TextField(
            controller: nameController,
            decoration: const InputDecoration(labelText: 'اسم الطالب'),
          ),
          const SizedBox(height: 10),
          TextField(
            controller: phoneController,
            keyboardType: TextInputType.phone,
            decoration: const InputDecoration(
              labelText: 'رقم الهاتف',
              prefixIcon: Icon(Icons.phone_iphone_rounded),
            ),
          ),
          const SizedBox(height: 10),
          TextField(
            controller: passwordController,
            decoration: const InputDecoration(labelText: 'كلمة المرور'),
          ),
          const SizedBox(height: 10),
          availableCourses.isEmpty
              ? const EmptyState(text: 'أنشئ قسما قبل إضافة طالب.')
              : DropdownButtonFormField<String>(
                  initialValue: courseId,
                  decoration: const InputDecoration(labelText: 'القسم'),
                  items: availableCourses
                      .map(
                        (course) => DropdownMenuItem(
                          value: course.id,
                          child: Text(course.title),
                        ),
                      )
                      .toList(),
                  onChanged: (value) => setState(() => courseId = value),
                ),
          const SizedBox(height: 10),
          TextField(
            controller: amountController,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: const InputDecoration(
              labelText: 'المبلغ المدفوع (اختياري)',
              hintText: 'مثال: 3000',
              prefixIcon: Icon(Icons.payments_rounded),
            ),
          ),
          const SizedBox(height: 12),
          Align(
            alignment: Alignment.centerLeft,
            child: FilledButton.icon(
              onPressed: () {
                if (nameController.text.trim().isEmpty ||
                    phoneController.text.trim().isEmpty ||
                    passwordController.text.length < 6 ||
                    courseId == null) {
                  return;
                }

                store.createStudentByAdmin(
                  name: nameController.text,
                  phone: phoneController.text,
                  password: passwordController.text,
                  courseId: courseId!,
                  paymentAmount: amountController.text,
                );
                nameController.clear();
                phoneController.clear();
                amountController.clear();
              },
              icon: const Icon(Icons.add_rounded),
              label: const Text('إضافة الطالب'),
            ),
          ),
        ],
      ),
    );
  }
}

class AdminTeachersPage extends StatelessWidget {
  const AdminTeachersPage({super.key});

  @override
  Widget build(BuildContext context) {
    final store = StoreScope.of(context);

    return Scaffold(
      backgroundColor: const Color(0xFFF7F9FF),
      appBar: const EpsilonAppBar(title: 'الأساتذة'),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
        children: [
          AdminPageHeader(
            title: 'إدارة الأساتذة',
            subtitle: 'اربط كل أستاذ بقسم ومادة واحدة',
            icon: Icons.co_present_rounded,
            color: const Color(0xFF0F766E),
          ),
          const SizedBox(height: 16),
          const CreateTeacherForm(),
          const SizedBox(height: 16),
          SectionCard(
            title: 'حسابات الأساتذة',
            icon: Icons.co_present_rounded,
            child: store.teachers.isEmpty
                ? const EmptyState(text: 'لا يوجد أساتذة بعد.')
                : Column(
                    children: store.teachers
                        .map(
                          (teacher) => UserTile(
                            user: teacher,
                            trailing: AccountActionButton(user: teacher),
                          ),
                        )
                        .toList(),
                  ),
          ),
        ],
      ),
    );
  }
}

class AdminCoursesPage extends StatelessWidget {
  const AdminCoursesPage({super.key});

  @override
  Widget build(BuildContext context) {
    final store = StoreScope.of(context);

    return Scaffold(
      backgroundColor: const Color(0xFFF7F9FF),
      appBar: const EpsilonAppBar(title: 'الأقسام'),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
        children: [
          AdminPageHeader(
            title: 'الأقسام والمواد',
            subtitle: 'أضف قسما مثل البكالوريا وحدد مواده',
            icon: Icons.menu_book_rounded,
            color: const Color(0xFF7C3AED),
          ),
          const SizedBox(height: 16),
          const CreateCourseForm(),
          const SizedBox(height: 16),
          SectionCard(
            title: 'الأقسام المضافة',
            icon: Icons.menu_book_rounded,
            child: store.courses.isEmpty
                ? const EmptyState(text: 'لا توجد أقسام بعد.')
                : Column(
                    children: store.courses
                        .map((course) => CourseAdminTile(course: course))
                        .toList(),
                  ),
          ),
        ],
      ),
    );
  }
}

class CourseAdminTile extends StatelessWidget {
  const CourseAdminTile({required this.course, super.key});

  final Course course;

  @override
  Widget build(BuildContext context) {
    final store = StoreScope.of(context);

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFF),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: epsilonLine),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              const Icon(Icons.menu_book_rounded, color: Color(0xFF7C3AED)),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  course.title,
                  style: const TextStyle(
                    color: epsilonInk,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
              IconButton(
                tooltip: 'تعديل مدة التجديد',
                onPressed: () => showDialog<void>(
                  context: context,
                  builder: (_) => EditCourseRenewalDialog(course: course),
                ),
                icon: const Icon(Icons.edit_calendar_rounded),
              ),
              IconButton(
                tooltip: 'حذف',
                onPressed: () => store.deleteCourse(course),
                icon: const Icon(Icons.delete_outline_rounded),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            'السعر: ${course.price.trim().isEmpty ? 'غير محدد' : course.price}',
            style: const TextStyle(
              color: epsilonMuted,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'مدة التجديد: كل ${course.renewalMonths} شهر',
            style: const TextStyle(
              color: Color(0xFF7C3AED),
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'المواد: ${course.subjects.join('، ')}',
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(color: epsilonMuted),
          ),
        ],
      ),
    );
  }
}

class EditCourseRenewalDialog extends StatefulWidget {
  const EditCourseRenewalDialog({required this.course, super.key});

  final Course course;

  @override
  State<EditCourseRenewalDialog> createState() =>
      _EditCourseRenewalDialogState();
}

class _EditCourseRenewalDialogState extends State<EditCourseRenewalDialog> {
  late final TextEditingController controller;
  bool isSaving = false;
  String? error;

  @override
  void initState() {
    super.initState();
    controller = TextEditingController(
      text: widget.course.renewalMonths.toString(),
    );
  }

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final store = StoreScope.of(context);

    return AlertDialog(
      title: const Text('تعديل مدة التجديد'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(widget.course.title),
          const SizedBox(height: 12),
          TextField(
            controller: controller,
            keyboardType: TextInputType.number,
            autofocus: true,
            decoration: const InputDecoration(
              labelText: 'مدة التجديد بالأشهر',
              prefixIcon: Icon(Icons.event_repeat_rounded),
            ),
          ),
          if (error != null) ...[
            const SizedBox(height: 10),
            Text(error!, style: TextStyle(color: Colors.red.shade700)),
          ],
        ],
      ),
      actions: [
        TextButton(
          onPressed: isSaving ? null : () => Navigator.of(context).pop(),
          child: const Text('إلغاء'),
        ),
        FilledButton(
          onPressed: isSaving
              ? null
              : () async {
                  final months = int.tryParse(controller.text.trim());
                  if (months == null || months < 1) {
                    setState(() => error = 'اكتب عددا صحيحا من الأشهر.');
                    return;
                  }
                  setState(() {
                    isSaving = true;
                    error = null;
                  });
                  await store.updateCourseRenewalMonths(
                    course: widget.course,
                    renewalMonths: months,
                  );
                  if (context.mounted) {
                    Navigator.of(context).pop();
                  }
                },
          child: Text(isSaving ? 'جار الحفظ...' : 'حفظ'),
        ),
      ],
    );
  }
}

class AdminGuestContentPage extends StatelessWidget {
  const AdminGuestContentPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF7F9FF),
      appBar: const EpsilonAppBar(title: 'محتوى الزائر'),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
        children: [
          const AdminPageHeader(
            title: 'محتوى الزائر',
            subtitle: 'أضف روابط Google Drive التي تظهر قبل تسجيل الدخول',
            icon: Icons.public_rounded,
            color: Color(0xFFF97316),
          ),
          const SizedBox(height: 16),
          GuestActionCard(
            title: 'الفيديوهات المجانية',
            subtitle: 'إضافة وتعديل وحذف الفيديوهات المجانية',
            icon: Icons.play_circle_rounded,
            color: const Color(0xFF2F5BEA),
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => const AdminGuestContentManagerPage(
                  type: GuestContentType.video,
                ),
              ),
            ),
          ),
          const SizedBox(height: 12),
          GuestActionCard(
            title: 'الأرشيف PDF',
            subtitle: 'إضافة وتعديل وحذف ملفات PDF',
            icon: Icons.picture_as_pdf_rounded,
            color: const Color(0xFF0F766E),
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => const AdminGuestContentManagerPage(
                  type: GuestContentType.archive,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

enum GuestContentType { video, archive }

class AdminGuestContentManagerPage extends StatelessWidget {
  const AdminGuestContentManagerPage({required this.type, super.key});

  final GuestContentType type;

  bool get isVideo => type == GuestContentType.video;

  @override
  Widget build(BuildContext context) {
    final store = StoreScope.of(context);
    final items = isVideo ? store.guestVideos : store.archiveFiles;

    return Scaffold(
      backgroundColor: const Color(0xFFF7F9FF),
      appBar: EpsilonAppBar(
        title: isVideo ? 'الفيديوهات المجانية' : 'الأرشيف PDF',
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
        children: [
          AdminPageHeader(
            title: isVideo ? 'الفيديوهات المجانية' : 'الأرشيف PDF',
            subtitle: isVideo
                ? 'أضف روابط الفيديوهات المجانية وعدلها بسهولة'
                : 'أضف روابط ملفات PDF وعدلها بسهولة',
            icon: isVideo
                ? Icons.play_circle_rounded
                : Icons.picture_as_pdf_rounded,
            color: isVideo ? const Color(0xFF2F5BEA) : const Color(0xFF0F766E),
          ),
          const SizedBox(height: 16),
          GuestContentForm(type: type),
          const SizedBox(height: 16),
          GuestContentList(
            title: isVideo ? 'الفيديوهات المنشورة' : 'ملفات الأرشيف',
            icon: isVideo
                ? Icons.play_circle_rounded
                : Icons.picture_as_pdf_rounded,
            items: items,
            emptyText: isVideo
                ? 'لا توجد فيديوهات مجانية بعد.'
                : 'لا توجد ملفات في الأرشيف بعد.',
            type: type,
          ),
        ],
      ),
    );
  }
}

class GuestContentForm extends StatefulWidget {
  const GuestContentForm({required this.type, super.key});

  final GuestContentType type;

  @override
  State<GuestContentForm> createState() => _GuestContentFormState();
}

class _GuestContentFormState extends State<GuestContentForm> {
  final titleController = TextEditingController();
  final urlController = TextEditingController();
  final descriptionController = TextEditingController();
  String? selectedCourseId;

  bool get isVideo => widget.type == GuestContentType.video;

  @override
  void dispose() {
    titleController.dispose();
    urlController.dispose();
    descriptionController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final store = StoreScope.of(context);

    return SectionCard(
      title: isVideo ? 'رفع فيديو مجاني' : 'رفع ملف للأرشيف',
      icon: isVideo ? Icons.play_circle_rounded : Icons.picture_as_pdf_rounded,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TextField(
            controller: titleController,
            decoration: InputDecoration(
              labelText: isVideo ? 'عنوان الفيديو' : 'عنوان الملف',
            ),
          ),
          const SizedBox(height: 10),
          DropdownButtonFormField<String>(
            initialValue: selectedCourseId,
            decoration: const InputDecoration(
              labelText: 'القسم',
              prefixIcon: Icon(Icons.menu_book_rounded),
            ),
            items: store.courses
                .map(
                  (course) => DropdownMenuItem(
                    value: course.id,
                    child: Text(course.title),
                  ),
                )
                .toList(),
            onChanged: (value) => setState(() => selectedCourseId = value),
          ),
          const SizedBox(height: 10),
          TextField(
            controller: urlController,
            keyboardType: TextInputType.url,
            decoration: const InputDecoration(
              labelText: 'رابط Google Drive',
              prefixIcon: Icon(Icons.link_rounded),
            ),
          ),
          const SizedBox(height: 10),
          TextField(
            controller: descriptionController,
            minLines: 2,
            maxLines: 3,
            decoration: const InputDecoration(labelText: 'وصف مختصر'),
          ),
          const SizedBox(height: 12),
          Align(
            alignment: Alignment.centerLeft,
            child: FilledButton.icon(
              onPressed: () {
                if (titleController.text.trim().isEmpty ||
                    urlController.text.trim().isEmpty ||
                    selectedCourseId == null) {
                  return;
                }

                if (isVideo) {
                  store.addGuestVideo(
                    title: titleController.text,
                    url: urlController.text,
                    description: descriptionController.text,
                    courseId: selectedCourseId!,
                  );
                } else {
                  store.addArchiveFile(
                    title: titleController.text,
                    url: urlController.text,
                    description: descriptionController.text,
                    courseId: selectedCourseId!,
                  );
                }

                titleController.clear();
                urlController.clear();
                descriptionController.clear();
                setState(() => selectedCourseId = null);
              },
              icon: const Icon(Icons.add_rounded),
              label: Text(isVideo ? 'إضافة الفيديو' : 'إضافة الملف'),
            ),
          ),
        ],
      ),
    );
  }
}

class GuestContentList extends StatelessWidget {
  const GuestContentList({
    required this.title,
    required this.icon,
    required this.items,
    required this.emptyText,
    required this.type,
    super.key,
  });

  final String title;
  final IconData icon;
  final List<GuestContentItem> items;
  final String emptyText;
  final GuestContentType type;

  @override
  Widget build(BuildContext context) {
    final store = StoreScope.of(context);

    return SectionCard(
      title: title,
      icon: icon,
      child: items.isEmpty
          ? EmptyState(text: emptyText)
          : Column(
              children: items
                  .map(
                    (item) => ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: Icon(icon),
                      title: Text(item.title),
                      subtitle: Text(
                        [
                          'القسم: ${store.courseById(item.courseId)?.title ?? 'غير محدد'}',
                          item.description.trim().isEmpty
                              ? item.url
                              : item.description,
                        ].join('\n'),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                            tooltip: 'تعديل',
                            onPressed: () => showDialog<void>(
                              context: context,
                              builder: (_) => EditGuestContentDialog(
                                item: item,
                                type: type,
                              ),
                            ),
                            icon: const Icon(Icons.edit_rounded),
                          ),
                          IconButton(
                            tooltip: 'حذف',
                            onPressed: () {
                              if (type == GuestContentType.video) {
                                store.deleteGuestVideo(item);
                              } else {
                                store.deleteArchiveFile(item);
                              }
                            },
                            icon: const Icon(Icons.delete_outline_rounded),
                          ),
                        ],
                      ),
                    ),
                  )
                  .toList(),
            ),
    );
  }
}

class EditGuestContentDialog extends StatefulWidget {
  const EditGuestContentDialog({
    required this.item,
    required this.type,
    super.key,
  });

  final GuestContentItem item;
  final GuestContentType type;

  @override
  State<EditGuestContentDialog> createState() => _EditGuestContentDialogState();
}

class _EditGuestContentDialogState extends State<EditGuestContentDialog> {
  late final TextEditingController titleController;
  late final TextEditingController urlController;
  late final TextEditingController descriptionController;
  late String? selectedCourseId;

  bool get isVideo => widget.type == GuestContentType.video;

  @override
  void initState() {
    super.initState();
    titleController = TextEditingController(text: widget.item.title);
    urlController = TextEditingController(text: widget.item.url);
    descriptionController = TextEditingController(
      text: widget.item.description,
    );
    selectedCourseId = widget.item.courseId;
  }

  @override
  void dispose() {
    titleController.dispose();
    urlController.dispose();
    descriptionController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final store = StoreScope.of(context);

    return AlertDialog(
      title: Text(isVideo ? 'تعديل الفيديو' : 'تعديل الملف'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: titleController,
              decoration: InputDecoration(
                labelText: isVideo ? 'عنوان الفيديو' : 'عنوان الملف',
              ),
            ),
            const SizedBox(height: 10),
            DropdownButtonFormField<String>(
              initialValue: selectedCourseId,
              decoration: const InputDecoration(
                labelText: 'القسم',
                prefixIcon: Icon(Icons.menu_book_rounded),
              ),
              items: store.courses
                  .map(
                    (course) => DropdownMenuItem(
                      value: course.id,
                      child: Text(course.title),
                    ),
                  )
                  .toList(),
              onChanged: (value) => setState(() => selectedCourseId = value),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: urlController,
              keyboardType: TextInputType.url,
              decoration: const InputDecoration(
                labelText: 'رابط Google Drive',
                prefixIcon: Icon(Icons.link_rounded),
              ),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: descriptionController,
              minLines: 2,
              maxLines: 3,
              decoration: const InputDecoration(labelText: 'وصف مختصر'),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('إلغاء'),
        ),
        FilledButton(
          onPressed: () {
            if (titleController.text.trim().isEmpty ||
                urlController.text.trim().isEmpty ||
                selectedCourseId == null) {
              return;
            }

            if (isVideo) {
              store.updateGuestVideo(
                item: widget.item,
                title: titleController.text,
                url: urlController.text,
                description: descriptionController.text,
                courseId: selectedCourseId!,
              );
            } else {
              store.updateArchiveFile(
                item: widget.item,
                title: titleController.text,
                url: urlController.text,
                description: descriptionController.text,
                courseId: selectedCourseId!,
              );
            }
            Navigator.of(context).pop();
          },
          child: const Text('حفظ'),
        ),
      ],
    );
  }
}

class TeacherDashboard extends StatelessWidget {
  const TeacherDashboard({super.key});

  @override
  Widget build(BuildContext context) {
    final store = StoreScope.of(context);
    final teacher = store.currentUser!;
    final teacherSection = store.courseById(teacher.courseId);
    final teacherSections = store.courses
        .where(
          (course) =>
              course.id == teacher.courseId &&
              course.subjects.contains(teacher.subject),
        )
        .toList();
    final teacherLessons =
        store.lessons.where((lesson) => lesson.teacherId == teacher.id).toList()
          ..sort((a, b) => b.createdAt.compareTo(a.createdAt));

    return Scaffold(
      backgroundColor: const Color(0xFFF7F9FF),
      appBar: const EpsilonAppBar(title: 'لوحة الأستاذ'),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
        children: [
          HeaderPanel(
            title: 'مرحبًا ${teacher.name}',
            subtitle:
                '${teacher.subject ?? 'مادة عامة'} - ${teacherSection?.title ?? 'بدون قسم'}',
            icon: Icons.co_present_rounded,
          ),
          const SizedBox(height: 16),
          SectionCard(
            title: 'مادتي داخل القسم',
            icon: Icons.subject_rounded,
            child: teacherSections.isEmpty
                ? const EmptyState(text: 'لا يوجد قسم مرتبط بمادتك حاليا.')
                : Column(
                    children: teacherSections
                        .map(
                          (course) => ListTile(
                            contentPadding: EdgeInsets.zero,
                            leading: Icon(
                              courseIcon(course.title),
                              color: courseAccent(course.title),
                            ),
                            title: Text(course.title),
                            subtitle: Text(
                              'المادة: ${teacher.subject ?? 'مادة عامة'}',
                            ),
                          ),
                        )
                        .toList(),
                  ),
          ),
          const SizedBox(height: 16),
          const CreateLessonForm(),
          const SizedBox(height: 16),
          SectionCard(
            title: 'إدارة دروسي',
            icon: Icons.video_library_rounded,
            child: teacherLessons.isEmpty
                ? const EmptyState(text: 'لم تقم بإضافة دروس بعد.')
                : Column(
                    children: teacherLessons
                        .map((lesson) => TeacherLessonTile(lesson: lesson))
                        .toList(),
                  ),
          ),
        ],
      ),
    );
  }
}

class StudentDashboard extends StatelessWidget {
  const StudentDashboard({super.key});

  @override
  Widget build(BuildContext context) {
    final store = StoreScope.of(context);
    final student = store.currentUser!;
    final selectedSection = store.courseById(student.courseId);
    final allowedSubjects = student.selectedSubjects.isNotEmpty
        ? student.selectedSubjects
        : selectedSection?.subjects ?? <String>[];
    final visibleLessons =
        store.lessons
            .where(
              (lesson) =>
                  lesson.isPublished &&
                  (student.courseId == null ||
                      lesson.courseId == student.courseId) &&
                  (allowedSubjects.isEmpty ||
                      allowedSubjects.contains(lesson.subject)),
            )
            .toList()
          ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
    final lessonsBySubject = <String, List<Lesson>>{};
    for (final subject in allowedSubjects) {
      lessonsBySubject[subject] = [];
    }
    for (final lesson in visibleLessons) {
      lessonsBySubject.putIfAbsent(lesson.subject, () => []).add(lesson);
    }
    final completedSubjects = lessonsBySubject.values
        .where((items) => items.isNotEmpty)
        .length;
    final invoiceAmount = studentInvoiceAmount(
      store: store,
      student: student,
      course: selectedSection,
      allowedSubjects: allowedSubjects,
    );

    return Scaffold(
      backgroundColor: const Color(0xFFF7F9FF),
      appBar: const EpsilonAppBar(title: 'دروسي'),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
        children: [
          HeaderPanel(
            title: 'مرحبًا ${student.name}',
            subtitle: selectedSection == null
                ? 'لم يتم ربطك بقسم بعد'
                : 'قسم ${selectedSection.title}',
            icon: Icons.auto_stories_rounded,
            logoAsset: 'assets/onboarding/epsilon_logo.jpeg',
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: StudentStatCard(
                  icon: Icons.subject_rounded,
                  value: '${allowedSubjects.length}',
                  label: 'موادك',
                  color: epsilonBlue,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: StudentStatCard(
                  icon: Icons.play_circle_rounded,
                  value: '${visibleLessons.length}',
                  label: 'الدروس',
                  color: epsilonTeal,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: StudentStatCard(
                  icon: Icons.check_circle_rounded,
                  value: '$completedSubjects',
                  label: 'نشطة',
                  color: epsilonGold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          if (selectedSection != null) ...[
            StudentInvoiceCard(
              student: student,
              course: selectedSection,
              subjects: allowedSubjects,
              amount: invoiceAmount,
            ),
            const SizedBox(height: 14),
          ],
          SectionCard(
            title: 'موادك الدراسية',
            icon: Icons.folder_special_rounded,
            child: lessonsBySubject.isEmpty
                ? const EmptyState(text: 'لا توجد مواد في هذا القسم.')
                : LayoutBuilder(
                    builder: (context, constraints) {
                      final wide = constraints.maxWidth > 390;
                      return Wrap(
                        spacing: 10,
                        runSpacing: 10,
                        children: lessonsBySubject.entries.map((entry) {
                          final width = wide
                              ? (constraints.maxWidth - 10) / 2
                              : constraints.maxWidth;
                          return SizedBox(
                            width: width,
                            child: SubjectCard(
                              subject: entry.key,
                              lessons: entry.value,
                            ),
                          );
                        }).toList(),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}

class StudentInvoiceCard extends StatefulWidget {
  const StudentInvoiceCard({
    required this.student,
    required this.course,
    required this.subjects,
    required this.amount,
    super.key,
  });

  final AppUser student;
  final Course course;
  final List<String> subjects;
  final String amount;

  @override
  State<StudentInvoiceCard> createState() => _StudentInvoiceCardState();
}

class _StudentInvoiceCardState extends State<StudentInvoiceCard> {
  bool isDownloading = false;

  Future<void> downloadInvoice() async {
    setState(() => isDownloading = true);
    try {
      final file = await createStudentInvoicePdf(
        student: widget.student,
        course: widget.course,
        subjects: widget.subjects,
        amount: widget.amount,
      );
      if (!mounted) {
        return;
      }
      final box = context.findRenderObject() as RenderBox?;
      await share.SharePlus.instance.share(
        share.ShareParams(
          title: 'فاتورة الاشتراك',
          subject: 'فاتورة اشتراك Epsilon Education',
          text: 'فاتورة اشتراك ${widget.student.name}',
          files: [
            share.XFile(
              file.path,
              mimeType: 'application/pdf',
              name: file.uri.pathSegments.last,
            ),
          ],
          fileNameOverrides: [file.uri.pathSegments.last],
          sharePositionOrigin: box == null
              ? null
              : box.localToGlobal(Offset.zero) & box.size,
        ),
      );
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('تم حفظ الفاتورة: ${file.uri.pathSegments.last}'),
        ),
      );
    } on Object catch (error) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('تعذر إنشاء الفاتورة: $error')));
    } finally {
      if (mounted) {
        setState(() => isDownloading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return SectionCard(
      title: 'فاتورة الاشتراك',
      icon: Icons.receipt_long_rounded,
      child: FilledButton.icon(
        onPressed: isDownloading ? null : downloadInvoice,
        icon: isDownloading
            ? const SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            : const Icon(Icons.download_rounded),
        label: Text(
          isDownloading ? 'جاري إنشاء الفاتورة...' : 'تحميل الفاتورة PDF',
        ),
        style: FilledButton.styleFrom(
          minimumSize: const Size.fromHeight(48),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
        ),
      ),
    );
  }
}

class StudentStatCard extends StatelessWidget {
  const StudentStatCard({
    required this.icon,
    required this.value,
    required this.label,
    required this.color,
    super.key,
  });

  final IconData icon;
  final String value;
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withValues(alpha: 0.18)),
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: 24),
          const SizedBox(height: 6),
          Text(
            value,
            style: TextStyle(
              color: color,
              fontSize: 20,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: epsilonMuted,
              fontSize: 12,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}

class CreateTeacherForm extends StatefulWidget {
  const CreateTeacherForm({super.key});

  @override
  State<CreateTeacherForm> createState() => _CreateTeacherFormState();
}

class _CreateTeacherFormState extends State<CreateTeacherForm> {
  final nameController = TextEditingController();
  final phoneController = TextEditingController();
  final passwordController = TextEditingController(text: '123456');
  String? classId;
  String? courseId;
  String? subject;
  String? message;
  bool isSaving = false;

  @override
  void dispose() {
    nameController.dispose();
    phoneController.dispose();
    passwordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final store = StoreScope.of(context);
    final availableSections = store.visibleFinancialCoursesFor(
      store.currentUser,
    );
    if (availableSections.isNotEmpty &&
        !availableSections.any((course) => course.id == courseId)) {
      courseId = availableSections.first.id;
      classId = availableSections.first.classId;
      subject = availableSections.first.subjects.firstOrNull;
    }
    final selectedCourse = store.courseById(courseId);
    if (selectedCourse != null && !selectedCourse.subjects.contains(subject)) {
      subject = selectedCourse.subjects.firstOrNull;
    }

    return SectionCard(
      title: 'إنشاء حساب أستاذ',
      icon: Icons.person_add_rounded,
      child: Column(
        children: [
          TextField(
            controller: nameController,
            decoration: const InputDecoration(labelText: 'اسم الأستاذ'),
          ),
          const SizedBox(height: 10),
          TextField(
            controller: phoneController,
            keyboardType: TextInputType.phone,
            decoration: const InputDecoration(
              labelText: 'رقم الهاتف',
              prefixIcon: Icon(Icons.phone_iphone_rounded),
            ),
          ),
          const SizedBox(height: 10),
          TextField(
            controller: passwordController,
            decoration: const InputDecoration(labelText: 'كلمة المرور'),
          ),
          const SizedBox(height: 10),
          availableSections.isEmpty
              ? const EmptyState(text: 'أنشئ قسما قبل إضافة أستاذ.')
              : DropdownButtonFormField<String>(
                  initialValue: courseId,
                  decoration: const InputDecoration(labelText: 'القسم'),
                  items: availableSections
                      .map(
                        (course) => DropdownMenuItem(
                          value: course.id,
                          child: Text(course.title),
                        ),
                      )
                      .toList(),
                  onChanged: (value) => setState(() {
                    courseId = value;
                    final section = store.courseById(value);
                    classId = section?.classId;
                    subject = section?.subjects.firstOrNull;
                  }),
                ),
          const SizedBox(height: 10),
          selectedCourse == null
              ? const EmptyState(text: 'اختر القسم لتظهر مواده.')
              : DropdownButtonFormField<String>(
                  initialValue: subject,
                  decoration: const InputDecoration(labelText: 'المادة'),
                  items: selectedCourse.subjects
                      .map(
                        (item) =>
                            DropdownMenuItem(value: item, child: Text(item)),
                      )
                      .toList(),
                  onChanged: (value) => setState(() => subject = value),
                ),
          const SizedBox(height: 12),
          if (message != null) ...[
            Text(
              message!,
              style: TextStyle(
                color: message!.startsWith('تم')
                    ? Colors.green.shade700
                    : Colors.red.shade700,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 10),
          ],
          Align(
            alignment: Alignment.centerLeft,
            child: FilledButton.icon(
              onPressed: isSaving
                  ? null
                  : () async {
                      if (nameController.text.trim().isEmpty ||
                          phoneController.text.trim().isEmpty ||
                          passwordController.text.length < 6 ||
                          classId == null ||
                          courseId == null ||
                          subject == null) {
                        setState(() {
                          message =
                              'أكمل البيانات وتأكد أن كلمة المرور 6 أحرف على الأقل.';
                        });
                        return;
                      }

                      setState(() {
                        isSaving = true;
                        message = null;
                      });

                      try {
                        await store.createTeacher(
                          name: nameController.text,
                          phone: phoneController.text,
                          password: passwordController.text,
                          classId: classId!,
                          courseId: courseId!,
                          subject: subject!,
                        );
                        if (!mounted) {
                          return;
                        }
                        nameController.clear();
                        phoneController.clear();
                        setState(
                          () => message = 'تم إنشاء حساب الأستاذ بنجاح.',
                        );
                      } on Object catch (error) {
                        if (!mounted) {
                          return;
                        }
                        setState(
                          () => message =
                              'فشل إنشاء الأستاذ: ${friendlyApiError(error)}',
                        );
                      } finally {
                        if (mounted) {
                          setState(() => isSaving = false);
                        }
                      }
                    },
              icon: const Icon(Icons.add_rounded),
              label: Text(isSaving ? 'جار الإضافة...' : 'إضافة الأستاذ'),
            ),
          ),
        ],
      ),
    );
  }
}

class CreateCourseForm extends StatefulWidget {
  const CreateCourseForm({super.key});

  @override
  State<CreateCourseForm> createState() => _CreateCourseFormState();
}

class _CreateCourseFormState extends State<CreateCourseForm> {
  final titleController = TextEditingController();
  final priceController = TextEditingController();
  final renewalMonthsController = TextEditingController(text: '1');
  final subjectNameControllers = <TextEditingController>[];
  final subjectPriceControllers = <TextEditingController>[];
  int step = 0;
  int subjectCount = 3;
  String? error;

  static const maxSubjects = 17;

  @override
  void initState() {
    super.initState();
    syncSubjectControllers();
  }

  @override
  void dispose() {
    titleController.dispose();
    priceController.dispose();
    renewalMonthsController.dispose();
    for (final controller in subjectNameControllers) {
      controller.dispose();
    }
    for (final controller in subjectPriceControllers) {
      controller.dispose();
    }
    super.dispose();
  }

  void syncSubjectControllers() {
    while (subjectNameControllers.length < subjectCount) {
      subjectNameControllers.add(TextEditingController());
      subjectPriceControllers.add(TextEditingController());
    }
    while (subjectNameControllers.length > subjectCount) {
      subjectNameControllers.removeLast().dispose();
      subjectPriceControllers.removeLast().dispose();
    }
  }

  void setSubjectCount(int value) {
    setState(() {
      subjectCount = value.clamp(1, maxSubjects);
      syncSubjectControllers();
      error = null;
    });
  }

  bool validateCurrentStep() {
    if (step == 0 && titleController.text.trim().isEmpty) {
      setState(() => error = 'اكتب اسم الدورة أو القسم أولا.');
      return false;
    }
    if (step == 2) {
      final missing = subjectNameControllers.any(
        (controller) => controller.text.trim().isEmpty,
      );
      if (missing) {
        setState(() => error = 'اكتب اسم كل مادة قبل الانتقال للأسعار.');
        return false;
      }
    }
    setState(() => error = null);
    return true;
  }

  void goNext() {
    if (!validateCurrentStep()) {
      return;
    }
    setState(() => step = min(step + 1, 3));
  }

  void goBack() {
    setState(() {
      step = max(step - 1, 0);
      error = null;
    });
  }

  void createCourse(SchoolStore store) {
    if (!validateCurrentStep()) {
      return;
    }
    final subjects = <Map<String, String>>[
      for (var index = 0; index < subjectCount; index++)
        {
          'name': subjectNameControllers[index].text.trim(),
          'price': subjectPriceControllers[index].text.trim(),
        },
    ];
    if (subjects.any((subject) => subject['name']!.isEmpty)) {
      setState(() => error = 'تأكد من كتابة كل أسماء المواد.');
      return;
    }
    final renewalMonths = int.tryParse(renewalMonthsController.text.trim());
    if (renewalMonths == null || renewalMonths < 1) {
      setState(() => error = 'اكتب مدة تجديد صحيحة بالأشهر.');
      return;
    }

    store.createCourse(
      title: titleController.text,
      classId: store.defaultClassId,
      description: 'دروس وتمارين وملخصات منظمة للطلاب',
      price: priceController.text,
      renewalMonths: renewalMonths,
      subjects: subjects,
    );
    titleController.clear();
    priceController.clear();
    renewalMonthsController.text = '1';
    for (final controller in subjectNameControllers) {
      controller.clear();
    }
    for (final controller in subjectPriceControllers) {
      controller.clear();
    }
    setState(() {
      step = 0;
      subjectCount = 3;
      syncSubjectControllers();
      error = null;
    });
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('تمت إضافة القسم')));
  }

  @override
  Widget build(BuildContext context) {
    final store = StoreScope.of(context);

    return SectionCard(
      title: 'إنشاء قسم',
      icon: Icons.add_circle_outline_rounded,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          CourseCreationStepper(currentStep: step),
          const SizedBox(height: 14),
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 260),
            switchInCurve: Curves.easeOutCubic,
            switchOutCurve: Curves.easeInCubic,
            transitionBuilder: (child, animation) {
              return FadeTransition(
                opacity: animation,
                child: SlideTransition(
                  position: Tween<Offset>(
                    begin: const Offset(0.05, 0),
                    end: Offset.zero,
                  ).animate(animation),
                  child: child,
                ),
              );
            },
            child: switch (step) {
              0 => CourseNameStep(
                key: const ValueKey('course-name'),
                titleController: titleController,
              ),
              1 => SubjectCountStep(
                key: const ValueKey('subject-count'),
                count: subjectCount,
                maxSubjects: maxSubjects,
                onChanged: setSubjectCount,
              ),
              2 => SubjectNamesStep(
                key: const ValueKey('subject-names'),
                controllers: subjectNameControllers,
              ),
              _ => SubjectPricesStep(
                key: const ValueKey('subject-prices'),
                coursePriceController: priceController,
                renewalMonthsController: renewalMonthsController,
                subjectNameControllers: subjectNameControllers,
                subjectPriceControllers: subjectPriceControllers,
              ),
            },
          ),
          if (error != null) ...[
            const SizedBox(height: 10),
            Text(error!, style: TextStyle(color: Colors.red.shade700)),
          ],
          const SizedBox(height: 16),
          Row(
            children: [
              if (step > 0)
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: goBack,
                    icon: const Icon(Icons.arrow_forward_rounded),
                    label: const Text('رجوع'),
                  ),
                ),
              if (step > 0) const SizedBox(width: 10),
              Expanded(
                flex: 2,
                child: FilledButton.icon(
                  onPressed: step == 3 ? () => createCourse(store) : goNext,
                  icon: Icon(
                    step == 3 ? Icons.add_rounded : Icons.arrow_back_rounded,
                  ),
                  label: Text(step == 3 ? 'إضافة القسم' : 'التالي'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class CourseCreationStepper extends StatelessWidget {
  const CourseCreationStepper({required this.currentStep, super.key});

  final int currentStep;

  @override
  Widget build(BuildContext context) {
    final labels = ['الاسم', 'العدد', 'المواد', 'الأسعار'];
    return Row(
      children: [
        for (var index = 0; index < labels.length; index++) ...[
          Expanded(
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 220),
              padding: const EdgeInsets.symmetric(vertical: 9),
              decoration: BoxDecoration(
                color: index <= currentStep
                    ? epsilonBlue.withValues(alpha: 0.10)
                    : const Color(0xFFF4F7FC),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: index == currentStep ? epsilonBlue : epsilonLine,
                ),
              ),
              child: Text(
                labels[index],
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: index <= currentStep ? epsilonBlue : epsilonMuted,
                  fontSize: 12,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
          ),
          if (index != labels.length - 1) const SizedBox(width: 7),
        ],
      ],
    );
  }
}

class CourseNameStep extends StatelessWidget {
  const CourseNameStep({required this.titleController, super.key});

  final TextEditingController titleController;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const StepIntro(
          icon: Icons.school_rounded,
          title: 'اسم الدورة أو القسم',
          subtitle: 'مثال: البكالوريا، الروابع، التحضير للمسابقات',
        ),
        const SizedBox(height: 12),
        TextField(
          controller: titleController,
          textInputAction: TextInputAction.next,
          decoration: const InputDecoration(
            labelText: 'اسم الدورة أو القسم',
            prefixIcon: Icon(Icons.drive_file_rename_outline_rounded),
          ),
        ),
      ],
    );
  }
}

class SubjectCountStep extends StatelessWidget {
  const SubjectCountStep({
    required this.count,
    required this.maxSubjects,
    required this.onChanged,
    super.key,
  });

  final int count;
  final int maxSubjects;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const StepIntro(
          icon: Icons.format_list_numbered_rounded,
          title: 'كم مادة في هذا القسم؟',
          subtitle: 'يمكنك اختيار عدد المواد حتى 17 مادة.',
        ),
        const SizedBox(height: 14),
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: const Color(0xFFF8FAFF),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: epsilonLine),
          ),
          child: Row(
            children: [
              IconButton.filled(
                onPressed: count <= 1 ? null : () => onChanged(count - 1),
                icon: const Icon(Icons.remove_rounded),
              ),
              Expanded(
                child: Column(
                  children: [
                    AnimatedSwitcher(
                      duration: const Duration(milliseconds: 180),
                      child: Text(
                        '$count',
                        key: ValueKey(count),
                        style: const TextStyle(
                          color: epsilonBlue,
                          fontSize: 34,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
                    const Text(
                      'مادة',
                      style: TextStyle(
                        color: epsilonMuted,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                ),
              ),
              IconButton.filled(
                onPressed: count >= maxSubjects
                    ? null
                    : () => onChanged(count + 1),
                icon: const Icon(Icons.add_rounded),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        Slider(
          value: count.toDouble(),
          min: 1,
          max: maxSubjects.toDouble(),
          divisions: maxSubjects - 1,
          label: '$count',
          onChanged: (value) => onChanged(value.round()),
        ),
      ],
    );
  }
}

class SubjectNamesStep extends StatelessWidget {
  const SubjectNamesStep({required this.controllers, super.key});

  final List<TextEditingController> controllers;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const StepIntro(
          icon: Icons.subject_rounded,
          title: 'أسماء المواد',
          subtitle: 'اكتب كل مادة في خانة مستقلة حتى تظهر للطلاب بشكل مرتب.',
        ),
        const SizedBox(height: 12),
        for (var index = 0; index < controllers.length; index++) ...[
          TextField(
            controller: controllers[index],
            textInputAction: index == controllers.length - 1
                ? TextInputAction.done
                : TextInputAction.next,
            decoration: InputDecoration(
              labelText: 'اسم المادة ${index + 1}',
              prefixIcon: const Icon(Icons.menu_book_rounded),
            ),
          ),
          if (index != controllers.length - 1) const SizedBox(height: 10),
        ],
      ],
    );
  }
}

class SubjectPricesStep extends StatelessWidget {
  const SubjectPricesStep({
    required this.coursePriceController,
    required this.renewalMonthsController,
    required this.subjectNameControllers,
    required this.subjectPriceControllers,
    super.key,
  });

  final TextEditingController coursePriceController;
  final TextEditingController renewalMonthsController;
  final List<TextEditingController> subjectNameControllers;
  final List<TextEditingController> subjectPriceControllers;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const StepIntro(
          icon: Icons.sell_rounded,
          title: 'الأسعار',
          subtitle: 'أضف السعر ومدة التجديد، ثم سعر كل مادة وحدها.',
        ),
        const SizedBox(height: 12),
        TextField(
          controller: coursePriceController,
          keyboardType: TextInputType.text,
          decoration: const InputDecoration(
            labelText: 'سعر الدورة أو القسم كاملا',
            hintText: 'مثال: 5000',
            prefixIcon: Icon(Icons.local_offer_rounded),
          ),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: renewalMonthsController,
          keyboardType: TextInputType.number,
          decoration: const InputDecoration(
            labelText: 'مدة التجديد بالأشهر',
            hintText: 'مثال: 1 للاشتراك الشهري، 12 للسنوي',
            prefixIcon: Icon(Icons.event_repeat_rounded),
          ),
        ),
        const SizedBox(height: 12),
        for (
          var index = 0;
          index < subjectPriceControllers.length;
          index++
        ) ...[
          TextField(
            controller: subjectPriceControllers[index],
            keyboardType: TextInputType.text,
            decoration: InputDecoration(
              labelText:
                  'سعر ${subjectNameControllers[index].text.trim().isEmpty ? 'المادة ${index + 1}' : subjectNameControllers[index].text.trim()}',
              hintText: 'مثال: 1500',
              prefixIcon: const Icon(Icons.payments_rounded),
            ),
          ),
          if (index != subjectPriceControllers.length - 1)
            const SizedBox(height: 10),
        ],
      ],
    );
  }
}

class StepIntro extends StatelessWidget {
  const StepIntro({
    required this.icon,
    required this.title,
    required this.subtitle,
    super.key,
  });

  final IconData icon;
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(13),
      decoration: BoxDecoration(
        color: epsilonBlue.withValues(alpha: 0.07),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: epsilonBlue.withValues(alpha: 0.12)),
      ),
      child: Row(
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: epsilonBlue.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(icon, color: epsilonBlue),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    color: epsilonInk,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  subtitle,
                  style: const TextStyle(
                    color: epsilonMuted,
                    fontSize: 12,
                    height: 1.35,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class PaymentNumberForm extends StatefulWidget {
  const PaymentNumberForm({super.key});

  @override
  State<PaymentNumberForm> createState() => _PaymentNumberFormState();
}

class _PaymentNumberFormState extends State<PaymentNumberForm> {
  final numberController = TextEditingController();
  final amountController = TextEditingController();
  final methodNameController = TextEditingController();
  final methodNumberController = TextEditingController();
  final methodImageController = TextEditingController();
  bool initialized = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!initialized) {
      numberController.text = StoreScope.of(context).paymentNumber;
      amountController.text = StoreScope.of(context).paymentAmount;
      initialized = true;
    }
  }

  @override
  void dispose() {
    numberController.dispose();
    amountController.dispose();
    methodNameController.dispose();
    methodNumberController.dispose();
    methodImageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final store = StoreScope.of(context);

    return SectionCard(
      title: 'إعدادات الدفع',
      icon: Icons.payments_rounded,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TextField(
            controller: amountController,
            keyboardType: TextInputType.text,
            decoration: const InputDecoration(
              labelText: 'سعر افتراضي عند عدم تحديد سعر القسم',
              prefixIcon: Icon(Icons.sell_rounded),
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: numberController,
            keyboardType: TextInputType.phone,
            decoration: const InputDecoration(
              labelText: 'رقم الدفع الذي يظهر للطلاب',
              prefixIcon: Icon(Icons.phone_android_rounded),
            ),
          ),
          const SizedBox(height: 12),
          Align(
            alignment: Alignment.centerLeft,
            child: FilledButton.icon(
              onPressed: () {
                store.updatePaymentAmount(amountController.text);
                store.updatePaymentNumber(numberController.text);
              },
              icon: const Icon(Icons.save_rounded),
              label: const Text('حفظ إعدادات الدفع'),
            ),
          ),
          const SizedBox(height: 18),
          const Divider(),
          const SizedBox(height: 8),
          Text(
            'طرق الدفع المتوفرة',
            style: Theme.of(
              context,
            ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: methodNameController,
            decoration: const InputDecoration(
              labelText: 'اسم الطريقة',
              hintText: 'مثال: بنكيلي أو مصرفي',
              prefixIcon: Icon(Icons.account_balance_wallet_rounded),
            ),
          ),
          const SizedBox(height: 10),
          TextField(
            controller: methodNumberController,
            keyboardType: TextInputType.phone,
            decoration: const InputDecoration(
              labelText: 'رقم الحساب أو الهاتف',
              prefixIcon: Icon(Icons.numbers_rounded),
            ),
          ),
          const SizedBox(height: 10),
          TextField(
            controller: methodImageController,
            keyboardType: TextInputType.url,
            decoration: const InputDecoration(
              labelText: 'رابط صورة الشعار',
              hintText: 'اختياري',
              prefixIcon: Icon(Icons.image_outlined),
            ),
          ),
          const SizedBox(height: 12),
          Align(
            alignment: Alignment.centerLeft,
            child: OutlinedButton.icon(
              onPressed: () {
                store.createPaymentMethod(
                  name: methodNameController.text,
                  accountNumber: methodNumberController.text,
                  imageUrl: methodImageController.text,
                );
                methodNameController.clear();
                methodNumberController.clear();
                methodImageController.clear();
              },
              icon: const Icon(Icons.add_rounded),
              label: const Text('إضافة طريقة دفع'),
            ),
          ),
          const SizedBox(height: 12),
          if (store.paymentMethods.isEmpty)
            const EmptyState(text: 'لم تتم إضافة طرق دفع بعد.')
          else
            for (final method in store.paymentMethods) ...[
              Container(
                margin: const EdgeInsets.only(bottom: 8),
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: const Color(0xFFF8FAFF),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: const Color(0xFFE1E8F8)),
                ),
                child: Row(
                  children: [
                    PaymentMethodLogo(method: method, size: 40),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            method.name,
                            style: const TextStyle(
                              color: epsilonInk,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                          Text(
                            method.accountNumber,
                            style: const TextStyle(
                              color: epsilonMuted,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      tooltip: 'حذف',
                      onPressed: () => store.deletePaymentMethod(method),
                      icon: const Icon(Icons.delete_outline_rounded),
                    ),
                  ],
                ),
              ),
            ],
        ],
      ),
    );
  }
}

class CreateClassForm extends StatefulWidget {
  const CreateClassForm({super.key});

  @override
  State<CreateClassForm> createState() => _CreateClassFormState();
}

class _CreateClassFormState extends State<CreateClassForm> {
  final nameController = TextEditingController();
  final levelController = TextEditingController();

  @override
  void dispose() {
    nameController.dispose();
    levelController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final store = StoreScope.of(context);

    return SectionCard(
      title: 'إنشاء قسم',
      icon: Icons.add_business_rounded,
      child: Column(
        children: [
          TextField(
            controller: nameController,
            decoration: const InputDecoration(labelText: 'اسم القسم'),
          ),
          const SizedBox(height: 10),
          TextField(
            controller: levelController,
            decoration: const InputDecoration(labelText: 'المستوى'),
          ),
          const SizedBox(height: 12),
          Align(
            alignment: Alignment.centerLeft,
            child: FilledButton.icon(
              onPressed: () {
                if (nameController.text.trim().isEmpty ||
                    levelController.text.trim().isEmpty) {
                  return;
                }

                store.createClass(
                  name: nameController.text,
                  level: levelController.text,
                );
                nameController.clear();
                levelController.clear();
              },
              icon: const Icon(Icons.add_rounded),
              label: const Text('إضافة القسم'),
            ),
          ),
        ],
      ),
    );
  }
}

class CreateLessonForm extends StatefulWidget {
  const CreateLessonForm({super.key});

  @override
  State<CreateLessonForm> createState() => _CreateLessonFormState();
}

class _CreateLessonFormState extends State<CreateLessonForm> {
  final titleController = TextEditingController();
  final urlController = TextEditingController();
  String? courseId;

  @override
  void dispose() {
    titleController.dispose();
    urlController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final store = StoreScope.of(context);
    final teacher = store.currentUser!;
    final availableCourses = store.courses
        .where(
          (course) =>
              course.id == teacher.courseId &&
              course.subjects.contains(teacher.subject),
        )
        .toList();

    if (availableCourses.isEmpty) {
      return const SectionCard(
        title: 'إضافة درس',
        icon: Icons.add_link_rounded,
        child: EmptyState(text: 'لا يوجد قسم يحتوي على مادتك حاليا.'),
      );
    }

    courseId ??= availableCourses.first.id;

    return SectionCard(
      title: 'إضافة رابط درس',
      icon: Icons.add_link_rounded,
      child: Column(
        children: [
          TextField(
            controller: titleController,
            decoration: const InputDecoration(labelText: 'عنوان الدرس'),
          ),
          const SizedBox(height: 10),
          TextField(
            controller: urlController,
            keyboardType: TextInputType.url,
            decoration: const InputDecoration(
              labelText: 'رابط فيديو Google Drive',
              hintText: 'ضع رابط المشاركة من Google Drive',
            ),
          ),
          const SizedBox(height: 10),
          DropdownButtonFormField<String>(
            initialValue: courseId,
            decoration: const InputDecoration(labelText: 'القسم'),
            items: availableCourses
                .map(
                  (course) => DropdownMenuItem(
                    value: course.id,
                    child: Text(course.title),
                  ),
                )
                .toList(),
            onChanged: (value) => setState(() => courseId = value),
          ),
          const SizedBox(height: 12),
          Align(
            alignment: Alignment.centerLeft,
            child: FilledButton.icon(
              onPressed: () {
                if (titleController.text.trim().isEmpty ||
                    urlController.text.trim().isEmpty ||
                    teacher.classId == null ||
                    courseId == null) {
                  return;
                }

                store.createLesson(
                  title: titleController.text,
                  url: urlController.text,
                  classId: teacher.classId!,
                  courseId: courseId!,
                );
                titleController.clear();
                urlController.clear();
              },
              icon: const Icon(Icons.publish_rounded),
              label: const Text('نشر الدرس'),
            ),
          ),
        ],
      ),
    );
  }
}

class EpsilonAppBar extends StatelessWidget implements PreferredSizeWidget {
  const EpsilonAppBar({required this.title, this.showLogout = true, super.key});

  final String title;
  final bool showLogout;

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);

  @override
  Widget build(BuildContext context) {
    final canGoBack = Navigator.of(context).canPop();
    final store = StoreScope.of(context);
    final unreadCount = store.unreadNotificationCount;

    return AppBar(
      backgroundColor: Colors.transparent,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      flexibleSpace: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: AlignmentDirectional.topStart,
            end: AlignmentDirectional.bottomEnd,
            colors: [
              Colors.white.withValues(alpha: .96),
              epsilonSoft.withValues(alpha: .88),
            ],
          ),
          border: const Border(bottom: BorderSide(color: epsilonLine)),
        ),
      ),
      leading: canGoBack
          ? IconButton(
              tooltip: 'رجوع',
              onPressed: () => Navigator.of(context).maybePop(),
              icon: const Icon(Icons.arrow_back_rounded),
            )
          : showLogout
          ? IconButton(
              tooltip: 'الإعدادات',
              onPressed: () => Navigator.of(
                context,
              ).push(MaterialPageRoute(builder: (_) => const SettingsPage())),
              icon: const Icon(Icons.settings_rounded),
            )
          : null,
      title: Text(title),
      actions: showLogout
          ? [
              IconButton(
                tooltip: 'الإشعارات',
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const NotificationsPage()),
                ),
                icon: NotificationBellIcon(unreadCount: unreadCount),
              ),
              IconButton(
                tooltip: 'خروج',
                onPressed: () => store.logout(),
                icon: const Icon(Icons.logout_rounded),
              ),
            ]
          : null,
    );
  }
}

class NotificationBellIcon extends StatelessWidget {
  const NotificationBellIcon({required this.unreadCount, super.key});

  final int unreadCount;

  @override
  Widget build(BuildContext context) {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        const Icon(Icons.notifications_rounded),
        if (unreadCount > 0)
          Positioned(
            right: -5,
            top: -6,
            child: Container(
              constraints: const BoxConstraints(minWidth: 17, minHeight: 17),
              padding: const EdgeInsets.symmetric(horizontal: 4),
              decoration: BoxDecoration(
                color: const Color(0xFFEF4444),
                borderRadius: BorderRadius.circular(999),
                border: Border.all(color: Colors.white, width: 1.5),
              ),
              alignment: Alignment.center,
              child: Text(
                unreadCount > 9 ? '9+' : unreadCount.toString(),
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 10,
                  fontWeight: FontWeight.w900,
                  height: 1,
                ),
              ),
            ),
          ),
      ],
    );
  }
}

class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  final currentPasswordController = TextEditingController();
  final newPasswordController = TextEditingController();
  final confirmPasswordController = TextEditingController();
  String? message;
  bool success = false;

  @override
  void dispose() {
    currentPasswordController.dispose();
    newPasswordController.dispose();
    confirmPasswordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final store = StoreScope.of(context);
    final user = store.currentUser;

    return Scaffold(
      backgroundColor: const Color(0xFFF7F9FF),
      appBar: const EpsilonAppBar(title: 'الإعدادات', showLogout: false),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
        children: [
          HeaderPanel(
            title: user?.name ?? 'الحساب',
            subtitle: user == null
                ? 'إعدادات الحساب'
                : '${roleLabel(user.role)} - ${statusLabel(user.status)}',
            icon: Icons.settings_rounded,
          ),
          const SizedBox(height: 16),
          SectionCard(
            title: 'معلومات الحساب',
            icon: Icons.account_circle_rounded,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                InfoRow(label: 'الاسم', value: user?.name ?? '-'),
                InfoRow(label: 'رقم الهاتف', value: user?.phone ?? '-'),
                InfoRow(label: 'الدور', value: roleLabel(user?.role)),
              ],
            ),
          ),
          const SizedBox(height: 16),
          SectionCard(
            title: 'تغيير كلمة المرور',
            icon: Icons.lock_reset_rounded,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                TextField(
                  controller: currentPasswordController,
                  obscureText: true,
                  decoration: const InputDecoration(
                    labelText: 'كلمة المرور الحالية',
                    prefixIcon: Icon(Icons.lock_outline_rounded),
                  ),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: newPasswordController,
                  obscureText: true,
                  decoration: const InputDecoration(
                    labelText: 'كلمة المرور الجديدة',
                    prefixIcon: Icon(Icons.password_rounded),
                  ),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: confirmPasswordController,
                  obscureText: true,
                  decoration: const InputDecoration(
                    labelText: 'تأكيد كلمة المرور',
                    prefixIcon: Icon(Icons.verified_user_outlined),
                  ),
                ),
                if (message != null) ...[
                  const SizedBox(height: 10),
                  Text(
                    message!,
                    style: TextStyle(
                      color: success
                          ? Colors.green.shade700
                          : Colors.red.shade700,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
                const SizedBox(height: 14),
                FilledButton.icon(
                  onPressed: () async {
                    if (newPasswordController.text !=
                        confirmPasswordController.text) {
                      setState(() {
                        success = false;
                        message = 'كلمة المرور الجديدة غير متطابقة.';
                      });
                      return;
                    }

                    final changed = await store.changeCurrentPassword(
                      currentPassword: currentPasswordController.text,
                      newPassword: newPasswordController.text,
                    );
                    if (!mounted) {
                      return;
                    }

                    setState(() {
                      success = changed;
                      message = changed
                          ? 'تم تغيير كلمة المرور بنجاح.'
                          : 'تأكد من كلمة المرور الحالية وأن الجديدة 6 أحرف على الأقل.';
                    });

                    if (changed) {
                      currentPasswordController.clear();
                      newPasswordController.clear();
                      confirmPasswordController.clear();
                    }
                  },
                  icon: const Icon(Icons.save_rounded),
                  label: const Text('حفظ كلمة المرور'),
                ),
              ],
            ),
          ),
          SectionCard(
            title: 'اللغة',
            icon: Icons.language_rounded,
            child: LanguageSettings(languageCode: store.languageCode),
          ),
        ],
      ),
    );
  }
}

class NotificationsPage extends StatefulWidget {
  const NotificationsPage({super.key});

  @override
  State<NotificationsPage> createState() => _NotificationsPageState();
}

class _NotificationsPageState extends State<NotificationsPage> {
  final titleController = TextEditingController();
  final bodyController = TextEditingController();
  bool isPublishing = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        return;
      }
      unawaited(StoreScope.of(context).markNotificationsRead());
    });
  }

  @override
  void dispose() {
    titleController.dispose();
    bodyController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final store = StoreScope.of(context);
    final canPublish = store.currentUser?.role == UserRole.admin;

    return Scaffold(
      backgroundColor: const Color(0xFFF7F9FF),
      appBar: const EpsilonAppBar(title: 'الإشعارات', showLogout: false),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
        children: [
          HeaderPanel(
            title: 'الإشعارات',
            subtitle: canPublish
                ? 'اكتب إشعارا ليظهر لجميع المستخدمين'
                : 'آخر الرسائل والتنبيهات من الإدارة',
            icon: Icons.notifications_active_rounded,
          ),
          const SizedBox(height: 16),
          if (canPublish) ...[
            SectionCard(
              title: 'نشر إشعار',
              icon: Icons.campaign_rounded,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  TextField(
                    controller: titleController,
                    textAlign: TextAlign.right,
                    textDirection: TextDirection.rtl,
                    decoration: const InputDecoration(
                      labelText: 'عنوان الإشعار',
                    ),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: bodyController,
                    textAlign: TextAlign.right,
                    textDirection: TextDirection.rtl,
                    minLines: 2,
                    maxLines: 3,
                    decoration: const InputDecoration(labelText: 'نص الإشعار'),
                  ),
                  const SizedBox(height: 12),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: FilledButton.icon(
                      onPressed: isPublishing
                          ? null
                          : () async {
                              if (titleController.text.trim().isEmpty ||
                                  bodyController.text.trim().isEmpty) {
                                return;
                              }

                              setState(() => isPublishing = true);
                              try {
                                await store.addNotification(
                                  title: titleController.text,
                                  body: bodyController.text,
                                );
                                titleController.clear();
                                bodyController.clear();
                                if (!context.mounted) {
                                  return;
                                }
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text('تم نشر الإشعار للجميع'),
                                  ),
                                );
                              } catch (_) {
                                if (!context.mounted) {
                                  return;
                                }
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text(
                                      store.lastError ??
                                          'تعذر نشر الإشعار. تحقق من صلاحية الأدمن.',
                                    ),
                                  ),
                                );
                              } finally {
                                if (mounted) {
                                  setState(() => isPublishing = false);
                                }
                              }
                            },
                      icon: isPublishing
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.send_rounded),
                      label: Text(
                        isPublishing ? 'جاري النشر...' : 'نشر للجميع',
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
          ],
          SectionCard(
            title: 'كل الإشعارات',
            icon: Icons.notifications_none_rounded,
            child: store.notifications.isEmpty
                ? const EmptyState(text: 'لا توجد إشعارات حاليا.')
                : Column(
                    children: store.notifications
                        .map(
                          (item) => NotificationTile(
                            notification: item,
                            canManage: canPublish,
                          ),
                        )
                        .toList(),
                  ),
          ),
        ],
      ),
    );
  }
}

class NotificationTile extends StatelessWidget {
  const NotificationTile({
    required this.notification,
    required this.canManage,
    super.key,
  });

  final AppNotification notification;
  final bool canManage;

  @override
  Widget build(BuildContext context) {
    final store = StoreScope.of(context);

    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: const CircleAvatar(
        backgroundColor: Color(0xFFEAF1FF),
        child: Icon(
          Icons.notifications_active_rounded,
          color: Color(0xFF2F5BEA),
        ),
      ),
      title: Text(notification.title),
      subtitle: Text(notification.body),
      trailing: canManage
          ? Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  tooltip: 'تعديل',
                  onPressed: () => showDialog<void>(
                    context: context,
                    builder: (_) =>
                        EditNotificationDialog(notification: notification),
                  ),
                  icon: const Icon(Icons.edit_rounded),
                ),
                IconButton(
                  tooltip: 'حذف',
                  onPressed: () async {
                    final confirm = await showDialog<bool>(
                      context: context,
                      builder: (_) =>
                          DeleteNotificationDialog(notification: notification),
                    );
                    if (confirm != true || !context.mounted) {
                      return;
                    }

                    try {
                      await store.deleteNotification(notification);
                      if (!context.mounted) {
                        return;
                      }
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('تم حذف الإشعار')),
                      );
                    } catch (_) {
                      if (!context.mounted) {
                        return;
                      }
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(store.lastError ?? 'تعذر حذف الإشعار.'),
                        ),
                      );
                    }
                  },
                  icon: const Icon(Icons.delete_outline_rounded),
                ),
              ],
            )
          : null,
    );
  }
}

class EditNotificationDialog extends StatefulWidget {
  const EditNotificationDialog({required this.notification, super.key});

  final AppNotification notification;

  @override
  State<EditNotificationDialog> createState() => _EditNotificationDialogState();
}

class _EditNotificationDialogState extends State<EditNotificationDialog> {
  late final TextEditingController titleController;
  late final TextEditingController bodyController;
  bool isSaving = false;

  @override
  void initState() {
    super.initState();
    titleController = TextEditingController(text: widget.notification.title);
    bodyController = TextEditingController(text: widget.notification.body);
  }

  @override
  void dispose() {
    titleController.dispose();
    bodyController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final store = StoreScope.of(context);

    return AlertDialog(
      title: const Text('تعديل الإشعار'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: titleController,
              textAlign: TextAlign.right,
              textDirection: TextDirection.rtl,
              decoration: const InputDecoration(labelText: 'عنوان الإشعار'),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: bodyController,
              textAlign: TextAlign.right,
              textDirection: TextDirection.rtl,
              minLines: 2,
              maxLines: 4,
              decoration: const InputDecoration(labelText: 'نص الإشعار'),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: isSaving ? null : () => Navigator.of(context).pop(),
          child: const Text('إلغاء'),
        ),
        FilledButton(
          onPressed: isSaving
              ? null
              : () async {
                  if (titleController.text.trim().isEmpty ||
                      bodyController.text.trim().isEmpty) {
                    return;
                  }

                  setState(() => isSaving = true);
                  try {
                    await store.updateNotification(
                      notification: widget.notification,
                      title: titleController.text,
                      body: bodyController.text,
                    );
                    if (!context.mounted) {
                      return;
                    }
                    Navigator.of(context).pop();
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('تم تعديل الإشعار')),
                    );
                  } catch (_) {
                    if (!context.mounted) {
                      return;
                    }
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(store.lastError ?? 'تعذر تعديل الإشعار.'),
                      ),
                    );
                  } finally {
                    if (mounted) {
                      setState(() => isSaving = false);
                    }
                  }
                },
          child: Text(isSaving ? 'جار الحفظ...' : 'حفظ'),
        ),
      ],
    );
  }
}

class DeleteNotificationDialog extends StatelessWidget {
  const DeleteNotificationDialog({required this.notification, super.key});

  final AppNotification notification;

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('حذف الإشعار'),
      content: Text('هل تريد حذف "${notification.title}"؟'),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: const Text('إلغاء'),
        ),
        FilledButton(
          onPressed: () => Navigator.of(context).pop(true),
          child: const Text('حذف'),
        ),
      ],
    );
  }
}

class LanguageSettings extends StatelessWidget {
  const LanguageSettings({required this.languageCode, super.key});

  final String languageCode;

  @override
  Widget build(BuildContext context) {
    final store = StoreScope.of(context);

    return SegmentedButton<String>(
      segments: const [
        ButtonSegment(value: 'ar', label: Text('العربية')),
        ButtonSegment(value: 'fr', label: Text('Français')),
      ],
      selected: {languageCode},
      onSelectionChanged: (values) => store.setLanguageCode(values.first),
    );
  }
}

class SectionCard extends StatelessWidget {
  const SectionCard({
    required this.title,
    required this.icon,
    required this.child,
    super.key,
  });

  final String title;
  final IconData icon;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: epsilonSurface.withValues(alpha: .96),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: epsilonLine),
        boxShadow: [
          BoxShadow(
            color: epsilonInk.withValues(alpha: 0.06),
            blurRadius: 24,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(17),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: AlignmentDirectional.topStart,
                      end: AlignmentDirectional.bottomEnd,
                      colors: [
                        epsilonBlue.withValues(alpha: 0.13),
                        epsilonTeal.withValues(alpha: 0.10),
                      ],
                    ),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(icon, color: epsilonBlue, size: 20),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    title,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                      color: epsilonInk,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            child,
          ],
        ),
      ),
    );
  }
}

class HeaderPanel extends StatelessWidget {
  const HeaderPanel({
    required this.title,
    required this.subtitle,
    required this.icon,
    this.logoAsset,
    super.key,
  });

  final String title;
  final String subtitle;
  final IconData icon;
  final String? logoAsset;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: AlignmentDirectional.topStart,
          end: AlignmentDirectional.bottomEnd,
          colors: [epsilonBlue, Color(0xFF173DAD), epsilonTeal],
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: epsilonBlue.withValues(alpha: 0.22),
            blurRadius: 26,
            offset: const Offset(0, 14),
          ),
        ],
      ),
      child: Row(
        children: [
          if (logoAsset == null)
            Icon(icon, color: Colors.white, size: 44)
          else
            Container(
              width: 58,
              height: 58,
              padding: const EdgeInsets.all(5),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(18),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.10),
                    blurRadius: 18,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(14),
                child: Image.asset(logoAsset!, fit: BoxFit.cover),
              ),
            ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  subtitle,
                  style: const TextStyle(color: Color(0xFFE8EEFF)),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class UserTile extends StatelessWidget {
  const UserTile({
    required this.user,
    this.trailing,
    this.compact = false,
    super.key,
  });

  final AppUser user;
  final Widget? trailing;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final store = StoreScope.of(context);
    final course = store.courseById(user.courseId);

    return Container(
      margin: EdgeInsets.only(bottom: compact ? 0 : 10),
      padding: EdgeInsets.all(compact ? 0 : 12),
      decoration: compact
          ? null
          : BoxDecoration(
              color: const Color(0xFFFAFBFF),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: const Color(0xFFE8EEFF)),
            ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 23,
                backgroundColor: const Color(0xFF2F5BEA).withValues(alpha: 0.1),
                child: Icon(
                  user.role == UserRole.teacher
                      ? Icons.co_present_rounded
                      : Icons.person_rounded,
                  color: const Color(0xFF2F5BEA),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      user.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontWeight: FontWeight.w800),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      [
                        user.phone,
                        if (course != null) course.title,
                      ].join(' - '),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      softWrap: false,
                      style: const TextStyle(
                        color: Color(0xFF6B7280),
                        fontSize: 12,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: [
                        StatusBadge(status: user.status),
                        if (user.role == UserRole.admin)
                          AdminTypeBadge(type: user.adminType),
                      ],
                    ),
                    if (user.role == UserRole.student &&
                        user.subscriptionExpiresAt != null) ...[
                      const SizedBox(height: 5),
                      Text(
                        'ينتهي: ${formatArabicDate(user.subscriptionExpiresAt!)}',
                        style: TextStyle(
                          color: user.isSubscriptionExpired
                              ? Colors.red.shade700
                              : epsilonMuted,
                          fontSize: 12,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
          if (trailing != null) ...[
            const SizedBox(height: 12),
            Align(
              alignment: AlignmentDirectional.centerStart,
              child: trailing!,
            ),
          ],
        ],
      ),
    );
  }
}

class StatusBadge extends StatelessWidget {
  const StatusBadge({required this.status, super.key});

  final AccountStatus status;

  Color get color {
    return switch (status) {
      AccountStatus.pending => const Color(0xFFF59E0B),
      AccountStatus.active => const Color(0xFF10B981),
      AccountStatus.blocked => const Color(0xFF64748B),
      AccountStatus.rejected => const Color(0xFFEF4444),
    };
  }

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: AlignmentDirectional.centerStart,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(999),
        ),
        child: Text(
          statusLabel(status),
          style: TextStyle(
            color: color,
            fontSize: 11,
            fontWeight: FontWeight.w900,
          ),
        ),
      ),
    );
  }
}

class AdminTypeBadge extends StatelessWidget {
  const AdminTypeBadge({required this.type, super.key});

  final AdminType type;

  Color get color {
    return switch (type) {
      AdminType.developer => const Color(0xFF334155),
      AdminType.generalManager => const Color(0xFF2457E6),
      AdminType.schoolManager => const Color(0xFF0F766E),
    };
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        adminTypeLabel(type),
        style: TextStyle(
          color: color,
          fontSize: 11,
          fontWeight: FontWeight.w900,
        ),
      ),
    );
  }
}

class AccountActionButton extends StatelessWidget {
  const AccountActionButton({required this.user, super.key});

  final AppUser user;

  @override
  Widget build(BuildContext context) {
    final store = StoreScope.of(context);
    final blocked = user.status == AccountStatus.blocked;

    return Wrap(
      spacing: 8,
      runSpacing: 8,
      alignment: WrapAlignment.start,
      children: [
        if (user.role == UserRole.student &&
            user.status == AccountStatus.active)
          OutlinedButton.icon(
            onPressed: () => showDialog<void>(
              context: context,
              builder: (_) => RenewSubscriptionDialog(user: user),
            ),
            icon: const Icon(Icons.autorenew_rounded),
            label: const Text('تجديد الاشتراك'),
          ),
        OutlinedButton.icon(
          onPressed: () =>
              blocked ? store.activateUser(user) : store.blockUser(user),
          icon: Icon(
            blocked
                ? Icons.lock_open_rounded
                : Icons.pause_circle_outline_rounded,
          ),
          label: Text(blocked ? 'تفعيل' : 'تجميد'),
        ),
        OutlinedButton.icon(
          onPressed: () => showDialog<void>(
            context: context,
            builder: (_) => DeleteAccountDialog(user: user),
          ),
          icon: const Icon(Icons.delete_outline_rounded),
          label: const Text('حذف'),
        ),
      ],
    );
  }
}

class RenewSubscriptionDialog extends StatefulWidget {
  const RenewSubscriptionDialog({required this.user, super.key});

  final AppUser user;

  @override
  State<RenewSubscriptionDialog> createState() =>
      _RenewSubscriptionDialogState();
}

class _RenewSubscriptionDialogState extends State<RenewSubscriptionDialog> {
  final amountController = TextEditingController();
  bool isSaving = false;
  String? error;

  @override
  void dispose() {
    amountController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final store = StoreScope.of(context);

    return AlertDialog(
      title: const Text('تجديد الاشتراك'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('أدخل المبلغ الذي دفعه "${widget.user.name}" لتجديد اشتراكه.'),
          const SizedBox(height: 12),
          TextField(
            controller: amountController,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            autofocus: true,
            decoration: const InputDecoration(
              labelText: 'المبلغ',
              hintText: 'مثال: 3000',
              prefixIcon: Icon(Icons.payments_rounded),
            ),
          ),
          if (error != null) ...[
            const SizedBox(height: 10),
            Text(error!, style: TextStyle(color: Colors.red.shade700)),
          ],
        ],
      ),
      actions: [
        TextButton(
          onPressed: isSaving ? null : () => Navigator.of(context).pop(),
          child: const Text('إلغاء'),
        ),
        FilledButton(
          onPressed: isSaving
              ? null
              : () async {
                  final amount = amountController.text.trim();
                  if (amount.isEmpty || priceNumberFromText(amount) == null) {
                    setState(() => error = 'اكتب مبلغا صحيحا.');
                    return;
                  }
                  setState(() {
                    isSaving = true;
                    error = null;
                  });
                  await store.renewSubscription(
                    user: widget.user,
                    amount: amount,
                  );
                  if (context.mounted) {
                    Navigator.of(context).pop();
                  }
                },
          child: Text(isSaving ? 'جار الحفظ...' : 'تأكيد'),
        ),
      ],
    );
  }
}

class DeleteAccountDialog extends StatefulWidget {
  const DeleteAccountDialog({required this.user, super.key});

  final AppUser user;

  @override
  State<DeleteAccountDialog> createState() => _DeleteAccountDialogState();
}

class _DeleteAccountDialogState extends State<DeleteAccountDialog> {
  bool isDeleting = false;
  String? error;

  @override
  Widget build(BuildContext context) {
    final store = StoreScope.of(context);

    return AlertDialog(
      title: const Text('حذف الحساب'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('هل تريد حذف حساب "${widget.user.name}" نهائيا؟'),
          if (error != null) ...[
            const SizedBox(height: 10),
            Text(error!, style: TextStyle(color: Colors.red.shade700)),
          ],
        ],
      ),
      actions: [
        TextButton(
          onPressed: isDeleting ? null : () => Navigator.of(context).pop(),
          child: const Text('إلغاء'),
        ),
        FilledButton(
          onPressed: isDeleting
              ? null
              : () async {
                  setState(() {
                    isDeleting = true;
                    error = null;
                  });
                  try {
                    await store.deleteUser(widget.user);
                    if (context.mounted) {
                      Navigator.of(context).pop();
                    }
                  } on Object catch (exception) {
                    if (mounted) {
                      setState(() {
                        isDeleting = false;
                        error =
                            'تعذر حذف الحساب: ${friendlyApiError(exception)}';
                      });
                    }
                  }
                },
          child: Text(isDeleting ? 'جار الحذف...' : 'حذف'),
        ),
      ],
    );
  }
}

class TeacherLessonTile extends StatelessWidget {
  const TeacherLessonTile({required this.lesson, super.key});

  final Lesson lesson;

  @override
  Widget build(BuildContext context) {
    final store = StoreScope.of(context);
    final course = store.courseById(lesson.courseId);

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFFAFBFF),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE8EEFF)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              const CircleAvatar(
                backgroundColor: Color(0xFFEAF1FF),
                child: Icon(
                  Icons.play_circle_rounded,
                  color: Color(0xFF2F5BEA),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      lesson.title,
                      style: const TextStyle(fontWeight: FontWeight.w900),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${course?.title ?? 'قسم'} - ${lesson.subject}',
                      style: const TextStyle(
                        color: Color(0xFF6B7280),
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              FilledButton.icon(
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => SecureVideoPage(lesson: lesson),
                  ),
                ),
                icon: const Icon(Icons.play_arrow_rounded),
                label: const Text('تشغيل'),
              ),
              OutlinedButton.icon(
                onPressed: () => showDialog<void>(
                  context: context,
                  builder: (_) => EditLessonDialog(lesson: lesson),
                ),
                icon: const Icon(Icons.edit_rounded),
                label: const Text('تعديل'),
              ),
              OutlinedButton.icon(
                onPressed: () => showDialog<void>(
                  context: context,
                  builder: (_) => DeleteLessonDialog(lesson: lesson),
                ),
                icon: const Icon(Icons.delete_outline_rounded),
                label: const Text('حذف'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class EditLessonDialog extends StatefulWidget {
  const EditLessonDialog({required this.lesson, super.key});

  final Lesson lesson;

  @override
  State<EditLessonDialog> createState() => _EditLessonDialogState();
}

class _EditLessonDialogState extends State<EditLessonDialog> {
  late final TextEditingController titleController;
  late final TextEditingController urlController;
  String? courseId;

  @override
  void initState() {
    super.initState();
    titleController = TextEditingController(text: widget.lesson.title);
    urlController = TextEditingController(text: widget.lesson.url);
    courseId = widget.lesson.courseId;
  }

  @override
  void dispose() {
    titleController.dispose();
    urlController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final store = StoreScope.of(context);
    final teacher = store.currentUser!;
    final availableCourses = store.courses
        .where(
          (course) =>
              course.id == teacher.courseId &&
              course.subjects.contains(teacher.subject),
        )
        .toList();
    if (availableCourses.isNotEmpty &&
        !availableCourses.any((course) => course.id == courseId)) {
      courseId = availableCourses.first.id;
    }

    return AlertDialog(
      title: const Text('تعديل الدرس'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: titleController,
              decoration: const InputDecoration(labelText: 'عنوان الدرس'),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: urlController,
              keyboardType: TextInputType.url,
              decoration: const InputDecoration(labelText: 'رابط Google Drive'),
            ),
            const SizedBox(height: 10),
            DropdownButtonFormField<String>(
              initialValue: courseId,
              decoration: const InputDecoration(labelText: 'القسم'),
              items: availableCourses
                  .map(
                    (course) => DropdownMenuItem(
                      value: course.id,
                      child: Text(course.title),
                    ),
                  )
                  .toList(),
              onChanged: (value) => setState(() => courseId = value),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('إلغاء'),
        ),
        FilledButton(
          onPressed: () {
            if (titleController.text.trim().isEmpty ||
                urlController.text.trim().isEmpty ||
                courseId == null) {
              return;
            }

            store.updateLesson(
              lesson: widget.lesson,
              title: titleController.text,
              url: urlController.text,
              courseId: courseId!,
            );
            Navigator.of(context).pop();
          },
          child: const Text('حفظ'),
        ),
      ],
    );
  }
}

class DeleteLessonDialog extends StatelessWidget {
  const DeleteLessonDialog({required this.lesson, super.key});

  final Lesson lesson;

  @override
  Widget build(BuildContext context) {
    final store = StoreScope.of(context);

    return AlertDialog(
      title: const Text('حذف الدرس'),
      content: Text('هل تريد حذف "${lesson.title}"؟'),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('إلغاء'),
        ),
        FilledButton(
          onPressed: () {
            store.deleteLesson(lesson);
            Navigator.of(context).pop();
          },
          child: const Text('حذف'),
        ),
      ],
    );
  }
}

class SubjectCard extends StatelessWidget {
  const SubjectCard({required this.subject, required this.lessons, super.key});

  final String subject;
  final List<Lesson> lessons;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: lessons.isEmpty
              ? const Color(0xFFE8EEFF)
              : epsilonBlue.withValues(alpha: 0.24),
        ),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () => Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) =>
                SubjectLessonsPage(subject: subject, lessons: lessons),
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Container(
                    width: 42,
                    height: 42,
                    decoration: BoxDecoration(
                      color: const Color(0xFF2F5BEA).withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: const Icon(
                      Icons.folder_special_rounded,
                      color: Color(0xFF2F5BEA),
                      size: 23,
                    ),
                  ),
                  const Spacer(),
                  StatusPill(text: '${lessons.length} درس'),
                ],
              ),
              const SizedBox(height: 12),
              Text(
                subject,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: epsilonInk,
                  fontSize: 16,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                lessons.isEmpty
                    ? 'لا توجد دروس منشورة بعد'
                    : 'آخر درس: ${lessons.first.title}',
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: Color(0xFF6B7280),
                  fontSize: 12,
                  height: 1.3,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Text(
                    lessons.isEmpty ? 'تفقد لاحقًا' : 'عرض الدروس',
                    style: const TextStyle(
                      color: Color(0xFF2F5BEA),
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(width: 4),
                  const Icon(
                    Icons.chevron_left_rounded,
                    color: Color(0xFF2F5BEA),
                    size: 20,
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class SubjectLessonsPage extends StatelessWidget {
  const SubjectLessonsPage({
    required this.subject,
    required this.lessons,
    super.key,
  });

  final String subject;
  final List<Lesson> lessons;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF7F9FF),
      appBar: EpsilonAppBar(title: subject, showLogout: false),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
        children: [
          HeaderPanel(
            title: subject,
            subtitle: '${lessons.length} فيديو متوفر',
            icon: Icons.folder_special_rounded,
          ),
          const SizedBox(height: 16),
          SectionCard(
            title: 'دروس المادة',
            icon: Icons.play_circle_outline_rounded,
            child: lessons.isEmpty
                ? const EmptyState(text: 'لا توجد دروس منشورة لهذه المادة بعد.')
                : Column(
                    children: lessons
                        .map((lesson) => SecureLessonTile(lesson: lesson))
                        .toList(),
                  ),
          ),
        ],
      ),
    );
  }
}

class SecureLessonTile extends StatelessWidget {
  const SecureLessonTile({required this.lesson, super.key});

  final Lesson lesson;

  @override
  Widget build(BuildContext context) {
    final store = StoreScope.of(context);
    final course = store.courseById(lesson.courseId);

    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: const CircleAvatar(
        backgroundColor: Color(0xFFEAF1FF),
        child: Icon(Icons.play_arrow_rounded, color: Color(0xFF2F5BEA)),
      ),
      title: Text(
        lesson.title,
        style: const TextStyle(fontWeight: FontWeight.w800),
      ),
      subtitle: Text(course?.title ?? 'درس فيديو'),
      trailing: FilledButton(
        onPressed: () => Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => SecureVideoPage(lesson: lesson)),
        ),
        child: const Text('مشاهدة'),
      ),
    );
  }
}

class StatusPill extends StatelessWidget {
  const StatusPill({required this.text, super.key});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      decoration: BoxDecoration(
        color: const Color(0xFF2F5BEA).withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        text,
        style: const TextStyle(
          color: Color(0xFF2F5BEA),
          fontSize: 11,
          fontWeight: FontWeight.w900,
        ),
      ),
    );
  }
}

class SecureVideoPage extends StatefulWidget {
  const SecureVideoPage({required this.lesson, super.key});

  final Lesson lesson;

  @override
  State<SecureVideoPage> createState() => _SecureVideoPageState();
}

class _SecureVideoPageState extends State<SecureVideoPage> {
  @override
  Widget build(BuildContext context) {
    return SecureContentViewerPage(
      title: widget.lesson.title,
      url: widget.lesson.url,
      kind: SecureContentKind.video,
    );
  }
}

enum SecureContentKind { video, pdf }

class SecureContentViewerPage extends StatefulWidget {
  const SecureContentViewerPage({
    required this.title,
    required this.url,
    required this.kind,
    super.key,
  });

  final String title;
  final String url;
  final SecureContentKind kind;

  @override
  State<SecureContentViewerPage> createState() =>
      _SecureContentViewerPageState();
}

class _SecureContentViewerPageState extends State<SecureContentViewerPage> {
  static const secureChannel = MethodChannel('epsilon/secure_window');
  late final String contentUrl;
  late final bool useNativeVideo;
  WebViewController? controller;

  @override
  void initState() {
    super.initState();
    enableSecureWindow();
    contentUrl = toVideoViewerUrl(widget.url);
    useNativeVideo =
        widget.kind == SecureContentKind.video && isDirectVideoUrl(contentUrl);
    if (useNativeVideo) {
      return;
    }

    late final PlatformWebViewControllerCreationParams params;
    if (WebViewPlatform.instance is WebKitWebViewPlatform) {
      params = WebKitWebViewControllerCreationParams(
        allowsInlineMediaPlayback: true,
        mediaTypesRequiringUserAction: const <PlaybackMediaTypes>{},
      );
    } else {
      params = const PlatformWebViewControllerCreationParams();
    }

    final webController = WebViewController.fromPlatformCreationParams(params)
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(Colors.black);

    if (webController.platform is AndroidWebViewController) {
      (webController.platform as AndroidWebViewController)
          .setMediaPlaybackRequiresUserGesture(false);
    }

    webController.loadRequest(Uri.parse(contentUrl));
    controller = webController;
  }

  @override
  void dispose() {
    disableSecureWindow();
    super.dispose();
  }

  Future<void> enableSecureWindow() async {
    try {
      await secureChannel.invokeMethod<void>('enable');
    } on Object {
      // iOS does not offer a reliable screenshot block like Android FLAG_SECURE.
    }
  }

  Future<void> disableSecureWindow() async {
    try {
      await secureChannel.invokeMethod<void>('disable');
    } on Object {
      // Keep navigation smooth on platforms without the native hook.
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        title: Text(
          widget.title,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
        ),
      ),
      body: useNativeVideo
          ? NativeVideoPlayer(url: contentUrl)
          : WebViewWidget(controller: controller!),
    );
  }
}

class NativeVideoPlayer extends StatefulWidget {
  const NativeVideoPlayer({required this.url, super.key});

  final String url;

  @override
  State<NativeVideoPlayer> createState() => _NativeVideoPlayerState();
}

class _NativeVideoPlayerState extends State<NativeVideoPlayer> {
  late final VideoPlayerController controller;
  late final Future<void> initializeFuture;

  @override
  void initState() {
    super.initState();
    controller = VideoPlayerController.networkUrl(Uri.parse(widget.url));
    initializeFuture = controller.initialize().then((_) {
      controller.play();
      if (mounted) {
        setState(() {});
      }
    });
  }

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<void>(
      future: initializeFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError || !controller.value.isInitialized) {
          return const Center(
            child: Padding(
              padding: EdgeInsets.all(20),
              child: Text(
                'تعذر تشغيل ملف MOV داخل التطبيق. حوّله إلى MP4/H.264 أو استخدم Bunny Stream.',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.white, fontSize: 15),
              ),
            ),
          );
        }

        return ValueListenableBuilder<VideoPlayerValue>(
          valueListenable: controller,
          builder: (context, value, _) {
            return Stack(
              alignment: Alignment.center,
              children: [
                Center(
                  child: AspectRatio(
                    aspectRatio: value.aspectRatio == 0
                        ? 16 / 9
                        : value.aspectRatio,
                    child: VideoPlayer(controller),
                  ),
                ),
                IconButton(
                  iconSize: 72,
                  color: Colors.white,
                  onPressed: () {
                    value.isPlaying ? controller.pause() : controller.play();
                  },
                  icon: Icon(
                    value.isPlaying
                        ? Icons.pause_circle_filled_rounded
                        : Icons.play_circle_fill_rounded,
                  ),
                ),
                Positioned(
                  left: 12,
                  right: 12,
                  bottom: 18,
                  child: VideoProgressIndicator(
                    controller,
                    allowScrubbing: true,
                    colors: const VideoProgressColors(
                      playedColor: Colors.white,
                      bufferedColor: Colors.white38,
                      backgroundColor: Colors.white24,
                    ),
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }
}

class EmptyState extends StatelessWidget {
  const EmptyState({required this.text, super.key});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Text(
        text,
        textAlign: TextAlign.center,
        style: TextStyle(color: Colors.grey.shade700),
      ),
    );
  }
}

String statusLabel(AccountStatus status) {
  return switch (status) {
    AccountStatus.pending => 'بانتظار القبول',
    AccountStatus.active => 'نشط',
    AccountStatus.blocked => 'مجمد',
    AccountStatus.rejected => 'مرفوض',
  };
}

String roleLabel(UserRole? role) {
  return switch (role) {
    UserRole.admin => 'إدارة',
    UserRole.teacher => 'أستاذ',
    UserRole.student => 'طالب',
    null => '-',
  };
}

String adminTypeLabel(AdminType type) {
  return switch (type) {
    AdminType.developer => 'دفلوبر',
    AdminType.generalManager => 'مدير عام',
    AdminType.schoolManager => 'مدير الثانوية',
  };
}

String adminTypeValue(AdminType type) {
  return switch (type) {
    AdminType.developer => 'developer',
    AdminType.generalManager => 'general_manager',
    AdminType.schoolManager => 'school_manager',
  };
}

List<String> stringListFromDynamic(Object? value) {
  if (value is List) {
    return value
        .map((item) => '$item'.trim())
        .where((item) => item.isNotEmpty)
        .toList();
  }
  return const [];
}

Color courseAccent(String title) {
  final colors = [
    const Color(0xFF2F5BEA),
    const Color(0xFF10B981),
    const Color(0xFF7C3AED),
    const Color(0xFFF97316),
    const Color(0xFF0EA5E9),
    const Color(0xFFDB2777),
  ];
  return colors[title.hashCode.abs() % colors.length];
}

IconData courseIcon(String title) {
  final lower = title.toLowerCase();
  if (title.contains('رياض') || lower.contains('math')) {
    return Icons.calculate_rounded;
  }
  if (title.contains('فيزياء') ||
      title.contains('كيمياء') ||
      lower.contains('chem') ||
      lower.contains('physics')) {
    return Icons.science_rounded;
  }
  if (title.contains('حياة') ||
      title.contains('أرض') ||
      lower.contains('bio')) {
    return Icons.biotech_rounded;
  }
  if (title.contains('باك') || title.toLowerCase().contains('bac')) {
    return Icons.school_rounded;
  }
  if (title.contains('ذكاء') || lower.contains('ai')) {
    return Icons.psychology_rounded;
  }
  return Icons.menu_book_rounded;
}

String courseShortTitle(String title) {
  final trimmed = title.trim();
  if (trimmed.isEmpty) {
    return 'قسم';
  }
  if (trimmed.length <= 12) {
    return trimmed;
  }
  return '${trimmed.substring(0, 11)}...';
}

String courseTitleLine(String title, String? level) {
  if (level != null && level.trim().isNotEmpty) {
    return level;
  }
  return title;
}

List<Map<String, String>> parseSubjectInputs(String raw) {
  final subjects = raw
      .split(RegExp(r'[,،\n]'))
      .map((subject) {
        final parts = subject.split(RegExp(r'[:：=]'));
        final name = parts.first.trim();
        final price = parts.length > 1 ? parts.sublist(1).join(':').trim() : '';
        return {'name': name, 'price': price};
      })
      .where((subject) => subject['name']!.isNotEmpty)
      .toList();

  final seen = <String>{};
  final uniqueSubjects = <Map<String, String>>[];
  for (final subject in subjects) {
    final name = subject['name']!;
    if (seen.add(name)) {
      uniqueSubjects.add(subject);
    }
  }

  return uniqueSubjects.isEmpty
      ? [
          {'name': 'مادة عامة', 'price': ''},
        ]
      : uniqueSubjects;
}

String studentInvoiceAmount({
  required SchoolStore store,
  required AppUser student,
  required Course? course,
  required List<String> allowedSubjects,
}) {
  if (course == null) {
    return store.paymentAmount.trim().isEmpty
        ? 'غير محدد'
        : store.paymentAmount;
  }

  final fullCourse =
      allowedSubjects.isEmpty ||
      (allowedSubjects.length == course.subjects.length &&
          allowedSubjects.every(course.subjects.contains));
  if (fullCourse && course.price.trim().isNotEmpty) {
    return course.price.trim();
  }
  if (allowedSubjects.isNotEmpty) {
    final selectedAmount = selectedSubjectsAmount(course, allowedSubjects);
    if (selectedAmount != 'غير محدد') {
      return selectedAmount;
    }
  }
  return store.paymentAmount.trim().isEmpty ? 'غير محدد' : store.paymentAmount;
}

Future<File> createStudentInvoicePdf({
  required AppUser student,
  required Course course,
  required List<String> subjects,
  required String amount,
}) async {
  final now = DateTime.now();
  final logoBytes = await rootBundle.load(
    'assets/onboarding/epsilon_logo.jpeg',
  );
  final fontBytes = await rootBundle.load('assets/fonts/SFArabic.ttf');
  final arabicFont = pw.Font.ttf(fontBytes);
  final latinFont = pw.Font.helvetica();
  final latinBoldFont = pw.Font.helveticaBold();
  final logo = pw.MemoryImage(logoBytes.buffer.asUint8List());
  final pdf = pw.Document();
  final invoiceNumber =
      'INV-${now.year}${twoDigits(now.month)}${twoDigits(now.day)}-${twoDigits(now.hour)}${twoDigits(now.minute)}-${student.phone}';
  final subjectText = subjects.isEmpty ? 'القسم كامل' : subjects.join('، ');

  pdf.addPage(
    pw.Page(
      pageFormat: PdfPageFormat.a4,
      margin: const pw.EdgeInsets.all(32),
      theme: pw.ThemeData.withFont(
        base: arabicFont,
        bold: arabicFont,
        fontFallback: [latinFont, latinBoldFont],
      ),
      build: (context) {
        return pw.Directionality(
          textDirection: pw.TextDirection.rtl,
          child: pw.Container(
            decoration: pw.BoxDecoration(
              border: pw.Border.all(color: PdfColor.fromInt(0xFFDDE6F5)),
              borderRadius: pw.BorderRadius.circular(14),
            ),
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.stretch,
              children: [
                pw.Container(
                  padding: const pw.EdgeInsets.all(20),
                  decoration: pw.BoxDecoration(
                    color: PdfColor.fromInt(0xFF2457E6),
                    borderRadius: const pw.BorderRadius.only(
                      topLeft: pw.Radius.circular(14),
                      topRight: pw.Radius.circular(14),
                    ),
                  ),
                  child: pw.Row(
                    children: [
                      pw.Container(
                        width: 72,
                        height: 72,
                        padding: const pw.EdgeInsets.all(6),
                        decoration: pw.BoxDecoration(
                          color: PdfColors.white,
                          borderRadius: pw.BorderRadius.circular(16),
                        ),
                        child: pw.Image(logo, fit: pw.BoxFit.cover),
                      ),
                      pw.SizedBox(width: 16),
                      pw.Expanded(
                        child: pw.Column(
                          crossAxisAlignment: pw.CrossAxisAlignment.start,
                          children: [
                            pw.Text(
                              'منصة إبسيلون التعليمية',
                              textAlign: pw.TextAlign.right,
                              style: pw.TextStyle(
                                color: PdfColors.white,
                                fontSize: 24,
                                fontWeight: pw.FontWeight.bold,
                              ),
                            ),
                            pw.SizedBox(height: 4),
                            pw.Text(
                              'فاتورة اشتراك رسمية',
                              textAlign: pw.TextAlign.right,
                              style: const pw.TextStyle(
                                color: PdfColors.white,
                                fontSize: 15,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                pw.Padding(
                  padding: const pw.EdgeInsets.all(22),
                  child: pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.stretch,
                    children: [
                      pw.Row(
                        children: [
                          pw.Expanded(
                            child: invoicePdfInfoBox(
                              label: 'رقم الفاتورة',
                              value: invoiceNumber,
                            ),
                          ),
                          pw.SizedBox(width: 12),
                          pw.Expanded(
                            child: invoicePdfInfoBox(
                              label: 'التاريخ والوقت',
                              value:
                                  '${formatArabicDate(now)} - ${formatTime(now)}',
                            ),
                          ),
                        ],
                      ),
                      pw.SizedBox(height: 18),
                      pw.Text(
                        'بيانات الطالب',
                        style: pw.TextStyle(
                          color: PdfColor.fromInt(0xFF17213D),
                          fontSize: 17,
                          fontWeight: pw.FontWeight.bold,
                        ),
                      ),
                      pw.SizedBox(height: 10),
                      invoicePdfTable([
                        ['اسم الطالب', student.name],
                        ['رقم الهاتف', student.phone],
                        ['القسم أو الدورة', course.title],
                        ['المواد', subjectText],
                        ['حالة الدفع', 'مدفوعة ومؤكدة من الإدارة'],
                      ]),
                      pw.SizedBox(height: 18),
                      pw.Container(
                        padding: const pw.EdgeInsets.all(16),
                        decoration: pw.BoxDecoration(
                          color: PdfColor.fromInt(0xFFEFF6FF),
                          borderRadius: pw.BorderRadius.circular(12),
                        ),
                        child: pw.Row(
                          children: [
                            pw.Text(
                              'المبلغ الإجمالي',
                              style: pw.TextStyle(
                                color: PdfColor.fromInt(0xFF17213D),
                                fontSize: 16,
                                fontWeight: pw.FontWeight.bold,
                              ),
                            ),
                            pw.Spacer(),
                            pw.Text(
                              amount,
                              textDirection: invoiceTextDirection(amount),
                              textAlign: pw.TextAlign.left,
                              style: pw.TextStyle(
                                color: PdfColor.fromInt(0xFF2457E6),
                                fontSize: 20,
                                fontWeight: pw.FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ),
                      pw.SizedBox(height: 70),
                      pw.Row(
                        children: [
                          pw.Expanded(
                            child: invoiceSignatureBox(
                              title: 'المدير العام',
                              name: 'احمد طالب عمر',
                            ),
                          ),
                          pw.SizedBox(width: 16),
                          pw.Expanded(
                            child: invoiceSignatureBox(
                              title: 'مدير المالية والرقمنة',
                              name: 'محمد سعيد محمدن',
                            ),
                          ),
                        ],
                      ),
                      pw.SizedBox(height: 14),
                      pw.Center(
                        child: pw.Text(
                          'تم إصدار هذه الفاتورة إلكترونياً بعد تأكيد عملية الدفع من طرف الإدارة.',
                          style: const pw.TextStyle(
                            color: PdfColor.fromInt(0xFF66708F),
                            fontSize: 11,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    ),
  );

  final directory = await getApplicationDocumentsDirectory();
  final invoicesDirectory = Directory('${directory.path}/invoices');
  if (!await invoicesDirectory.exists()) {
    await invoicesDirectory.create(recursive: true);
  }
  final fileName =
      'epsilon_invoice_${safeFileSegment(student.phone)}_${now.millisecondsSinceEpoch}.pdf';
  final file = File('${invoicesDirectory.path}/$fileName');
  await file.writeAsBytes(await pdf.save(), flush: true);
  return file;
}

pw.Widget invoicePdfInfoBox({required String label, required String value}) {
  return pw.Container(
    padding: const pw.EdgeInsets.all(12),
    decoration: pw.BoxDecoration(
      color: PdfColor.fromInt(0xFFF8FAFC),
      border: pw.Border.all(color: PdfColor.fromInt(0xFFE2E8F0)),
      borderRadius: pw.BorderRadius.circular(10),
    ),
    child: pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Text(
          label,
          textAlign: pw.TextAlign.right,
          style: const pw.TextStyle(
            color: PdfColor.fromInt(0xFF66708F),
            fontSize: 10,
          ),
        ),
        pw.SizedBox(height: 4),
        invoicePdfText(
          value,
          textAlign: pw.TextAlign.right,
          style: pw.TextStyle(
            color: PdfColor.fromInt(0xFF17213D),
            fontSize: 12,
            fontWeight: pw.FontWeight.bold,
          ),
        ),
      ],
    ),
  );
}

pw.Widget invoicePdfTable(List<List<String>> rows) {
  return pw.Table(
    border: pw.TableBorder.all(color: PdfColor.fromInt(0xFFE2E8F0)),
    columnWidths: const {
      0: pw.FlexColumnWidth(1.2),
      1: pw.FlexColumnWidth(2.2),
    },
    children: rows.map((row) {
      return pw.TableRow(
        children: [
          invoicePdfCell(row[0], isLabel: true),
          invoicePdfCell(row[1]),
        ],
      );
    }).toList(),
  );
}

pw.Widget invoicePdfCell(String text, {bool isLabel = false}) {
  return pw.Container(
    padding: const pw.EdgeInsets.symmetric(horizontal: 10, vertical: 9),
    color: isLabel ? PdfColor.fromInt(0xFFF8FAFC) : PdfColors.white,
    child: invoicePdfText(
      text,
      textAlign: pw.TextAlign.right,
      style: pw.TextStyle(
        color: isLabel
            ? PdfColor.fromInt(0xFF475569)
            : PdfColor.fromInt(0xFF17213D),
        fontSize: 11,
        fontWeight: isLabel ? pw.FontWeight.bold : pw.FontWeight.normal,
      ),
    ),
  );
}

pw.Widget invoicePdfText(
  String text, {
  required pw.TextStyle style,
  pw.TextAlign textAlign = pw.TextAlign.right,
}) {
  return pw.Directionality(
    textDirection: invoiceTextDirection(text),
    child: pw.Text(text, textAlign: textAlign, style: style),
  );
}

pw.TextDirection invoiceTextDirection(String text) {
  return RegExp(r'[\u0600-\u06FF]').hasMatch(text)
      ? pw.TextDirection.rtl
      : pw.TextDirection.ltr;
}

pw.Widget invoiceSignatureBox({required String title, required String name}) {
  return pw.Container(
    height: 98,
    padding: const pw.EdgeInsets.all(12),
    decoration: pw.BoxDecoration(
      border: pw.Border.all(color: PdfColor.fromInt(0xFFDDE6F5)),
      borderRadius: pw.BorderRadius.circular(12),
    ),
    child: pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.stretch,
      children: [
        pw.Text(
          title,
          textAlign: pw.TextAlign.center,
          style: const pw.TextStyle(
            color: PdfColor.fromInt(0xFF66708F),
            fontSize: 10,
          ),
        ),
        pw.SizedBox(height: 8),
        pw.Container(height: 1, color: PdfColor.fromInt(0xFFDDE6F5)),
        pw.Spacer(),
        pw.Text(
          name,
          textAlign: pw.TextAlign.center,
          style: pw.TextStyle(
            color: PdfColor.fromInt(0xFF17213D),
            fontSize: 13,
            fontWeight: pw.FontWeight.bold,
          ),
        ),
        pw.SizedBox(height: 2),
        pw.Text(
          'التوقيع',
          textAlign: pw.TextAlign.center,
          style: const pw.TextStyle(
            color: PdfColor.fromInt(0xFF94A3B8),
            fontSize: 9,
          ),
        ),
      ],
    ),
  );
}

String formatArabicDate(DateTime date) {
  return '${twoDigits(date.day)}/${twoDigits(date.month)}/${date.year}';
}

String formatTime(DateTime date) {
  return '${twoDigits(date.hour)}:${twoDigits(date.minute)}';
}

DateTime addMonths(DateTime date, int months) {
  final targetMonth = date.month + months;
  final year = date.year + ((targetMonth - 1) ~/ 12);
  final month = ((targetMonth - 1) % 12) + 1;
  final day = min(date.day, DateTime(year, month + 1, 0).day);
  return DateTime(
    year,
    month,
    day,
    date.hour,
    date.minute,
    date.second,
    date.millisecond,
    date.microsecond,
  );
}

String twoDigits(int value) => value.toString().padLeft(2, '0');

String safeFileSegment(String value) {
  return value.replaceAll(RegExp(r'[^a-zA-Z0-9_-]+'), '_');
}

String selectedSubjectsAmount(
  Course course,
  Iterable<String> selectedSubjects,
) {
  final selected = selectedSubjects.toList();
  if (selected.isEmpty) {
    return 'غير محدد';
  }

  final prices = selected
      .map((subject) => course.subjectPrices[subject]?.trim() ?? '')
      .toList();
  if (prices.any((price) => price.isEmpty)) {
    return selected.length == 1 ? 'سعر المادة غير محدد' : 'بعض المواد بدون سعر';
  }

  final numericPrices = prices.map(priceNumberFromText).toList();
  if (numericPrices.every((price) => price != null)) {
    final total = numericPrices.fold<double>(
      0,
      (runningTotal, price) => runningTotal + price!,
    );
    final suffix = priceSuffix(prices.first);
    final totalText = total == total.roundToDouble()
        ? total.round().toString()
        : total.toStringAsFixed(2);
    return suffix.isEmpty ? totalText : '$totalText $suffix';
  }

  if (prices.length == 1) {
    return prices.first;
  }
  return 'حسب أسعار المواد المختارة';
}

String formatBoxAmount(double amount) {
  return amount == amount.roundToDouble()
      ? amount.round().toString()
      : amount.toStringAsFixed(2);
}

double? priceNumberFromText(String value) {
  final normalized = value
      .replaceAll('٬', '')
      .replaceAll(',', '.')
      .replaceAll(RegExp(r'[^0-9.]'), '');
  if (normalized.isEmpty) {
    return null;
  }
  return double.tryParse(normalized);
}

String priceSuffix(String value) {
  return value.replaceAll(RegExp(r'[0-9\s.,٬]+'), '').trim();
}

String toVideoViewerUrl(String url) {
  final trimmed = url.trim();
  if (isDirectVideoUrl(trimmed)) {
    return trimmed;
  }

  final idMatch =
      RegExp(r'/d/([^/]+)').firstMatch(trimmed) ??
      RegExp(r'id=([^&]+)').firstMatch(trimmed);

  if (idMatch == null) {
    return trimmed;
  }

  final fileId = idMatch.group(1);
  if (fileId == null || fileId.isEmpty) {
    return trimmed;
  }

  return 'https://drive.google.com/file/d/$fileId/preview';
}

bool isDirectVideoUrl(String url) {
  final path = Uri.tryParse(url)?.path.toLowerCase() ?? url.toLowerCase();
  return path.endsWith('.mp4') ||
      path.endsWith('.webm') ||
      path.endsWith('.mov') ||
      path.endsWith('.m4v') ||
      path.endsWith('.m3u8');
}

String videoPlayerHtml(String url) {
  final escapedUrl = const HtmlEscape().convert(url);
  final escapedType = const HtmlEscape().convert(videoMimeType(url));
  return '''
<!doctype html>
<html>
<head>
  <meta name="viewport" content="width=device-width, initial-scale=1, viewport-fit=cover">
  <script src="https://cdn.jsdelivr.net/npm/hls.js@latest"></script>
  <style>
    html, body {
      margin: 0;
      width: 100%;
      height: 100%;
      background: #000;
      overflow: hidden;
    }
    body {
      display: flex;
      align-items: center;
      justify-content: center;
      color: #fff;
      font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", sans-serif;
    }
    video {
      width: 100%;
      height: 100%;
      background: #000;
      object-fit: contain;
    }
    #message {
      position: absolute;
      inset: auto 16px 28px 16px;
      padding: 12px 14px;
      border-radius: 8px;
      background: rgba(0, 0, 0, .72);
      color: #fff;
      font-size: 14px;
      line-height: 1.5;
      text-align: center;
      display: none;
      z-index: 2;
    }
  </style>
</head>
<body>
  <video id="player" controls playsinline webkit-playsinline preload="metadata" controlsList="nodownload">
    <source src="$escapedUrl" type="$escapedType">
  </video>
  <div id="message">تعذر تشغيل الفيديو داخل التطبيق. تحقق من رابط Bunny أو صيغة الفيديو.</div>
  <script>
    const source = "$escapedUrl";
    const player = document.getElementById('player');
    const message = document.getElementById('message');
    const showError = () => { message.style.display = 'block'; };

    player.addEventListener('loadeddata', () => { message.style.display = 'none'; });
    player.addEventListener('error', showError);

    if (source.toLowerCase().includes('.m3u8')) {
      if (player.canPlayType('application/vnd.apple.mpegurl')) {
        player.src = source;
      } else if (window.Hls && Hls.isSupported()) {
        const hls = new Hls({
          enableWorker: true,
          lowLatencyMode: true,
        });
        hls.loadSource(source);
        hls.attachMedia(player);
        hls.on(Hls.Events.ERROR, function (_, data) {
          if (data && data.fatal) showError();
        });
      } else {
        showError();
      }
    } else {
      player.load();
    }
  </script>
</body>
</html>
''';
}

String videoMimeType(String url) {
  final path = Uri.tryParse(url)?.path.toLowerCase() ?? url.toLowerCase();
  if (path.endsWith('.mov')) {
    return 'video/quicktime';
  }
  if (path.endsWith('.webm')) {
    return 'video/webm';
  }
  if (path.endsWith('.m3u8')) {
    return 'application/vnd.apple.mpegurl';
  }
  return 'video/mp4';
}
