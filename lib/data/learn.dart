import 'dart:typed_data';
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
      nameFr = _str(r['name_fr']),
      groupPrice = _int(r['group_price']),
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
  final String nameFr;
  // The price of the group alone (no lessons), set by the admin.
  final int groupPrice;
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

  /// The French name when the admin wrote one, else the Arabic name.
  String get displayName => nameFr.isNotEmpty ? nameFr : name;

  Map<String, dynamic> toRow() => {
    'course_id': courseId,
    'name_fr': nameFr,
    'group_price': groupPrice,
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
      active = r['active'] == null || _bool(r['active']),
      features = _strings(r['features']);

  final String code;
  final String title;
  final String subtitle;
  final String badge;
  final int months;
  final int discountPercent;
  final bool isFree;

  /// Plans switched off by the admin (only the yearly plan is offered).
  final bool active;
  final List<String> features;

  /// The plan costs the subjects' price, paid once (less the plan's
  /// discount, if the admin set one). Its months only set how long the
  /// subscription lasts.
  int priceFor(int subjectsTotal) {
    if (isFree) {
      return 0;
    }
    return (subjectsTotal * (100 - discountPercent) / 100).round();
  }
}

class EpsSubscription {
  EpsSubscription.fromRow(Map<String, dynamic> r)
    : id = _str(r['id']),
      ref = _str(r['request_ref']),
      studentId = _str(r['student_id']),
      subjectId = _str(r['subject_id']),
      planCode = _str(r['plan_code']),
      access = _str(r['access']) == 'groups' ? 'groups' : 'full',
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
  // 'full' (lessons, files and group) or 'groups' (the group only).
  final String access;
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

/// A faculty offered on upload. [label] is the full name shown to students.
class EpsFaculty {
  EpsFaculty.fromRow(Map<String, dynamic> r)
    : id = _str(r['id']),
      name = _str(r['name']),
      label = _str(r['label']).isEmpty ? _str(r['name']) : _str(r['label']),
      status = _str(r['status']);

  final String id;
  final String name;
  final String label;
  final String status;
}

/// A file shared by a student with their specialty; visible once approved.
/// One class in the student's university timetable.
class EpsTimetableItem {
  EpsTimetableItem.fromRow(Map<String, dynamic> r)
    : id = _str(r['id']),
      weekday = (r['weekday'] as num?)?.toInt() ?? 0,
      startsAt = _str(r['starts_at']).length >= 5
          ? _str(r['starts_at']).substring(0, 5)
          : _str(r['starts_at']),
      subjectName = _str(r['subject_name']),
      room = _str(r['room']);

  final String id;
  final int weekday; // 0 = Sunday ... 6 = Saturday
  final String startsAt; // HH:MM
  final String subjectName;
  final String room;
}

/// A file or image attached to a subject, or to one lesson of it.
class EpsAttachment {
  EpsAttachment.fromRow(Map<String, dynamic> r)
    : id = _str(r['id']),
      subjectId = _str(r['subject_id']),
      lessonId = r['lesson_id'] as String?,
      title = _str(r['title']),
      kind = _str(r['kind']),
      url = _str(r['url']);

  final String id;
  final String subjectId;
  final String? lessonId;
  final String title;
  final String kind; // pdf or image
  final String url;
  bool get isImage => kind == 'image';
}

/// A section (course): its title, what it offers, and its bundle price.
class EpsSection {
  EpsSection.fromRow(Map<String, dynamic> r)
    : id = _str(r['id']),
      title = _str(r['title']),
      description = _str(r['description']),
      features = [
        for (final f in (r['features'] as List? ?? const [])) '$f'.trim(),
      ].where((f) => f.isNotEmpty).toList(),
      bundlePrice = (r['bundle_price'] as num?)?.toInt() ?? 0,
      featurePrices = {
        'videos': _int(r['feature_videos_price']),
        'live': _int(r['feature_live_price']),
        'assistant': _int(r['feature_assistant_price']),
      };

  final String id;
  final String title;
  final String description;
  // The price of each feature of the section (groups, videos, live, assistant).
  // A price of 0 means the feature is not activated for this section yet.
  final Map<String, int> featurePrices;
  final List<String> features;
  final int bundlePrice;
}

/// The chat group of one subject (one per subject).
class EpsChatGroup {
  EpsChatGroup.fromRow(Map<String, dynamic> r)
    : id = _str(r['id']),
      subjectId = _str(r['subject_id']),
      name = _str(r['name']),
      price = _int(r['price']),
      active = r['active'] != false,
      locked = _bool(r['locked']),
      starred = _bool(r['starred']),
      pinnedId = r['pinned_message_id'] as String?;

  final String id;
  final String subjectId;
  // The name the admin or the teacher gave the group.
  final String name;
  // The subscription price of this group, set by the admin.
  final int price;
  final bool active;
  final bool locked;
  final bool starred;
  final String? pinnedId;
}

/// A student's subscription to one group.
class EpsGroupSub {
  EpsGroupSub.fromRow(Map<String, dynamic> r)
    : id = _str(r['id']),
      ref = _str(r['request_ref']),
      studentId = _str(r['student_id']),
      groupId = _str(r['group_id']),
      amount = _int(r['amount']),
      receiptUrl = _str(r['receipt_url']),
      transactionRef = _str(r['transaction_ref']),
      rawStatus = _status(_str(r['status'])),
      rejectionReason = _str(r['rejection_reason']),
      expiresAt = _date(r['expires_at']),
      createdAt = _date(r['created_at']) ?? DateTime.now();

  final String id;
  final String ref;
  final String studentId;
  final String groupId;
  final int amount;
  final String receiptUrl;
  final String transactionRef;
  final SubscriptionStatus rawStatus;
  final String rejectionReason;
  final DateTime? expiresAt;
  final DateTime createdAt;

  bool get isActive =>
      rawStatus == SubscriptionStatus.active &&
      (expiresAt == null || expiresAt!.isAfter(DateTime.now()));

  bool get isPending => rawStatus == SubscriptionStatus.pending;
}

/// One message in a subject's chat group.
class EpsChatMessage {
  EpsChatMessage.fromRow(Map<String, dynamic> r)
    : id = _str(r['id']),
      groupId = _str(r['group_id']),
      senderId = _str(r['sender_id']),
      senderName = _str(r['sender_name']),
      body = _str(r['body']),
      imageUrl = _str(r['image_url']),
      audioUrl = _str(r['audio_url']),
      audioSeconds = (r['audio_seconds'] as num?)?.toInt() ?? 0,
      videoUrl = _str(r['video_url']),
      pollQuestion = _str(r['poll_question']),
      pollOptions = [
        for (final o in (r['poll_options'] as List? ?? const [])) '$o',
      ],
      replyTo = r['reply_to'] as String?,
      createdAt = _date(r['created_at']) ?? DateTime.now().toUtc();

  final String id;
  final String groupId;
  final String senderId;
  final String senderName;
  final String body;
  final String imageUrl;
  final String audioUrl;
  final int audioSeconds;
  final String videoUrl;
  final String pollQuestion;
  final List<String> pollOptions;
  final String? replyTo;
  final DateTime createdAt;
}

/// One emoji reaction on a chat message (one per user and message).
class EpsChatReaction {
  EpsChatReaction.fromRow(Map<String, dynamic> r)
    : messageId = _str(r['message_id']),
      userId = _str(r['user_id']),
      emoji = _str(r['emoji']);

  final String messageId;
  final String userId;
  final String emoji;
}

class EpsStudentFile {
  EpsStudentFile.fromRow(Map<String, dynamic> r)
    : id = _str(r['id']),
      uploaderId = _str(r['uploader_id']),
      title = _str(r['title']),
      description = _str(r['description']),
      subjectId = _str(r['subject_id']),
      subjectName = _str(r['subject_name']),
      faculty = _str(r['faculty']),
      track = _str(r['track']),
      level = _str(r['level']),
      url = _str(r['file_url']),
      fileType = _str(r['file_type']),
      status = _str(r['status']),
      downloads = _int(r['downloads']),
      createdAt = _date(r['created_at']) ?? DateTime.now();

  final String id;
  final String uploaderId;
  final String title;
  final String description;
  final String subjectId;
  final String subjectName;
  final String faculty;
  final String track;
  final String level;
  final String url;
  final String fileType;
  final String status;
  final int downloads;
  final DateTime createdAt;

  bool get isPdf => fileType == 'pdf';
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

/// A student's subscription to one feature of a section (videos, live,
/// assistant or groups); the subject's group is kept separately.
class EpsSectionFeatureSub {
  EpsSectionFeatureSub.fromRow(Map<String, dynamic> r)
    : id = _str(r['id']),
      courseId = _str(r['course_id']),
      feature = _str(r['feature']),
      amount = _int(r['amount']),
      status = _str(r['status']),
      expiresAt = _date(r['expires_at']);

  final String id;
  final String courseId;
  final String feature;
  final int amount;
  final String status;
  final DateTime? expiresAt;

  bool get isActive =>
      status == 'active' &&
      (expiresAt == null || expiresAt!.isAfter(DateTime.now()));

  bool get isPending => status == 'pending';
}

/// A private conversation between a student and a teacher.
class EpsDirectThread {
  EpsDirectThread.fromRow(Map<String, dynamic> r)
    : id = _str(r['id']),
      studentId = _str(r['student_id']),
      teacherId = _str(r['teacher_id']),
      lastAt = _date(r['last_message_at']) ?? DateTime.now();

  final String id;
  final String studentId;
  final String teacherId;
  final DateTime lastAt;
}

/// One private message; `forwarded` when the teacher posted it in the group.
class EpsDirectMessage {
  EpsDirectMessage.fromRow(Map<String, dynamic> r)
    : id = _str(r['id']),
      threadId = _str(r['thread_id']),
      senderId = _str(r['sender_id']),
      body = _str(r['body']),
      imageUrl = _str(r['image_url']),
      forwarded = _bool(r['forwarded']),
      createdAt = _date(r['created_at']) ?? DateTime.now();

  final String id;
  final String threadId;
  final String senderId;
  final String body;
  final String imageUrl;
  final bool forwarded;
  final DateTime createdAt;
}

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
      attendees = _int(r['attendees_count']),
      roomName = _str(r['room_name']),
      startedAt = _date(r['started_at']),
      endedAt = _date(r['ended_at']);

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
  final String roomName;
  final DateTime? startedAt;
  final DateTime? endedAt;

  /// Broadcast through LiveKit inside the app (no external link set).
  bool get usesLiveKit => liveUrl.trim().isEmpty;

  DateTime get endsAt => startsAt.add(Duration(minutes: durationMinutes));

  LiveState get state {
    final now = DateTime.now();
    if (isLiveFlag) {
      return LiveState.live;
    }
    if (endedAt != null) {
      return LiveState.past;
    }
    if (now.isAfter(startsAt) && now.isBefore(endsAt)) {
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
      answered = _bool(r['answered']),
      body = _str(r['body']),
      createdAt = _date(r['created_at']) ?? DateTime.now();

  final String id;
  final String userId;
  final String userName;
  final bool isTeacher;
  final bool isQuestion;
  final bool answered;
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
      profileCompleted = _bool(r['profile_completed']),
      referralCode = _str(r['referral_code']);

  final String id;
  final String name;
  final String phone;
  final String referralCode;
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

  Future<List<EpsSection>> sections() async => (await _select(
    'courses',
    order: 'created_at',
  )).map(EpsSection.fromRow).toList();

  /// The admin's changes to a section: title, description, what it offers,
  /// and the bundle price.
  Future<void> saveSection({
    required String id,
    required String title,
    required String description,
    required List<String> features,
    required int bundlePrice,
    Map<String, int> featurePrices = const {},
  }) async {
    await client
        .from('courses')
        .update({
          'title': title.trim(),
          'description': description.trim(),
          'features': features,
          'bundle_price': bundlePrice,
          'feature_videos_price': featurePrices['videos'] ?? 0,
          'feature_live_price': featurePrices['live'] ?? 0,
          'feature_assistant_price': featurePrices['assistant'] ?? 0,
        })
        .eq('id', id);
  }

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
    Map<String, int>? amounts,
    required EpsPlan plan,
    required String? paymentMethodId,
    required String receiptUrl,
    required String transactionRef,
    String access = 'full',
  }) async {
    final payload = [
      for (final subject in subjects)
        {
          'student_id': studentId,
          'subject_id': subject.id,
          'access': access,
          'plan_code': plan.code,
          'amount': plan.priceFor(
            amounts?[subject.id] ??
                (access == 'groups'
                    ? subject.groupPrice
                    : subject.monthlyPrice),
          ),
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

  Future<List<EpsSectionFeatureSub>> sectionFeatureSubscriptions({
    required String studentId,
  }) async => _list(
    await client
        .from('section_feature_subscriptions')
        .select()
        .eq('student_id', studentId)
        .order('created_at', ascending: false),
  ).map(EpsSectionFeatureSub.fromRow).toList();

  /// One request per student, section and feature; a new request replaces an
  /// earlier pending or rejected one.
  Future<void> requestSectionFeature({
    required String studentId,
    required String courseId,
    required String feature,
    required int amount,
    required String? paymentMethodId,
    required String receiptUrl,
    required String transactionRef,
  }) async {
    await client
        .from('section_feature_subscriptions')
        .delete()
        .eq('student_id', studentId)
        .eq('course_id', courseId)
        .eq('feature', feature)
        .inFilter('status', ['pending', 'rejected']);
    await client.from('section_feature_subscriptions').insert({
      'student_id': studentId,
      'course_id': courseId,
      'feature': feature,
      'amount': amount,
      'payment_method_id': paymentMethodId,
      'receipt_url': receiptUrl,
      'transaction_ref': transactionRef,
      'status': 'pending',
    });
  }

  /// Sets the student's username: lowercase letters, digits or _, 3 to 20.
  Future<void> setUsername(String userId, String username) async {
    final u = username.trim().toLowerCase();
    if (!RegExp(r'^[a-z0-9_]{3,20}$').hasMatch(u)) {
      throw StateError(
        'اسم المستخدم من 3 إلى 20 حرفاً إنجليزياً أو رقماً أو _',
      );
    }
    await client.from('users').update({'username': u}).eq('id', userId);
  }

  /// The private conversation of a student and a teacher, created on first use.
  Future<EpsDirectThread> directThread({
    required String studentId,
    required String teacherId,
  }) async {
    final rows = _list(
      await client.from('direct_threads').upsert({
        'student_id': studentId,
        'teacher_id': teacherId,
      }, onConflict: 'student_id,teacher_id').select(),
    );
    return EpsDirectThread.fromRow(rows.first);
  }

  /// The conversations of a user, newest first (as a student or a teacher).
  Future<List<EpsDirectThread>> directThreadsFor(String userId) async {
    final rows = _list(
      await client
          .from('direct_threads')
          .select()
          .or('student_id.eq.$userId,teacher_id.eq.$userId')
          .order('last_message_at', ascending: false),
    );
    return rows.map(EpsDirectThread.fromRow).toList();
  }

  Future<List<EpsDirectMessage>> directMessages(String threadId) async => _list(
    await client
        .from('direct_messages')
        .select()
        .eq('thread_id', threadId)
        .order('created_at', ascending: true),
  ).map(EpsDirectMessage.fromRow).toList();

  Future<void> sendDirectMessage({
    required String threadId,
    required String senderId,
    required String body,
  }) async {
    await client.from('direct_messages').insert({
      'thread_id': threadId,
      'sender_id': senderId,
      'body': body.trim(),
    });
    await client
        .from('direct_threads')
        .update({'last_message_at': DateTime.now().toUtc().toIso8601String()})
        .eq('id', threadId);
  }

  /// The teacher posts a private message in the group, with the sender's
  /// username, and the private message is marked as forwarded.
  Future<void> forwardDirectToGroup({
    required EpsDirectMessage message,
    required String groupId,
    required String teacherId,
    required String teacherName,
  }) async {
    await client.from('chat_messages').insert({
      'group_id': groupId,
      'sender_id': teacherId,
      'sender_name': teacherName,
      'body': message.body,
    });
    await client
        .from('direct_messages')
        .update({'forwarded': true})
        .eq('id', message.id);
  }

  Future<List<Map<String, dynamic>>> assistantPackageRows() async => _list(
    await client.from('assistant_packages').select().order('sort_order'),
  );

  /// Changes the price columns of one row (subjects, courses or packages).
  Future<void> updateRowBy({
    required String table,
    required String column,
    required String key,
    required Map<String, dynamic> values,
  }) => client.from(table).update(values).eq(column, key);

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

  /// The student's assistant allowance left today and this month, as
  /// percentages (the assistant function works in tokens).
  Future<({int dailyLeftPct, int monthlyLeftPct})?> assistantBalance(
    String userId,
  ) async {
    try {
      final response = await client.functions.invoke(
        'assistant',
        body: {'userId': userId, 'action': 'balance'},
      );
      final data = response.data;
      if (data is Map && data['dailyLeftPct'] is num) {
        return (
          dailyLeftPct: (data['dailyLeftPct'] as num).toInt(),
          monthlyLeftPct: ((data['monthlyLeftPct'] as num?) ?? 0).toInt(),
        );
      }
    } on Object {
      // Shown as unknown until the next answer.
    }
    return null;
  }

  /// Faculties offered to students (approved only).
  Future<List<EpsFaculty>> approvedFaculties() async =>
      (await client
              .from('faculties')
              .select()
              .eq('status', 'approved')
              .order('name'))
          .map((r) => EpsFaculty.fromRow(Map<String, dynamic>.from(r)))
          .toList();

  /// Every faculty, for the administration (pending first).
  Future<List<EpsFaculty>> allFaculties() async => _list(
    await client.from('faculties').select().order('created_at'),
  ).map(EpsFaculty.fromRow).toList();

  /// A student suggests a faculty that is missing; it waits for approval.
  Future<void> suggestFaculty(String name, String userId) async {
    final existing = _list(
      await client
          .from('faculties')
          .select('id')
          .eq('name', name.trim())
          .limit(1),
    );
    if (existing.isNotEmpty) {
      return;
    }
    await client.from('faculties').insert({
      'name': name.trim(),
      'status': 'pending',
      'suggested_by': userId,
    });
  }

  Future<void> setFacultyStatus(String id, String status) =>
      client.from('faculties').update({'status': status}).eq('id', id);

  /// Approved files of a specialty (faculty, track and level). An empty
  /// value leaves that part unfiltered.
  Future<List<EpsStudentFile>> studentFiles({
    String faculty = '',
    String track = '',
    String level = '',
  }) async {
    var query = client.from('student_files').select().eq('status', 'approved');
    if (faculty.isNotEmpty) query = query.eq('faculty', faculty);
    if (track.isNotEmpty) query = query.eq('track', track);
    if (level.isNotEmpty) query = query.eq('level', level);
    final rows = _list(
      await query.order('created_at', ascending: false).limit(200),
    );
    return rows.map(EpsStudentFile.fromRow).toList();
  }

  /// The student's timetable, ordered by day and start time.
  Future<List<EpsTimetableItem>> myTimetable(String userId) async => _list(
    await client
        .from('student_timetable')
        .select()
        .eq('student_id', userId)
        .order('weekday')
        .order('starts_at'),
  ).map(EpsTimetableItem.fromRow).toList();

  Future<void> addTimetableItem({
    required String userId,
    required int weekday,
    required String startsAt,
    required String subjectName,
    String room = '',
  }) async {
    await client.from('student_timetable').insert({
      'student_id': userId,
      'weekday': weekday,
      'starts_at': startsAt,
      'subject_name': subjectName.trim(),
      'room': room.trim(),
    });
  }

  /// Changes a class: its subject, room, day or start time.
  Future<void> updateTimetableItem({
    required String id,
    required int weekday,
    required String startsAt,
    required String subjectName,
    String room = '',
  }) async {
    await client
        .from('student_timetable')
        .update({
          'weekday': weekday,
          'starts_at': startsAt,
          'subject_name': subjectName.trim(),
          'room': room.trim(),
        })
        .eq('id', id);
  }

  /// A student's request to buy an assistant package, with the receipt.
  Future<void> submitAssistantRequest({
    required String userId,
    required String tier,
    required String period,
    required int amount,
    required String? paymentMethodId,
    required String receiptUrl,
    required String transactionRef,
  }) async {
    await client.from('assistant_subscriptions').insert({
      'student_id': userId,
      'tier': tier,
      'period': period,
      'amount': amount,
      'payment_method_id': paymentMethodId,
      'receipt_url': receiptUrl,
      'transaction_ref': transactionRef.trim(),
      'status': 'pending',
    });
  }

  /// Every assistant package request, newest first, with the student's name.
  Future<List<Map<String, dynamic>>> assistantRequests() async => _list(
    await client
        .from('assistant_subscriptions')
        .select('*, student:users(name, phone)')
        .order('created_at', ascending: false)
        .limit(200),
  );

  Future<void> reviewAssistantRequest({
    required String id,
    required bool approve,
    String reason = '',
  }) async {
    await client
        .from('assistant_subscriptions')
        .update({
          'status': approve ? 'active' : 'rejected',
          'rejection_reason': approve ? '' : reason,
        })
        .eq('id', id);
  }

  /// Files attached to one lesson.
  Future<List<EpsAttachment>> lessonAttachments(String lessonId) async => _list(
    await client
        .from('lesson_attachments')
        .select()
        .eq('lesson_id', lessonId)
        .order('sort_order')
        .order('created_at'),
  ).map(EpsAttachment.fromRow).toList();

  /// Subject files: attached to the subject, not to one lesson.
  Future<List<EpsAttachment>> subjectFiles(String subjectId) async => _list(
    await client
        .from('lesson_attachments')
        .select()
        .eq('subject_id', subjectId)
        .isFilter('lesson_id', null)
        .order('sort_order')
        .order('created_at'),
  ).map(EpsAttachment.fromRow).toList();

  /// Every attachment of a subject (admin view).
  Future<List<EpsAttachment>> allAttachments(String subjectId) async => _list(
    await client
        .from('lesson_attachments')
        .select()
        .eq('subject_id', subjectId)
        .order('created_at', ascending: false),
  ).map(EpsAttachment.fromRow).toList();

  Future<void> addAttachment({
    required String subjectId,
    required String? lessonId,
    required String title,
    required Uint8List bytes,
    required String fileName,
  }) async {
    final ext = fileName.contains('.')
        ? fileName.split('.').last.toLowerCase()
        : 'pdf';
    final mime = switch (ext) {
      'png' => 'image/png',
      'jpg' || 'jpeg' => 'image/jpeg',
      'webp' => 'image/webp',
      _ => 'application/pdf',
    };
    final kind = mime == 'application/pdf' ? 'pdf' : 'image';
    final path =
        '$subjectId/${DateTime.now().millisecondsSinceEpoch}.${kind == 'pdf' ? 'pdf' : ext}';
    final bucket = client.storage.from('lesson-files');
    await bucket.uploadBinary(
      path,
      bytes,
      fileOptions: FileOptions(contentType: mime, upsert: false),
    );
    await client.from('lesson_attachments').insert({
      'subject_id': subjectId,
      'lesson_id': lessonId,
      'title': title.trim(),
      'kind': kind,
      'url': bucket.getPublicUrl(path),
    });
  }

  Future<void> deleteAttachment(String id) async {
    await client.from('lesson_attachments').delete().eq('id', id);
  }

  /// The chat group of a subject, created the first time it is needed.
  Future<EpsChatGroup> chatGroupFor(String subjectId) async {
    final row = await client
        .from('chat_groups')
        .upsert({'subject_id': subjectId}, onConflict: 'subject_id')
        .select()
        .single();
    return EpsChatGroup.fromRow(Map<String, dynamic>.from(row));
  }

  /// Messages of a group, or only the ones after [after] when polling.
  Future<List<EpsChatMessage>> chatMessages(
    String groupId, {
    DateTime? after,
  }) async {
    // The whole history, oldest first, in pages: a new subscriber must see
    // everything the teacher posted, including the voice notes and images.
    const page = 500;
    final out = <EpsChatMessage>[];
    var from = 0;
    while (true) {
      var query = client.from('chat_messages').select().eq('group_id', groupId);
      if (after != null) {
        query = query.gt('created_at', after.toUtc().toIso8601String());
      }
      final rows = _list(
        await query.order('created_at').range(from, from + page - 1),
      );
      out.addAll(rows.map(EpsChatMessage.fromRow));
      if (rows.length < page) break;
      from += page;
    }
    return out;
  }

  Future<void> sendChatMessage({
    required String groupId,
    required String senderId,
    required String senderName,
    required String body,
    Uint8List? image,
    String? imageName,
    String? replyToId,
  }) async {
    var url = '';
    if (image != null) {
      final ext = (imageName ?? 'jpg').split('.').last.toLowerCase();
      final mime = switch (ext) {
        'png' => 'image/png',
        'webp' => 'image/webp',
        _ => 'image/jpeg',
      };
      final path =
          '$groupId/${DateTime.now().millisecondsSinceEpoch}.${ext == 'png' || ext == 'webp' ? ext : 'jpg'}';
      final bucket = client.storage.from('chat-images');
      await bucket.uploadBinary(
        path,
        image,
        fileOptions: FileOptions(contentType: mime, upsert: false),
      );
      url = bucket.getPublicUrl(path);
    }
    await client.from('chat_messages').insert({
      'group_id': groupId,
      'sender_id': senderId,
      'sender_name': senderName,
      'body': body.trim(),
      'image_url': url,
      'reply_to': replyToId,
    });
  }

  /// A video (uploaded or recorded by the teacher), sent to the group.
  Future<void> sendChatVideo({
    required String groupId,
    required String senderId,
    required String senderName,
    required Uint8List bytes,
    required String extension,
    String caption = '',
  }) async {
    final ext = extension.toLowerCase();
    final mime = switch (ext) {
      'mov' => 'video/quicktime',
      'webm' => 'video/webm',
      '3gp' => 'video/3gpp',
      _ => 'video/mp4',
    };
    final path = '$groupId/${DateTime.now().millisecondsSinceEpoch}.$ext';
    final bucket = client.storage.from('chat-videos');
    await bucket.uploadBinary(
      path,
      bytes,
      fileOptions: FileOptions(contentType: mime, upsert: false),
    );
    await client.from('chat_messages').insert({
      'group_id': groupId,
      'sender_id': senderId,
      'sender_name': senderName,
      'body': caption.trim(),
      'video_url': bucket.getPublicUrl(path),
    });
  }

  /// A voice note: the audio file, then the message that points to it.
  Future<void> sendChatVoice({
    required String groupId,
    required String senderId,
    required String senderName,
    required Uint8List bytes,
    required int seconds,
    required String extension,
  }) async {
    final ext = extension.toLowerCase();
    final mime = switch (ext) {
      'webm' => 'audio/webm',
      'ogg' => 'audio/ogg',
      'wav' => 'audio/wav',
      _ => 'audio/mp4',
    };
    final path = '$groupId/${DateTime.now().millisecondsSinceEpoch}.$ext';
    final bucket = client.storage.from('chat-audio');
    await bucket.uploadBinary(
      path,
      bytes,
      fileOptions: FileOptions(contentType: mime, upsert: false),
    );
    await client.from('chat_messages').insert({
      'group_id': groupId,
      'sender_id': senderId,
      'sender_name': senderName,
      'body': '',
      'audio_url': bucket.getPublicUrl(path),
      'audio_seconds': seconds,
    });
  }

  /// The reactions of some messages (one query for the whole list).
  Future<List<EpsChatReaction>> chatReactions(List<String> messageIds) async {
    if (messageIds.isEmpty) return [];
    final rows = await client
        .from('chat_reactions')
        .select()
        .inFilter('message_id', messageIds);
    return _list(rows).map(EpsChatReaction.fromRow).toList();
  }

  /// Tap an emoji: adds it, or removes it when it is the same one again.
  /// A user has one reaction per message, so a new emoji replaces the old.
  Future<void> toggleChatReaction({
    required String messageId,
    required String userId,
    required String emoji,
    required bool removeSame,
  }) async {
    if (removeSame) {
      await client
          .from('chat_reactions')
          .delete()
          .eq('message_id', messageId)
          .eq('user_id', userId);
      return;
    }
    await client.from('chat_reactions').upsert({
      'message_id': messageId,
      'user_id': userId,
      'emoji': emoji,
    }, onConflict: 'message_id,user_id');
  }

  /// Name and photo of some users (the senders of a chat).
  Future<Map<String, ({String name, String photo})>> usersById(
    List<String> ids,
  ) async {
    if (ids.isEmpty) return {};
    final rows = _list(
      await client
          .from('users')
          .select('id, name, avatar_url')
          .inFilter('id', ids.toSet().toList()),
    );
    return {
      for (final r in rows)
        _str(r['id']): (name: _str(r['name']), photo: _str(r['avatar_url'])),
    };
  }

  /// The students with an active subscription to a subject: the class of the
  /// group, shown to the members.
  Future<List<({String id, String name, String photo})>> subjectStudents(
    String subjectId,
  ) async {
    final rows = _list(
      await client
          .from('subject_subscriptions')
          .select('student:users(id, name, avatar_url)')
          .eq('subject_id', subjectId)
          .eq('status', 'active'),
    );
    final out = <({String id, String name, String photo})>[];
    for (final r in rows) {
      final u = r['student'];
      if (u is Map) {
        out.add((
          id: _str(u['id']),
          name: _str(u['name']),
          photo: _str(u['avatar_url']),
        ));
      }
    }
    out.sort((a, b) => a.name.compareTo(b.name));
    return out;
  }

  /// The chat groups of some subjects (a group may not exist yet).
  Future<EpsChatGroup> chatGroupById(String id) async {
    final row = await client.from('chat_groups').select().eq('id', id).single();
    return EpsChatGroup.fromRow(Map<String, dynamic>.from(row));
  }

  /// Every group, oldest first.
  Future<List<EpsChatGroup>> allChatGroups() async => _list(
    await client.from('chat_groups').select().order('created_at'),
  ).map(EpsChatGroup.fromRow).toList();

  /// The admin or the teacher adds a group to a subject.
  Future<EpsChatGroup> createChatGroup({
    required String subjectId,
    required String name,
    required int price,
    String? createdBy,
  }) async {
    final row = await client
        .from('chat_groups')
        .insert({
          'subject_id': subjectId,
          'name': name.trim(),
          'price': price,
          'created_by': createdBy,
        })
        .select()
        .single();
    return EpsChatGroup.fromRow(Map<String, dynamic>.from(row));
  }

  /// The admin sets the price; the admin or the teacher sets the name.
  Future<void> updateChatGroup(String id, {String? name, int? price}) => client
      .from('chat_groups')
      .update({
        if (name != null) 'name': name.trim(),
        if (price != null) 'price': price,
      })
      .eq('id', id);

  Future<List<EpsGroupSub>> groupSubscriptions({String? studentId}) async {
    var query = client.from('group_subscriptions').select();
    if (studentId != null) {
      query = query.eq('student_id', studentId);
    }
    return _list(
      await query.order('created_at', ascending: false),
    ).map(EpsGroupSub.fromRow).toList();
  }

  /// A student pays for one group; a new request replaces an earlier pending one.
  Future<void> requestGroupSubscription({
    required String studentId,
    required EpsChatGroup group,
    required String? paymentMethodId,
    required String receiptUrl,
    required String transactionRef,
  }) async {
    await client
        .from('group_subscriptions')
        .delete()
        .eq('student_id', studentId)
        .eq('group_id', group.id)
        .inFilter('status', ['pending', 'rejected']);
    await client.from('group_subscriptions').insert({
      'student_id': studentId,
      'group_id': group.id,
      'amount': group.price,
      'payment_method_id': paymentMethodId,
      'receipt_url': receiptUrl,
      'transaction_ref': transactionRef,
      'status': 'pending',
    });
  }

  /// The admin accepts or rejects a group payment; an accepted one lasts a month.
  Future<void> reviewGroupSubscription({
    required EpsGroupSub sub,
    required bool approve,
    String reason = '',
  }) {
    final now = DateTime.now().toUtc();
    return client
        .from('group_subscriptions')
        .update({
          'status': approve ? 'active' : 'rejected',
          'rejection_reason': approve ? '' : reason,
          'reviewed_at': now.toIso8601String(),
          if (approve) 'starts_at': now.toIso8601String(),
          if (approve)
            'expires_at': DateTime(
              now.year,
              now.month + 1,
              now.day,
            ).toUtc().toIso8601String(),
        })
        .eq('id', sub.id);
  }

  Future<List<EpsChatGroup>> chatGroupsFor(List<String> subjectIds) async {
    if (subjectIds.isEmpty) return [];
    final rows = await client
        .from('chat_groups')
        .select()
        .inFilter('subject_id', subjectIds);
    return _list(rows).map(EpsChatGroup.fromRow).toList();
  }

  /// The latest messages of some groups, newest first (used for previews).
  Future<List<EpsChatMessage>> latestChatMessages(List<String> groupIds) async {
    if (groupIds.isEmpty) return [];
    final rows = await client
        .from('chat_messages')
        .select()
        .inFilter('group_id', groupIds)
        .order('created_at', ascending: false)
        .limit(300);
    return _list(rows).map(EpsChatMessage.fromRow).toList();
  }

  /// A poll: a question and its options.
  Future<void> sendChatPoll({
    required String groupId,
    required String senderId,
    required String senderName,
    required String question,
    required List<String> options,
  }) async {
    await client.from('chat_messages').insert({
      'group_id': groupId,
      'sender_id': senderId,
      'sender_name': senderName,
      'body': '',
      'poll_question': question.trim(),
      'poll_options': options,
    });
  }

  /// The votes of some polls.
  Future<List<({String messageId, String userId, int option})>> pollVotes(
    List<String> messageIds,
  ) async {
    if (messageIds.isEmpty) return [];
    final rows = _list(
      await client
          .from('chat_poll_votes')
          .select()
          .inFilter('message_id', messageIds),
    );
    return [
      for (final r in rows)
        (
          messageId: _str(r['message_id']),
          userId: _str(r['user_id']),
          option: (r['option_index'] as num?)?.toInt() ?? 0,
        ),
    ];
  }

  /// One vote per user and poll: voting again changes the choice.
  Future<void> votePoll({
    required String messageId,
    required String userId,
    required int option,
  }) async {
    await client.from('chat_poll_votes').upsert({
      'message_id': messageId,
      'user_id': userId,
      'option_index': option,
    }, onConflict: 'message_id,user_id');
  }

  /// Marks this user as present in the group (called about once a minute).
  Future<void> touchPresence(String groupId, String userId) async {
    await client.from('chat_presence').upsert({
      'group_id': groupId,
      'user_id': userId,
      'seen_at': DateTime.now().toUtc().toIso8601String(),
    }, onConflict: 'group_id,user_id');
  }

  /// How many people were in the group in the last two minutes.
  Future<int> onlineCount(String groupId) async {
    final since = DateTime.now().toUtc().subtract(const Duration(minutes: 2));
    final rows = _list(
      await client
          .from('chat_presence')
          .select('user_id')
          .eq('group_id', groupId)
          .gte('seen_at', since.toIso8601String()),
    );
    return rows.length;
  }

  /// Teacher only: pin a message at the top of the group, or unpin it (null).
  Future<void> setPinnedMessage(String groupId, String? messageId) async {
    await client
        .from('chat_groups')
        .update({'pinned_message_id': messageId})
        .eq('id', groupId);
  }

  /// Teacher only: put the group first in the students' list, or take it back.
  Future<void> setChatStarred(String groupId, bool starred) async {
    await client
        .from('chat_groups')
        .update({'starred': starred})
        .eq('id', groupId);
  }

  /// Teacher only: lock the group (students cannot post) or unlock it.
  Future<void> setChatLocked(String groupId, bool locked) async {
    await client
        .from('chat_groups')
        .update({'locked': locked})
        .eq('id', groupId);
  }

  Future<void> deleteTimetableItem(String id) async {
    await client.from('student_timetable').delete().eq('id', id);
  }

  /// Every file a student uploaded, whatever its status.
  Future<List<EpsStudentFile>> myStudentFiles(String userId) async => _list(
    await client
        .from('student_files')
        .select()
        .eq('uploader_id', userId)
        .order('created_at', ascending: false),
  ).map(EpsStudentFile.fromRow).toList();

  /// Uploads a file to the student-files bucket and records it as pending.
  Future<void> uploadStudentFile({
    required String userId,
    required String title,
    required String description,
    required String subjectId,
    required String subjectName,
    required String faculty,
    required String track,
    required String level,
    required Uint8List bytes,
    required String fileName,
  }) async {
    final ext = fileName.contains('.')
        ? fileName.split('.').last.toLowerCase()
        : 'pdf';
    final mime = switch (ext) {
      'png' => 'image/png',
      'jpg' || 'jpeg' => 'image/jpeg',
      'webp' => 'image/webp',
      _ => 'application/pdf',
    };
    final fileType = mime == 'application/pdf' ? 'pdf' : 'image';
    final path =
        '$userId/${DateTime.now().millisecondsSinceEpoch}.${fileType == 'pdf' ? 'pdf' : ext}';
    final bucket = client.storage.from('student-files');
    await bucket.uploadBinary(
      path,
      bytes,
      fileOptions: FileOptions(contentType: mime, upsert: false),
    );
    await client.from('student_files').insert({
      'uploader_id': userId,
      'title': title.trim(),
      'description': description.trim(),
      'subject_id': subjectId.isEmpty ? null : subjectId,
      'subject_name': subjectName.trim(),
      'faculty': faculty,
      'track': track,
      'level': level,
      'file_path': path,
      'file_url': bucket.getPublicUrl(path),
      'file_type': fileType,
      'size_bytes': bytes.length,
    });
  }

  Future<void> setStudentFileStatus(String id, String status) =>
      client.from('student_files').update({'status': status}).eq('id', id);

  /// Calls the `livekit` edge function: `token`, `start`, `record`, `end`.
  Future<Map<String, dynamic>> liveKit(
    String action, {
    required String userId,
    required String sessionId,
    int? peakViewers,
  }) async {
    try {
      final response = await client.functions.invoke(
        'livekit',
        body: {
          'action': action,
          'userId': userId,
          'sessionId': sessionId,
          'peakViewers': ?peakViewers,
        },
      );
      final data = response.data;
      return data is Map ? Map<String, dynamic>.from(data) : {};
    } on FunctionException catch (e) {
      final details = e.details;
      throw Exception(
        details is Map && details['message'] != null
            ? '${details['message']}'
            : 'تعذر الاتصال بخدمة البث.',
      );
    }
  }

  Future<EpsLiveSession?> liveSession(String id) async {
    final rows = _list(
      await client.from('live_sessions').select().eq('id', id).limit(1),
    );
    return rows.isEmpty ? null : EpsLiveSession.fromRow(rows.first);
  }

  /// Sessions a teacher hosts (or every session for an admin).
  Future<List<EpsLiveSession>> hostedSessions(String? teacherId) async {
    var query = client.from('live_sessions').select();
    if (teacherId != null) {
      query = query.or('teacher_id.eq.$teacherId,teacher_id.is.null');
    }
    return _list(
      await query.order('starts_at', ascending: false).limit(60),
    ).map(EpsLiveSession.fromRow).toList();
  }

  Future<void> createLiveSession(Map<String, dynamic> values) =>
      client.from('live_sessions').insert(values);

  Future<void> setQuestionAnswered(String messageId, bool answered) => client
      .from('live_messages')
      .update({'answered': answered})
      .eq('id', messageId);

  /// Pushes chat changes of one session as they happen.
  RealtimeChannel watchLiveMessages(String sessionId, VoidCallback onChange) =>
      client
          .channel('live-messages-$sessionId')
          .onPostgresChanges(
            event: PostgresChangeEvent.all,
            schema: 'public',
            table: 'live_messages',
            filter: PostgresChangeFilter(
              type: PostgresChangeFilterType.eq,
              column: 'session_id',
              value: sessionId,
            ),
            callback: (_) => onChange(),
          )
          .onPostgresChanges(
            event: PostgresChangeEvent.update,
            schema: 'public',
            table: 'live_sessions',
            filter: PostgresChangeFilter(
              type: PostgresChangeFilterType.eq,
              column: 'id',
              value: sessionId,
            ),
            callback: (_) => onChange(),
          )
          .subscribe();

  /// Asks the assistant. [image] (a data URI) goes with the last question.
  Future<({String reply, int? dailyLeftPct, int? monthlyLeftPct})>
  askAssistant({
    required String userId,
    required List<Map<String, String>> messages,
    String? lessonTitle,
    String? subjectName,
    String? image,
    String? document,
    String? documentName,
    String mode = 'solve',
    String? studentLevel,
    String? studentName,
    String? lessonSummary,
  }) async {
    Object? data;
    try {
      final response = await client.functions.invoke(
        'assistant',
        body: {
          'userId': userId,
          'messages': messages,
          'lessonTitle': lessonTitle,
          'subjectName': subjectName,
          'image': ?image,
          'document': ?document,
          'documentName': ?documentName,
          'mode': mode,
          'studentLevel': ?studentLevel,
          'studentName': ?studentName,
          'lessonSummary': ?lessonSummary,
        },
      );
      data = response.data;
    } on FunctionException catch (e) {
      data = e.details;
    }
    if (data is Map && data['reply'] != null) {
      int? n(Object? v) => v is num ? v.toInt() : null;
      return (
        reply: '${data['reply']}',
        dailyLeftPct: n(data['dailyLeftPct']),
        monthlyLeftPct: n(data['monthlyLeftPct']),
      );
    }
    throw Exception(
      data is Map && data['message'] != null
          ? '${data['message']}'
          : 'تعذر الحصول على رد.',
    );
  }

  Future<String> setting(String key, {required String fallback}) async {
    final rows = _list(
      await client.from('app_settings').select('value').eq('key', key),
    );
    final value = rows.isEmpty ? '' : _str(rows.first['value']).trim();
    return value.isEmpty ? fallback : value;
  }

  Future<void> saveSetting(String key, String value) =>
      client.from('app_settings').upsert({
        'key': key,
        'value': value,
        'updated_at': DateTime.now().toUtc().toIso8601String(),
      });

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
  List<EpsSectionFeatureSub> featureSubs = [];
  // Every group, and the student's subscriptions to groups.
  List<EpsChatGroup> chatGroups = [];
  List<EpsGroupSub> groupSubs = [];
  // The assistant packages as the admin set them (empty: the built-in ones).
  List<Map<String, dynamic>> packageRows = [];
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
  String selectedPlanCode = 'yearly';

  /// Offered plans, and the selected one kept among them.
  void _setPlans(List<EpsPlan> all) {
    plans = all.where((p) => p.active).toList();
    if (!plans.any((p) => p.code == selectedPlanCode)) {
      final paid = plans.where((p) => !p.isFree).firstOrNull;
      if (paid != null) {
        selectedPlanCode = paid.code;
      }
    }
  }

  /// Subjects open for subscription: those with at least one lesson. The
  /// status changes on its own as soon as lessons are uploaded.
  bool isAvailable(String subjectId) => lessonsFor(subjectId).isNotEmpty;

  /// Subject the student is currently browsing.
  String? currentSubjectId;

  /// Last submitted subscription batch, shown on the confirmation screen.
  List<EpsSubscription> lastRequest = [];

  static const defaultUniversityResultsUrl =
      'https://resultats.univ-nkc.mr/FST/pages/accueil.jsf';

  /// University results site, editable by the admin (app_settings).
  String universityResultsUrl = defaultUniversityResultsUrl;

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
      try {
        sections = await repo.sections();
        sectionBundles = {for (final c in sections) c.id: c.bundlePrice};
      } on Object {
        sections = [];
        sectionBundles = {};
      }
      teachers = results[2]! as List<EpsTeacher>;
      _setPlans(results[3]! as List<EpsPlan>);
      subscriptions = results[4]! as List<EpsSubscription>;
      // Kept apart: a missing table must not stop the rest of the app.
      try {
        featureSubs = await repo.sectionFeatureSubscriptions(studentId: id);
      } on Object {
        featureSubs = [];
      }
      try {
        chatGroups = await repo.allChatGroups();
        groupSubs = await repo.groupSubscriptions(studentId: id);
      } on Object {
        chatGroups = [];
        groupSubs = [];
      }
      try {
        packageRows = await repo.assistantPackageRows();
      } on Object {
        packageRows = [];
      }
      lessons = (results[5]! as List<EpsLesson>)
          .where((l) => l.isPublished)
          .toList();
      completedLessonIds = results[6]! as Set<String>;
      exercises = results[7]! as List<EpsExercise>;
      pdfs = results[8]! as List<EpsPdf>;
      liveSessions = results[9]! as List<EpsLiveSession>;
      reminders = results[10]! as Set<String>;
      _syncReminders();
      quizzes = results[11]! as List<EpsQuiz>;
      attempts = results[12]! as List<EpsAttempt>;
      announcements = results[13]! as List<EpsAnnouncement>;
      notices = results[14]! as List<EpsNotice>;
      universityResultsUrl = await repo.setting(
        'universityResultsUrl',
        fallback: defaultUniversityResultsUrl,
      );
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

  /// Paid signup in progress: the details typed in the signup form. The
  /// account itself is created when the payment receipt is sent.
  ({String name, String phone, String password, String referral})? signupDraft;

  /// Subjects, teachers and plans for someone not signed in yet (paid
  /// signup goes through the catalog before the account exists).
  Future<void> loadCatalog() async {
    if (!enabled || subjects.isNotEmpty) {
      return;
    }
    try {
      final results = await Future.wait<Object>([
        repo.subjects(),
        repo.teachers(),
        repo.plans(),
        repo.lessons(),
      ]);
      subjects = (results[0] as List<EpsSubject>)
          .where((s) => s.isActive)
          .toList();
      teachers = results[1] as List<EpsTeacher>;
      _setPlans(results[2] as List<EpsPlan>);
      lessons = (results[3] as List<EpsLesson>)
          .where((l) => l.isPublished)
          .toList();
      notifyListeners();
    } on Object {
      // The catalog screens show their empty state.
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

  /// A group opens with the full subject or with its own subscription.
  bool canOpenGroup(EpsChatGroup group) =>
      hasAccess(group.subjectId) ||
      groupSubs.any((g) => g.groupId == group.id && g.isActive);

  /// Lessons and files: only a full subscription opens them.
  /// Whether the student has an active subscription to a feature of a section.
  bool hasFeature(String courseId, String feature) => featureSubs.any(
    (f) => f.courseId == courseId && f.feature == feature && f.isActive,
  );

  bool hasGroupAccess(String? subjectId) =>
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

  /// The free plan covers live sessions and PDF files only.
  /// The section a subject belongs to, if any.
  String? courseOf(String? subjectId) =>
      subjects.where((s) => s.id == subjectId).firstOrNull?.courseId;

  /// A section feature (videos, live, assistant) of the subject's section.
  bool sectionFeatureFor(String? subjectId, String feature) {
    final course = courseOf(subjectId);
    return course != null && hasFeature(course, feature);
  }

  /// Recorded videos: the full subject, or the section's videos feature.
  bool canWatch(String? subjectId) =>
      hasAccess(subjectId) || sectionFeatureFor(subjectId, 'videos');

  /// Live sessions: the full subject, or the section's live feature.
  bool canJoinLive(String? subjectId) =>
      hasAccess(subjectId) || sectionFeatureFor(subjectId, 'live');

  bool canOpenLesson(EpsLesson lesson) => canWatch(lesson.subjectId);

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
    if (!cart.contains(subjectId) && !isAvailable(subjectId)) {
      return;
    }
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

  /// Bundle price of each section (course id -> MRU a month). A section whose
  /// subjects are all in the cart pays this price instead of the sum.
  Map<String, int> sectionBundles = {};
  List<EpsSection> sections = [];

  EpsSection? sectionById(String id) =>
      sections.where((c) => c.id == id).firstOrNull;

  /// What each subject in the cart costs this month. A complete section pays
  /// its bundle price, split between its subjects by their price.
  Map<String, int> get cartAmounts {
    final out = <String, int>{
      for (final s in cartSubjects) s.id: s.monthlyPrice,
    };
    final byCourse = <String, List<EpsSubject>>{};
    for (final s in cartSubjects) {
      final c = s.courseId;
      if (c != null) byCourse.putIfAbsent(c, () => []).add(s);
    }
    for (final entry in byCourse.entries) {
      final bundle = sectionBundles[entry.key] ?? 0;
      final allInSection = subjects
          .where((s) => s.courseId == entry.key)
          .length;
      if (bundle <= 0 || entry.value.length < allInSection) continue;
      final sum = entry.value.fold<int>(0, (a, s) => a + s.monthlyPrice);
      var left = bundle;
      for (var i = 0; i < entry.value.length; i++) {
        final s = entry.value[i];
        final share = i == entry.value.length - 1
            ? left
            : (sum == 0
                  ? bundle ~/ entry.value.length
                  : (bundle * s.monthlyPrice / sum).round());
        out[s.id] = share;
        left -= share;
      }
    }
    return out;
  }

  int get cartMonthlyTotal => cartAmounts.values.fold(0, (sum, v) => sum + v);

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
            'amount': plan.priceFor(cartAmounts[s.id] ?? s.monthlyPrice),
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
      amounts: cartAmounts,
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

  /// Set by the app to schedule (or cancel) device notifications for a
  /// session reminder.
  static void Function(EpsLiveSession session, bool on)? reminderScheduler;

  void _syncReminders() {
    final schedule = reminderScheduler;
    if (schedule == null) {
      return;
    }
    for (final s in liveSessions) {
      if (reminders.contains(s.id) && s.state == LiveState.upcoming) {
        schedule(s, true);
      }
    }
  }

  /// Replaces a session with fresher data (e.g. after a realtime update).
  void replaceLiveSession(EpsLiveSession session) {
    final i = liveSessions.indexWhere((s) => s.id == session.id);
    if (i < 0) {
      liveSessions = [...liveSessions, session];
    } else {
      liveSessions = [...liveSessions]..[i] = session;
    }
    notifyListeners();
  }

  Future<void> toggleReminder(String sessionId) async {
    final on = !reminders.contains(sessionId);
    on ? reminders.add(sessionId) : reminders.remove(sessionId);
    notifyListeners();
    final session = liveSessions.where((s) => s.id == sessionId).firstOrNull;
    if (session != null) {
      reminderScheduler?.call(session, on);
    }
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

  String? _localAvatar;

  /// The student's photo as a data URI, or empty when none is set.
  String get avatarUrl => _localAvatar ?? profile?.avatarUrl ?? '';

  /// Saves (or clears, with an empty string) the student's photo.
  Future<void> setAvatar(String dataUri) async {
    if (!enabled) {
      _localAvatar = dataUri;
      notifyListeners();
      return;
    }
    await saveProfile({'avatar_url': dataUri});
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
