import 'package:flutter/material.dart';

/// Design tokens taken from the Figma Make design (index.css `:root`).
class Eps {
  Eps._();

  static const blue = Color(0xFF2F5BD3);
  static const blue2 = Color(0xFF416DDE);
  static const blueDeep = Color(0xFF2B58B4);
  static const blueSoft = Color(0xFFEAF3FF);
  static const navy = Color(0xFF172D72);
  static const navy2 = Color(0xFF2E5CB5);
  static const orange = Color(0xFFF1B91C);
  static const orangeInk = Color(0xFFB96D00);
  static const orangeSoft = Color(0xFFFFF7D9);
  static const green = Color(0xFF16A36A);
  static const greenInk = Color(0xFF078657);
  static const greenSoft = Color(0xFFE4F8EF);
  static const red = Color(0xFFE84855);
  static const redInk = Color(0xFFD52F3E);
  static const redSoft = Color(0xFFFFE7EA);
  static const ink = Color(0xFF172039);
  static const muted = Color(0xFF778097);
  static const faint = Color(0xFF9198AA);
  static const line = Color(0xFFE8EBF2);
  static const field = Color(0xFFDFE4ED);
  static const bg = Color(0xFFF7F8FC);
  static const gray = Color(0xFFF0F2F6);
  static const grayInk = Color(0xFF687187);

  static const font = 'Cairo';

  static const radius = 14.0;
  static const cardRadius = 17.0;

  static const fontNum = 'Inter';

  /// `linear-gradient(100deg, --blue, #2b58b4)`.
  static const primaryGradient = LinearGradient(
    begin: Alignment(-1, -0.18),
    end: Alignment(1, 0.18),
    colors: [blue, blueDeep],
  );

  static const heroGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [navy, navy2],
  );

  static const greenGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFF16A36A), Color(0xFF0E8A57)],
  );

  static List<BoxShadow> get cardShadow => const [
    BoxShadow(color: Color(0x0918254A), blurRadius: 16, offset: Offset(0, 5)),
  ];

  static List<BoxShadow> get buttonShadow => const [
    BoxShadow(color: Color(0x2B1E3A8A), blurRadius: 19, offset: Offset(0, 9)),
  ];

  static ThemeData lightTheme() {
    final scheme = ColorScheme.fromSeed(
      seedColor: blue,
      primary: blue,
      secondary: green,
      tertiary: orange,
      error: red,
      surface: Colors.white,
    );
    final base = ThemeData(
      colorScheme: scheme,
      useMaterial3: true,
      fontFamily: font,
      scaffoldBackgroundColor: bg,
    );
    return base.copyWith(
      textTheme: base.textTheme.apply(bodyColor: ink, displayColor: ink),
      appBarTheme: const AppBarTheme(
        backgroundColor: Colors.transparent,
        foregroundColor: ink,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        titleTextStyle: TextStyle(
          fontFamily: font,
          color: ink,
          fontSize: 17,
          fontWeight: FontWeight.w800,
        ),
      ),
      inputDecorationTheme: inputTheme(),
      cardTheme: CardThemeData(
        elevation: 0,
        color: Colors.white,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(cardRadius),
          side: const BorderSide(color: line),
        ),
      ),
      dividerTheme: const DividerThemeData(color: line, thickness: 1),
      filledButtonTheme: FilledButtonThemeData(style: _filledStyle()),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: blue,
          foregroundColor: Colors.white,
          elevation: 0,
          minimumSize: const Size(64, 50),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(radius),
          ),
          textStyle: const TextStyle(
            fontFamily: font,
            fontWeight: FontWeight.w800,
            fontSize: 15,
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: blue,
          side: const BorderSide(color: line),
          backgroundColor: Colors.white,
          minimumSize: const Size(64, 48),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(radius),
          ),
          textStyle: const TextStyle(
            fontFamily: font,
            fontWeight: FontWeight.w800,
          ),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: blue,
          textStyle: const TextStyle(
            fontFamily: font,
            fontWeight: FontWeight.w800,
          ),
        ),
      ),
      chipTheme: base.chipTheme.copyWith(
        backgroundColor: Colors.white,
        selectedColor: blue,
        side: const BorderSide(color: line),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        labelStyle: const TextStyle(
          fontFamily: font,
          fontWeight: FontWeight.w700,
        ),
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: ink,
        contentTextStyle: const TextStyle(
          fontFamily: font,
          color: Colors.white,
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(radius),
        ),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
      ),
      bottomSheetTheme: const BottomSheetThemeData(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.transparent,
        indicatorColor: blueSoft,
        labelTextStyle: WidgetStateProperty.resolveWith(
          (states) => TextStyle(
            fontFamily: font,
            fontSize: 11,
            fontWeight: states.contains(WidgetState.selected)
                ? FontWeight.w800
                : FontWeight.w600,
            color: states.contains(WidgetState.selected) ? blue : faint,
          ),
        ),
      ),
    );
  }

  static ThemeData darkTheme() {
    final base = ThemeData(
      colorScheme: ColorScheme.fromSeed(
        seedColor: blue,
        brightness: Brightness.dark,
      ),
      useMaterial3: true,
      fontFamily: font,
      scaffoldBackgroundColor: const Color(0xFF0F172A),
    );
    return base.copyWith(
      appBarTheme: const AppBarTheme(
        backgroundColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
      ),
      inputDecorationTheme: InputDecorationTheme(
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(radius)),
        filled: true,
        fillColor: const Color(0xFF111827),
      ),
      cardTheme: CardThemeData(
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(cardRadius),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(style: _filledStyle()),
    );
  }

  static ButtonStyle _filledStyle() => FilledButton.styleFrom(
    backgroundColor: blue,
    foregroundColor: Colors.white,
    disabledBackgroundColor: const Color(0xFFC9CED9),
    disabledForegroundColor: Colors.white,
    minimumSize: const Size(64, 50),
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(radius)),
    textStyle: const TextStyle(
      fontFamily: font,
      fontWeight: FontWeight.w800,
      fontSize: 15,
    ),
  );

  static InputDecorationTheme inputTheme() {
    OutlineInputBorder b(Color c, [double w = 1]) => OutlineInputBorder(
      borderRadius: BorderRadius.circular(radius),
      borderSide: BorderSide(color: c, width: w),
    );
    return InputDecorationTheme(
      filled: true,
      fillColor: Colors.white,
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 15),
      border: b(field),
      enabledBorder: b(field),
      focusedBorder: b(blue2, 1.5),
      errorBorder: b(red),
      focusedErrorBorder: b(red, 1.5),
      hintStyle: const TextStyle(color: Color(0xFF9AA2B4), fontSize: 14),
      labelStyle: const TextStyle(color: muted),
      prefixIconColor: const Color(0xFF8A94A6),
      suffixIconColor: const Color(0xFF8C95A7),
    );
  }
}
