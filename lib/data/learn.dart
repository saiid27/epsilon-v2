// Data layer for the Figma redesign features: subjects catalog, per-subject
// subscriptions, plans, lesson progress, PDFs, live sessions, quizzes,
// leaderboard, announcements, per-user notifications and assistant.
//
// Tables are created by supabase/migrations/20261112_figma_redesign.sql.

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

// ---------------------------------------------------------------------------
// Models
// ---------------------------------------------------------------------------

DateTime? _date(Object? value) =>
    value == null ? null : DateTime.tryParse('$value')?.toLocal();

int _int(Object? value, [int fallback = 0]) =>
    value is num ? value.toInt() : int.tryParse('${value ?? ''}') ?? fallback;

double _double(Object? value) =>
    value is num ? value.toDouble() : double.tryParse('${value ?? ''}') ?? 0;

String _str(Object? value) => value == null ? '' : '$value';

bool _bool(Object? value) => value == true || value == 'true';

List<String> _strings(Object? value) =>
    value is List ? value.map((e) => '$e').toList() : const [];

enum SubscriptionStatus { pending, active, expired, rejected }

SubscriptionStatus _status(String value) => switch (value) {
  'active' => SubscriptionStatus.active,
  'expired' => SubscriptionStatus.expired,
  'rejected' => SubscriptionStatus.rejected,
  _ => SubscriptionStatus.pending,
};

class EpsSubject {
  EpsSubject.fromRow(Map<String, dynamic> r)
    : id = _str(r['id']),
      courseId = r['course_id'] == null ? null : _str(r['course_id']),
      name = _str(r['name']),
      icon = _str(r['icon']).isEmpty ? '∑' : _str(r['icon']),
      colorHex = _str(r['color']).isEmpty ? '#DBEAFE' : _str(r['color']),
      faculty = _str(r['faculty']),
      level = _str(r['level']),
      description = _str(r['description']),
      monthlyPrice = _int(r['monthly_price']),
      discount = _int(r['discount']),
      teacherId = r['teacher_id'] == null ? null : _str(r['teacher_id']),
      isActive = r['is_active'] != false,
      sortOrder = _int(r['sort_order']);

  final String id;
  final String? courseId;
  final String name;
  final String icon;
  final String colorHex;
  final String faculty;
  final String level;
  final String description;
  final int monthlyPrice;
  final int discount;
  final String? teacherId;
  final bool isActive;
  final int sortOrder;

  Color get color {
    final hex = colorHex.replaceAll('#', '');
    return Color(int.tryParse('FF$hex', radix: 16) ?? 0xFFDBEAFE);
  }

  Map<String, dynamic> toRow() => {
    'course_id': courseId,
    'name': name,
    'icon': icon,
    'color': colorHex,
    'faculty': faculty,
    'level': level,
    'description': description,
    'monthly_price': monthlyPrice,
    'discount': discount,
    'teacher_id': teacherId,
    'is_active': isActive,
    'sort_order': sortOrder,
  };
}

class EpsTeacher {
  EpsTeacher.fromRow(Map<String, dynamic> r)
    : id = _str(r['id']),
      name = _str(r['name']),
      photoUrl = _str(r['avatar_url']),
      specialty = _str(r['specialty']),
      bio = _str(r['bio']),
      yearsOfExperience = _int(r['years_experience']),
      rating = _double(r['rating']);

  final String id;
  final String name;
  final String photoUrl;
  final String specialty;
  final String bio;
  final int yearsOfExperience;
  final double rating;
}

class EpsPlan {
  EpsPlan.fromRow(Map<String, dynamic> r)
    : code = _str(r['code']),
      title = _str(r['title']),
      subtitle = _str(r['subtitle']),
      badge = _str(r['badge']),
      months = _int(r['months']),
      discountPercent = _int(r['discount_percent']),
      isFree = _bool(r['is_free']),
      features = _strings(r['features']);

  final String code;
  final String title;
  final String subtitle;
  final String badge;
  final int months;
  final int discountPercent;
  final bool isFree;
  final List<String> features;

  int priceFor(int monthlyTotal) {
    if (isFree) {
      return 0;
    }
    final full = monthlyTotal * months;
    return (full * (100 - discountPercent) / 100).round();
  }
}

class EpsSubscription {
  EpsSubscription.fromRow(Map<String, dynamic> r)
    : id = _str(r['id']),
      ref = _str(r['request_ref']),
      studentId = _str(r['student_id']),
      subjectId = _str(r['subject_id']),
      planCode = _str(r['plan_code']),
      amount = _int(r['amount']),
      paymentMethodId = r['payment_method_id'] == null
          ? null
          : _str(r['payment_method_id']),
      receiptUrl = _str(r['receipt_url']),
      transactionRef = _str(r['transaction_ref']),
      rawStatus = _status(_str(r['status'])),
      rejectionReason = _str(r['rejection_reason']),
      startsAt = _date(r['starts_at']),
      expiresAt = _date(r['expires_at']),
      createdAt = _date(r['created_at']) ?? DateTime.now();

  final String id;
  final String ref;
  final String studentId;
  final String subjectId;
  final String planCode;
  final int amount;
  final String? paymentMethodId;
  final String receiptUrl;
  final String transactionRef;
  final SubscriptionStatus rawStatus;
  final String rejectionReason;
  final DateTime? startsAt;
  final DateTime? expiresAt;
  final DateTime createdAt;

  SubscriptionStatus get status =>
      rawStatus == SubscriptionStatus.active &&
          expiresAt != null &&
          expiresAt!.isBefore(DateTime.now())
      ? SubscriptionStatus.expired
      : rawStatus;
}

class EpsLesson {
  EpsLesson.fromRow(Map<String, dynamic> r)
    : id = _str(r['id']),
      subjectId = _str(r['subject_id']),
      courseId = _str(r['course_id']),
      subjectName = _str(r['subject']),
      title = _str(r['title']),
      url = _str(r['url']),
      unit = _str(r['unit']),
      duration = _str(r['duration']),
      pdfUrl = _str(r['pdf_url']),
      isFree = _bool(r['is_free']),
      description = _str(r['description']),
      keyIdea = _str(r['key_idea']),
      example = _str(r['example']),
      sortOrder = _int(r['sort_order']),
      isPublished = r['is_published'] != false,
      createdAt = _date(r['created_at']) ?? DateTime.now();

  final String id;
  final String subjectId;
  final String courseId;
  final String subjectName;
  final String title;
  final String url;
  final String unit;
  final String duration;
  final String pdfUrl;
  final bool isFree;
  final String description;
  final String keyIdea;
  final String example;
  final int sortOrder;
  final bool isPublished;
  final DateTime createdAt;
}

class EpsExercise {
  EpsExercise.fromRow(Map<String, dynamic> r)
    : id = _str(r['id']),
      lessonId = _str(r['lesson_id']),
      question = _str(r['question']),
      illustration = _str(r['illustration']),
      solutionSteps = _strings(r['solution_steps']),
      isFree = _bool(r['is_free']);

  final String id;
  final String lessonId;
  final String question;
  final String illustration;
  final List<String> solutionSteps;
  final bool isFree;
}

class EpsPdf {
  EpsPdf.fromRow(Map<String, dynamic> r)
    : id = _str(r['id']),
      subjectId = _str(r['subject_id']),
      title = _str(r['title']),
      url = _str(r['url']),
      pageCount = _int(r['page_count']),
      sizeText = _str(r['size_text']),
      isFree = _bool(r['is_free']);

  final String id;
  final String subjectId;
  final String title;
  final String url;
  final int pageCount;
  final String sizeText;
  final bool isFree;
}

enum LiveState { live, upcoming, past }

class EpsLiveSession {
  EpsLiveSession.fromRow(Map<String, dynamic> r)
    : id = _str(r['id']),
      subjectId = _str(r['subject_id']),
      teacherId = r['teacher_id'] == null ? null : _str(r['teacher_id']),
      title = _str(r['title']),
      startsAt = _date(r['starts_at']) ?? DateTime.now(),
      durationMinutes = _int(r['duration_minutes'], 60),
      liveUrl = _str(r['live_url']),
      recordingUrl = _str(r['recording_url']),
      isFree = _bool(r['is_free']),
      isLiveFlag = _bool(r['is_live']),
      attendees = _int(r['attendees_count']);

  final String id;
  final String subjectId;
  final String? teacherId;
  final String title;
  final DateTime startsAt;
  final int durationMinutes;
  final String liveUrl;
  final String recordingUrl;
  final bool isFree;
  final bool isLiveFlag;
  final int attendees;

  DateTime get endsAt => startsAt.add(Duration(minutes: durationMinutes));

  LiveState get state {
    final now = DateTime.now();
    if (isLiveFlag || (now.isAfter(startsAt) && now.isBefore(endsAt))) {
      return LiveState.live;
    }
    return now.isBefore(startsAt) ? LiveState.upcoming : LiveState.past;
  }
}

class EpsLiveMessage {
  EpsLiveMessage.fromRow(Map<String, dynamic> r)
    : id = _str(r['id']),
      userId = _str(r['user_id']),
      userName = _str(r['user_name']),
      isTeacher = _bool(r['is_teacher']),
      isQuestion = _bool(r['is_question']),
      body = _str(r['body']),
      createdAt = _date(r['created_at']) ?? DateTime.now();

  final String id;
  final String userId;
  final String userName;
  final bool isTeacher;
  final bool isQuestion;
  final String body;
  final DateTime createdAt;
}

class EpsQuiz {
  EpsQuiz.fromRow(Map<String, dynamic> r)
    : id = _str(r['id']),
      subjectId = r['subject_id'] == null ? null : _str(r['subject_id']),
      title = _str(r['title']),
      kind = _str(r['kind']),
      xpReward = _int(r['xp_reward'], 50),
      timeLimitSeconds = _int(r['time_limit_seconds'], 300),
      questionSeconds = _int(r['question_seconds'], 30),
      isFree = _bool(r['is_free']),
      publishDate = _date(r['publish_date']),
      questionsCount = r['quiz_questions'] is List
          ? (r['quiz_questions'] as List).length
          : _int(r['questions_count']);

  final String id;
  final String? subjectId;
  final String title;
  final String kind;
  final int xpReward;
  final int timeLimitSeconds;
  final int questionSeconds;
  final bool isFree;
  final DateTime? publishDate;
  final int questionsCount;
}

class EpsQuestion {
  EpsQuestion.fromRow(Map<String, dynamic> r)
    : id = _str(r['id']),
      prompt = _str(r['prompt']),
      formula = _str(r['formula']),
      options = _strings(r['options']),
      correctIndex = _int(r['correct_index']),
      explanation = _str(r['explanation']);

  final String id;
  final String prompt;
  final String formula;
  final List<String> options;
  final int correctIndex;
  final String explanation;
}

class EpsAttempt {
  EpsAttempt.fromRow(Map<String, dynamic> r)
    : id = _str(r['id']),
      quizId = _str(r['quiz_id']),
      correctCount = _int(r['correct_count']),
      total = _int(r['total']),
      xpEarned = _int(r['xp_earned']),
      durationSeconds = _int(r['duration_seconds']),
      createdAt = _date(r['created_at']) ?? DateTime.now();

  final String id;
  final String quizId;
  final int correctCount;
  final int total;
  final int xpEarned;
  final int durationSeconds;
  final DateTime createdAt;
}

class EpsLeader {
  EpsLeader.fromRow(Map<String, dynamic> r)
    : studentId = _str(r['student_id']),
      name = _str(r['name']),
      avatarUrl = _str(r['avatar_url']),
      xp = _int(r['xp']);

  final String studentId;
  final String name;
  final String avatarUrl;
  final int xp;
}

class EpsAnnouncement {
  EpsAnnouncement.fromRow(Map<String, dynamic> r)
    : id = _str(r['id']),
      title = _str(r['title']),
      body = _str(r['body']),
      active = r['active'] != false,
      createdAt = _date(r['created_at']) ?? DateTime.now();

  final String id;
  final String title;
  final String body;
  final bool active;
  final DateTime createdAt;
}

class EpsNotice {
  EpsNotice.fromRow(Map<String, dynamic> r, {required this.read})
    : id = _str(r['id']),
      userId = r['user_id'] == null ? null : _str(r['user_id']),
      kind = _str(r['kind']).isEmpty ? 'general' : _str(r['kind']),
      title = _str(r['title']),
      body = _str(r['body']),
      createdAt = _date(r['created_at']) ?? DateTime.now();

  final String id;
  final String? userId;
  final String kind;
  final String title;
  final String body;
  final DateTime createdAt;
  bool read;
}

class EpsProfile {
  EpsProfile.fromRow(Map<String, dynamic> r)
    : id = _str(r['id']),
      name = _str(r['name']),
      phone = _str(r['phone']),
      university = _str(r['university']),
      faculty = _str(r['faculty']),
      track = _str(r['track']),
      level = _str(r['level']),
      avatarUrl = _str(r['avatar_url']),
      xp = _int(r['xp']),
      streakDays = _int(r['streak_days']),
      lastActivity = _date(r['last_activity_date']),
      profileCompleted = _bool(r['profile_completed']);

  final String id;
  final String name;
  final String phone;
  final String university;
  final String faculty;
  final String track;
  final String level;
  final String avatarUrl;
  final int xp;
  final int streakDays;
  final DateTime? lastActivity;
  final bool profileCompleted;

  /// Level every 250 XP, matching the profile card ("المستوى 8").
  int get xpLevel => xp ~/ 250 + 1;
  int get xpToNextLevel => 250 - xp % 250;
  double get levelProgress => (xp % 250) / 250;

  int get activeStreak {
    if (lastActivity == null) {
      return 0;
    }
    final today = DateUtils.dateOnly(DateTime.now());
    final last = DateUtils.dateOnly(lastActivity!);
    return today.difference(last).inDays <= 1 ? streakDays : 0;
  }
}

// ---------------------------------------------------------------------------
// Repository
// ---------------------------------------------------------------------------

class LearnRepository {
  LearnRepository([SupabaseClient? client])
    : client = client ?? Supabase.instance.client;

  final SupabaseClient client;

  List<Map<String, dynamic>> _list(Object? value) => value is List
      ? value.whereType<Map>().map(Map<String, dynamic>.from).toList()
      : const [];

  Future<List<Map<String, dynamic>>> _select(
    String table, {
    String columns = '*',
    String? order,
    bool ascending = true,
  }) async {
    final query = client.from(table).select(columns);
    final rows = order == null
        ? await query
        : await query.order(order, ascending: ascending);
    return _list(rows);
  }

  Future<EpsProfile?> profile(String userId) async {
    final rows = _list(
      await client.from('users').select().eq('id', userId).limit(1),
    );
    return rows.isEmpty ? null : EpsProfile.fromRow(rows.first);
  }

  Future<void> updateProfile(String userId, Map<String, dynamic> values) =>
      client.from('users').update(values).eq('id', userId);

  Future<List<EpsSubject>> subjects() async => (await _select(
    'subjects',
    order: 'sort_order',
  )).map(EpsSubject.fromRow).toList();

  Future<List<EpsTeacher>> teachers() async => _list(
    await client.from('users').select().eq('role', 'teacher'),
  ).map(EpsTeacher.fromRow).toList();

  Future<List<EpsPlan>> plans() async => (await _select(
    'plans',
    order: 'sort_order',
  )).map(EpsPlan.fromRow).toList();

  Future<List<EpsSubscription>> subscriptions({String? studentId}) async {
    var query = client.from('subject_subscriptions').select();
    if (studentId != null) {
      query = query.eq('student_id', studentId);
    }
    return _list(
      await query.order('created_at', ascending: false),
    ).map(EpsSubscription.fromRow).toList();
  }

  Future<List<EpsSubscription>> requestSubscriptions({
    required String studentId,
    required List<EpsSubject> subjects,
    required EpsPlan plan,
    required String? paymentMethodId,
    required String receiptUrl,
    required String transactionRef,
  }) async {
    final payload = [
      for (final subject in subjects)
        {
          'student_id': studentId,
          'subject_id': subject.id,
          'plan_code': plan.code,
          'amount': plan.priceFor(subject.monthlyPrice),
          'payment_method_id': paymentMethodId,
          'receipt_url': receiptUrl,
          'transaction_ref': transactionRef,
          'status': 'pending',
        },
    ];
    // A re-upload replaces earlier pending/rejected requests for the subject.
    await client
        .from('subject_subscriptions')
        .delete()
        .eq('student_id', studentId)
        .inFilter('subject_id', [for (final s in subjects) s.id])
        .inFilter('status', ['pending', 'rejected']);
    final rows = await client
        .from('subject_subscriptions')
        .insert(payload)
        .select();
    return _list(rows).map(EpsSubscription.fromRow).toList();
  }

  Future<void> reviewSubscription({
    required EpsSubscription subscription,
    required bool approve,
    String reason = '',
    int months = 1,
  }) {
    final now = DateTime.now().toUtc();
    return client
        .from('subject_subscriptions')
        .update({
          'status': approve ? 'active' : 'rejected',
          'rejection_reason': approve ? '' : reason,
          'reviewed_at': now.toIso8601String(),
          if (approve) 'starts_at': now.toIso8601String(),
          if (approve)
            'expires_at': DateTime(
              now.year,
              now.month + (months < 1 ? 1 : months),
              now.day,
            ).toUtc().toIso8601String(),
        })
        .eq('id', subscription.id);
  }

  Future<List<EpsLesson>> lessons() async => (await _select(
    'lessons',
    order: 'sort_order',
  )).map(EpsLesson.fromRow).toList();

  Future<Set<String>> completedLessons(String studentId) async => _list(
    await client
        .from('lesson_progress')
        .select('lesson_id')
        .eq('student_id', studentId)
        .eq('completed', true),
  ).map((r) => _str(r['lesson_id'])).toSet();

  Future<void> setLessonCompleted(
    String studentId,
    String lessonId,
    bool done,
  ) => client.from('lesson_progress').upsert({
    'student_id': studentId,
    'lesson_id': lessonId,
    'completed': done,
    'updated_at': DateTime.now().toUtc().toIso8601String(),
  });

  Future<List<EpsExercise>> exercises() async => (await _select(
    'lesson_exercises',
    order: 'sort_order',
  )).map(EpsExercise.fromRow).toList();

  Future<List<EpsPdf>> pdfs() async => (await _select(
    'pdf_resources',
    order: 'created_at',
  )).map(EpsPdf.fromRow).toList();

  Future<List<EpsLiveSession>> liveSessions() async => (await _select(
    'live_sessions',
    order: 'starts_at',
  )).map(EpsLiveSession.fromRow).toList();

  Future<Set<String>> liveReminders(String userId) async => _list(
    await client
        .from('live_reminders')
        .select('session_id')
        .eq('user_id', userId),
  ).map((r) => _str(r['session_id'])).toSet();

  Future<void> setLiveReminder(String userId, String sessionId, bool on) => on
      ? client.from('live_reminders').upsert({
          'user_id': userId,
          'session_id': sessionId,
        })
      : client
            .from('live_reminders')
            .delete()
            .eq('user_id', userId)
            .eq('session_id', sessionId);

  Future<List<EpsLiveMessage>> liveMessages(String sessionId) async => _list(
    await client
        .from('live_messages')
        .select()
        .eq('session_id', sessionId)
        .order('created_at'),
  ).map(EpsLiveMessage.fromRow).toList();

  Future<void> sendLiveMessage({
    required String sessionId,
    required String userId,
    required String userName,
    required String body,
    required bool isQuestion,
    bool isTeacher = false,
  }) => client.from('live_messages').insert({
    'session_id': sessionId,
    'user_id': userId,
    'user_name': userName,
    'body': body,
    'is_question': isQuestion,
    'is_teacher': isTeacher,
  });

  Future<List<EpsQuiz>> quizzes() async => _list(
    await client
        .from('quizzes')
        .select('*, quiz_questions(id)')
        .eq('active', true)
        .order('publish_date', ascending: false),
  ).map(EpsQuiz.fromRow).toList();

  Future<List<EpsQuestion>> questions(String quizId) async => _list(
    await client
        .from('quiz_questions')
        .select()
        .eq('quiz_id', quizId)
        .order('sort_order'),
  ).map(EpsQuestion.fromRow).toList();

  Future<List<EpsAttempt>> attempts(String studentId) async => _list(
    await client
        .from('quiz_attempts')
        .select()
        .eq('student_id', studentId)
        .order('created_at', ascending: false),
  ).map(EpsAttempt.fromRow).toList();

  Future<EpsAttempt> recordAttempt({
    required String quizId,
    required String studentId,
    required int correct,
    required int total,
    required int xp,
    required int seconds,
    required List<int> answers,
  }) async {
    final row = await client
        .from('quiz_attempts')
        .insert({
          'quiz_id': quizId,
          'student_id': studentId,
          'correct_count': correct,
          'total': total,
          'xp_earned': xp,
          'duration_seconds': seconds,
          'answers': answers,
        })
        .select()
        .single();
    return EpsAttempt.fromRow(Map<String, dynamic>.from(row));
  }

  Future<List<EpsLeader>> leaderboard({
    bool weekly = true,
    String? subjectId,
  }) async {
    final rows = subjectId != null
        ? await client
              .from('leaderboard_by_subject')
              .select()
              .eq('subject_id', subjectId)
              .order('xp', ascending: false)
              .limit(100)
        : await client
              .from(weekly ? 'leaderboard_weekly' : 'leaderboard_all_time')
              .select()
              .order('xp', ascending: false)
              .limit(100);
    return _list(rows).map(EpsLeader.fromRow).toList();
  }

  Future<List<EpsAnnouncement>> announcements() async => _list(
    await client
        .from('announcements')
        .select()
        .eq('active', true)
        .order('created_at', ascending: false),
  ).map(EpsAnnouncement.fromRow).toList();

  Future<List<EpsNotice>> notices(String userId) async {
    final rows = _list(
      await client
          .from('notifications')
          .select()
          .or('user_id.is.null,user_id.eq.$userId')
          .order('created_at', ascending: false)
          .limit(100),
    );
    final reads = _list(
      await client
          .from('notification_reads')
          .select('notification_id')
          .eq('user_id', userId),
    ).map((r) => _str(r['notification_id'])).toSet();
    return [
      for (final r in rows)
        EpsNotice.fromRow(r, read: reads.contains(_str(r['id']))),
    ];
  }

  Future<void> markNoticesRead(String userId, Iterable<String> ids) async {
    if (ids.isEmpty) {
      return;
    }
    await client.from('notification_reads').upsert([
      for (final id in ids) {'notification_id': id, 'user_id': userId},
    ]);
  }

  Future<int> assistantQuestionsToday(String userId) async {
    final rows = _list(
      await client
          .from('assistant_usage')
          .select('questions')
          .eq('user_id', userId)
          .eq('day', DateTime.now().toIso8601String().substring(0, 10)),
    );
    return rows.isEmpty ? 0 : _int(rows.first['questions']);
  }

  Future<String> askAssistant({
    required String userId,
    required List<Map<String, String>> messages,
    String? lessonTitle,
    String? subjectName,
  }) async {
    final response = await client.functions.invoke(
      'assistant',
      body: {
        'userId': userId,
        'messages': messages,
        'lessonTitle': lessonTitle,
        'subjectName': subjectName,
      },
    );
    final data = response.data;
    if (data is Map && data['reply'] != null) {
      return '${data['reply']}';
    }
    throw Exception(
      data is Map && data['message'] != null
          ? '${data['message']}'
          : 'تعذر الحصول على رد.',
    );
  }

  // Admin helpers ---------------------------------------------------------

  Future<void> upsert(String table, Map<String, dynamic> values) =>
      client.from(table).upsert(values);

  Future<void> insert(String table, Map<String, dynamic> values) =>
      client.from(table).insert(values);

  Future<void> update(String table, String id, Map<String, dynamic> values) =>
      client.from(table).update(values).eq('id', id);

  Future<void> delete(String table, String id) =>
      client.from(table).delete().eq('id', id);
}

// ---------------------------------------------------------------------------
// Store
// ---------------------------------------------------------------------------

class LearnStore extends ChangeNotifier {
  LearnStore({required this.enabled, LearnRepository? repository})
    : _repository = repository;

  /// False when the backend is not reachable (local/demo mode).
  final bool enabled;
  LearnRepository? _repository;
  LearnRepository get repo => _repository ??= LearnRepository();

  String? userId;
  EpsProfile? profile;
  List<EpsSubject> subjects = [];
  List<EpsTeacher> teachers = [];
  List<EpsPlan> plans = [];
  List<EpsSubscription> subscriptions = [];
  List<EpsLesson> lessons = [];
  Set<String> completedLessonIds = {};
  List<EpsExercise> exercises = [];
  List<EpsPdf> pdfs = [];
  List<EpsLiveSession> liveSessions = [];
  Set<String> reminders = {};
  List<EpsQuiz> quizzes = [];
  List<EpsAttempt> attempts = [];
  List<EpsAnnouncement> announcements = [];
  List<EpsNotice> notices = [];
  bool loading = false;
  String? error;

  /// Subjects chosen in the catalog before checkout.
  final Set<String> cart = {};
  String selectedPlanCode = 'monthly';

  /// Subject the student is currently browsing.
  String? currentSubjectId;

  /// Last submitted subscription batch, shown on the confirmation screen.
  List<EpsSubscription> lastRequest = [];

  /// Last finished quiz, shown on the result screen.
  EpsQuizResult? lastResult;

  /// Sample content used only when the backend is not connected (offline
  /// preview builds): quiz questions, live chat and leaderboard.
  final Map<String, List<EpsQuestion>> demoQuestions = {};
  final Map<String, List<EpsLiveMessage>> demoMessages = {};
  List<EpsLeader> demoLeaders = [];

  Future<void> load(String id) async {
    userId = id;
    if (!enabled) {
      return;
    }
    loading = true;
    error = null;
    notifyListeners();
    try {
      final results = await Future.wait<Object?>([
        repo.profile(id),
        repo.subjects(),
        repo.teachers(),
        repo.plans(),
        repo.subscriptions(studentId: id),
        repo.lessons(),
        repo.completedLessons(id),
        repo.exercises(),
        repo.pdfs(),
        repo.liveSessions(),
        repo.liveReminders(id),
        repo.quizzes(),
        repo.attempts(id),
        repo.announcements(),
        repo.notices(id),
      ]);
      profile = results[0] as EpsProfile?;
      subjects = (results[1]! as List<EpsSubject>)
          .where((s) => s.isActive)
          .toList();
      teachers = results[2]! as List<EpsTeacher>;
      plans = results[3]! as List<EpsPlan>;
      subscriptions = results[4]! as List<EpsSubscription>;
      lessons = (results[5]! as List<EpsLesson>)
          .where((l) => l.isPublished)
          .toList();
      completedLessonIds = results[6]! as Set<String>;
      exercises = results[7]! as List<EpsExercise>;
      pdfs = results[8]! as List<EpsPdf>;
      liveSessions = results[9]! as List<EpsLiveSession>;
      reminders = results[10]! as Set<String>;
      quizzes = results[11]! as List<EpsQuiz>;
      attempts = results[12]! as List<EpsAttempt>;
      announcements = results[13]! as List<EpsAnnouncement>;
      notices = results[14]! as List<EpsNotice>;
    } on Object catch (e) {
      error = '$e';
    } finally {
      loading = false;
      notifyListeners();
    }
  }

  Future<void> refresh() async {
    if (userId != null) {
      await load(userId!);
    }
  }

  void clear() {
    userId = null;
    profile = null;
    subscriptions = [];
    completedLessonIds = {};
    attempts = [];
    notices = [];
    cart.clear();
    notifyListeners();
  }

  // Lookups ---------------------------------------------------------------

  EpsSubject? subjectById(String? id) =>
      subjects.where((s) => s.id == id).firstOrNull;

  EpsTeacher? teacherById(String? id) =>
      teachers.where((t) => t.id == id).firstOrNull;

  EpsPlan? planByCode(String code) =>
      plans.where((p) => p.code == code).firstOrNull;

  EpsSubscription? subscriptionFor(String subjectId) =>
      subscriptions.where((s) => s.subjectId == subjectId).firstOrNull;

  List<EpsSubscription> withStatus(SubscriptionStatus status) =>
      subscriptions.where((s) => s.status == status).toList();

  bool hasAccess(String? subjectId) =>
      subjectId != null &&
      subscriptions.any(
        (s) =>
            s.subjectId == subjectId && s.status == SubscriptionStatus.active,
      );

  bool get isSubscribed =>
      subscriptions.any((s) => s.status == SubscriptionStatus.active);

  List<EpsSubject> get activeSubjects => [
    for (final s in subjects)
      if (hasAccess(s.id)) s,
  ];

  List<EpsLesson> lessonsFor(String subjectId) =>
      lessons.where((l) => l.subjectId == subjectId).toList()
        ..sort((a, b) => a.sortOrder.compareTo(b.sortOrder));

  List<EpsLesson> get freeLessons => lessons.where((l) => l.isFree).toList();

  List<EpsPdf> pdfsFor(String subjectId) =>
      pdfs.where((p) => p.subjectId == subjectId).toList();

  List<EpsExercise> exercisesFor(String lessonId) =>
      exercises.where((e) => e.lessonId == lessonId).toList();

  List<EpsQuiz> quizzesFor(String subjectId) =>
      quizzes.where((q) => q.subjectId == subjectId).toList();

  List<EpsLiveSession> liveFor(String subjectId) =>
      liveSessions.where((s) => s.subjectId == subjectId).toList();

  int progressFor(String subjectId) {
    final items = lessonsFor(subjectId);
    if (items.isEmpty) {
      return 0;
    }
    final done = items.where((l) => completedLessonIds.contains(l.id)).length;
    return (done * 100 / items.length).round();
  }

  bool canOpenLesson(EpsLesson lesson) =>
      lesson.isFree || hasAccess(lesson.subjectId);

  EpsQuiz? get dailyQuiz {
    final today = DateUtils.dateOnly(DateTime.now());
    return quizzes
            .where(
              (q) =>
                  q.kind == 'daily' &&
                  q.publishDate != null &&
                  DateUtils.isSameDay(q.publishDate, today),
            )
            .firstOrNull ??
        quizzes.where((q) => q.kind == 'daily').firstOrNull;
  }

  int get unreadNotices => notices.where((n) => !n.read).length;

  int get totalXp => profile?.xp ?? 0;

  int get correctAnswers => attempts.fold(0, (sum, a) => sum + a.correctCount);

  // Actions ---------------------------------------------------------------

  void toggleCart(String subjectId) {
    cart.contains(subjectId) ? cart.remove(subjectId) : cart.add(subjectId);
    notifyListeners();
  }

  void selectPlan(String code) {
    selectedPlanCode = code;
    notifyListeners();
  }

  void openSubject(String id) {
    currentSubjectId = id;
    notifyListeners();
  }

  List<EpsSubject> get cartSubjects => [
    for (final s in subjects)
      if (cart.contains(s.id)) s,
  ];

  int get cartMonthlyTotal =>
      cartSubjects.fold(0, (sum, s) => sum + s.monthlyPrice);

  Future<void> submitPayment({
    required String? paymentMethodId,
    required String receiptUrl,
    required String transactionRef,
  }) async {
    final plan = planByCode(selectedPlanCode) ?? plans.first;
    if (!enabled) {
      lastRequest = [
        for (final s in cartSubjects)
          EpsSubscription.fromRow({
            'id': 'local-${s.id}',
            'request_ref':
                'EPS-${DateTime.now().millisecondsSinceEpoch % 1000000}',
            'subject_id': s.id,
            'plan_code': plan.code,
            'amount': plan.priceFor(s.monthlyPrice),
            'status': 'pending',
          }),
      ];
      subscriptions = [
        ...lastRequest,
        for (final s in subscriptions)
          if (!cart.contains(s.subjectId)) s,
      ];
      cart.clear();
      notifyListeners();
      return;
    }
    lastRequest = await repo.requestSubscriptions(
      studentId: userId!,
      subjects: cartSubjects,
      plan: plan,
      paymentMethodId: paymentMethodId,
      receiptUrl: receiptUrl,
      transactionRef: transactionRef,
    );
    cart.clear();
    subscriptions = await repo.subscriptions(studentId: userId);
    notifyListeners();
  }

  Future<void> toggleLessonDone(EpsLesson lesson) async {
    final done = !completedLessonIds.contains(lesson.id);
    done
        ? completedLessonIds.add(lesson.id)
        : completedLessonIds.remove(lesson.id);
    notifyListeners();
    if (enabled) {
      await repo.setLessonCompleted(userId!, lesson.id, done);
    }
  }

  Future<void> toggleReminder(String sessionId) async {
    final on = !reminders.contains(sessionId);
    on ? reminders.add(sessionId) : reminders.remove(sessionId);
    notifyListeners();
    if (enabled) {
      await repo.setLiveReminder(userId!, sessionId, on);
    }
  }

  Future<void> finishQuiz({
    required EpsQuiz quiz,
    required List<EpsQuestion> questions,
    required List<int> answers,
    required int seconds,
  }) async {
    var correct = 0;
    for (var i = 0; i < questions.length; i++) {
      if (i < answers.length && answers[i] == questions[i].correctIndex) {
        correct++;
      }
    }
    final xp = questions.isEmpty
        ? 0
        : (quiz.xpReward * correct / questions.length).round() + correct * 10;
    final attempt = enabled
        ? await repo.recordAttempt(
            quizId: quiz.id,
            studentId: userId!,
            correct: correct,
            total: questions.length,
            xp: xp,
            seconds: seconds,
            answers: answers,
          )
        : EpsAttempt.fromRow({
            'id': 'local-${attempts.length}',
            'quiz_id': quiz.id,
            'correct_count': correct,
            'total': questions.length,
            'xp_earned': xp,
            'duration_seconds': seconds,
          });
    attempts = [attempt, ...attempts];
    lastResult = EpsQuizResult(
      quiz: quiz,
      questions: questions,
      answers: answers,
      attempt: attempt,
    );
    if (enabled) {
      profile = await repo.profile(userId!);
    }
    notifyListeners();
  }

  Future<void> markAllRead() async {
    final ids = [
      for (final n in notices)
        if (!n.read) n.id,
    ];
    for (final n in notices) {
      n.read = true;
    }
    notifyListeners();
    if (enabled) {
      await repo.markNoticesRead(userId!, ids);
    }
  }

  Future<void> saveProfile(Map<String, dynamic> values) async {
    if (!enabled) {
      return;
    }
    await repo.updateProfile(userId!, values);
    profile = await repo.profile(userId!);
    notifyListeners();
  }
}

class EpsQuizResult {
  EpsQuizResult({
    required this.quiz,
    required this.questions,
    required this.answers,
    required this.attempt,
  });

  final EpsQuiz quiz;
  final List<EpsQuestion> questions;
  final List<int> answers;
  final EpsAttempt attempt;
}

class LearnScope extends InheritedNotifier<LearnStore> {
  const LearnScope({
    required LearnStore super.notifier,
    required super.child,
    super.key,
  });

  static LearnStore of(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<LearnScope>()!.notifier!;

  static LearnStore read(BuildContext context) =>
      context.getInheritedWidgetOfExactType<LearnScope>()!.notifier!;
}
