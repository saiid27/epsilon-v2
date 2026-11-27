part of '../main.dart';

/// One look of the group chat: its colours and its font.
class ChatLook {
  const ChatLook({
    required this.id,
    required this.title,
    required this.font,
    required this.wall,
    required this.bar,
    required this.incoming,
    required this.outgoing,
    required this.text,
    required this.muted,
    required this.accent,
  });

  final String id;
  final String title;
  final String font;
  final Color wall;
  final Color bar;
  final Color incoming;
  final Color outgoing;
  final Color text;
  final Color muted;
  final Color accent;

  /// The text style every label in the chat inherits.
  TextStyle get textStyle => GoogleFonts.getFont(font, color: text);

  /// A: dark and elegant, Tajawal for easy reading on dark screens.
  static const dark = ChatLook(
    id: 'dark',
    title: 'ليلي أنيق (Tajawal)',
    font: 'Tajawal',
    wall: Color(0xFF0B141A),
    bar: Color(0xFF1F2C34),
    incoming: Color(0xFF1F2C34),
    outgoing: Color(0xFF005C4B),
    text: Color(0xFFE9EDEF),
    muted: Color(0xFF8696A0),
    accent: Color(0xFF00A884),
  );

  /// B: light and soft, Cairo with balanced weights.
  static const day = ChatLook(
    id: 'day',
    title: 'نهاري ناعم (Cairo)',
    font: 'Cairo',
    wall: Color(0xFFEFEAE2),
    bar: Color(0xFFFFFFFF),
    incoming: Color(0xFFFFFFFF),
    outgoing: Color(0xFFD9FDD3),
    text: Color(0xFF111B21),
    muted: Color(0xFF667781),
    accent: Color(0xFF00A884),
  );

  /// C: the pinned lesson style, Almarai for strong headings.
  static const pinned = ChatLook(
    id: 'pinned',
    title: 'الدرس المثبت (Almarai)',
    font: 'Almarai',
    wall: Color(0xFFF4F7FB),
    bar: Color(0xFF172D72),
    incoming: Color(0xFFFFFFFF),
    outgoing: Color(0xFFE3ECFF),
    text: Color(0xFF172039),
    muted: Color(0xFF6B7690),
    accent: Color(0xFF2F5BD3),
  );

  static const all = [dark, day, pinned];

  static ChatLook byId(String? id) =>
      all.firstWhere((l) => l.id == id, orElse: () => dark);
}

/// The look the chat uses now. Changed from the chat's settings sheet.
final ValueNotifier<ChatLook> chatLook = ValueNotifier<ChatLook>(ChatLook.dark);

/// Reads the chosen look from the phone (once, when the app starts a chat).
Future<void> loadChatLook() async {
  try {
    final prefs = await SharedPreferences.getInstance();
    chatLook.value = ChatLook.byId(prefs.getString('chat_look'));
  } on Object {
    // Keep the default look.
  }
}

Future<void> saveChatLook(ChatLook look) async {
  chatLook.value = look;
  try {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('chat_look', look.id);
  } on Object {
    // The choice still applies for this session.
  }
}
