import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

// To use a custom font like 'Inter' or 'SF Pro', add it to your pubspec.yaml:
//
// dependencies:
//   google_fonts: ^6.2.1
//
// Then, uncomment the GoogleFonts line in the _textTheme definition below.

class ThemeProvider extends ChangeNotifier {
  bool _isDarkTheme = true;

  bool get isDarkTheme => _isDarkTheme;

  void setTheme(bool isDark) {
    _isDarkTheme = isDark;
    notifyListeners();
  }

  // Make the theme data public for easy access from main.dart
  static final ThemeData lightTheme = _buildTheme(Brightness.light);
  static final ThemeData darkTheme = _buildTheme(Brightness.dark);

  static ThemeData _buildTheme(Brightness brightness) {
    final bool isDark = brightness == Brightness.dark;

    // Professional color schemes inspired by modern apps like Slack, Discord, Notion
    final ColorScheme darkColorScheme = const ColorScheme.dark().copyWith(
      // Primary: Professional blue that works well in dark mode
      primary: const Color(0xFF007AFF), // iOS system blue
      onPrimary: Colors.white,
      primaryContainer: const Color(0xFF0051D5),
      onPrimaryContainer: Colors.white,

      // Secondary: Subtle accent color
      secondary: const Color(0xFF5856D6), // iOS system purple
      onSecondary: Colors.white,
      secondaryContainer: const Color(0xFF4845C7),
      onSecondaryContainer: Colors.white,

      // Surface colors: Rich dark surfaces with subtle variations
      surface: const Color(0xFF1C1C1E), // iOS dark surface
      onSurface: const Color(0xFFF2F2F7), // High contrast white
      surfaceContainer: const Color(0xFF2C2C2E), // Slightly lighter surface
      surfaceContainerHighest: const Color(0xFF3A3A3C), // Card/elevated surface
      onSurfaceVariant: const Color(0xFF8E8E93),

      // Outline colors for borders
      outline: const Color(0xFF38383A),
      outlineVariant: const Color(0xFF2C2C2E),

      // Error colors
      error: const Color(0xFFFF453A), // iOS system red
      onError: Colors.white,
      errorContainer: const Color(0xFFFF3B30),
      onErrorContainer: Colors.white,

      // Success/positive color
      tertiary: const Color(0xFF30D158), // iOS system green
      onTertiary: Colors.white,
    );

    final ColorScheme lightColorScheme = const ColorScheme.light().copyWith(
      // Primary: Clean, professional blue
      primary: const Color(0xFF007AFF),
      onPrimary: Colors.white,
      primaryContainer: const Color(0xFFD1E7FF),
      onPrimaryContainer: const Color(0xFF001A41),

      // Secondary: Complementary purple
      secondary: const Color(0xFF5856D6),
      onSecondary: Colors.white,
      secondaryContainer: const Color(0xFFE5E5F7),
      onSecondaryContainer: const Color(0xFF1A1A2E),

      // Surface colors: Clean whites and light grays
      surface: Colors.white,
      onSurface: const Color(0xFF1C1C1E),
      surfaceContainer: const Color(0xFFF2F2F7), // Light gray for cards
      surfaceContainerHighest: const Color(0xFFE5E5EA), // Elevated surfaces
      onSurfaceVariant: const Color(0xFF8E8E93),

      // Outline colors
      outline: const Color(0xFFD1D1D6),
      outlineVariant: const Color(0xFFE5E5EA),

      // Error colors
      error: const Color(0xFFFF3B30),
      onError: Colors.white,
      errorContainer: const Color(0xFFFFE5E5),
      onErrorContainer: const Color(0xFF410002),

      // Success color
      tertiary: const Color(0xFF30D158),
      onTertiary: Colors.white,
    );

    final colorScheme = isDark ? darkColorScheme : lightColorScheme;

    // Professional typography scale inspired by SF Pro and Inter
    final baseTextTheme = TextTheme(
      // Display styles - for large headings
      displayLarge: TextStyle(
        fontWeight: FontWeight.w800,
        fontSize: 57,
        letterSpacing: -0.25,
        color: colorScheme.onSurface,
        height: 1.12,
      ),
      displayMedium: TextStyle(
        fontWeight: FontWeight.w700,
        fontSize: 45,
        letterSpacing: 0,
        color: colorScheme.onSurface,
        height: 1.16,
      ),
      displaySmall: TextStyle(
        fontWeight: FontWeight.w600,
        fontSize: 36,
        letterSpacing: 0,
        color: colorScheme.onSurface,
        height: 1.22,
      ),

      // Headlines - for section headers
      headlineLarge: TextStyle(
        fontWeight: FontWeight.w600,
        fontSize: 32,
        letterSpacing: 0,
        color: colorScheme.onSurface,
        height: 1.25,
      ),
      headlineMedium: TextStyle(
        fontWeight: FontWeight.w600,
        fontSize: 28,
        letterSpacing: 0,
        color: colorScheme.onSurface,
        height: 1.29,
      ),
      headlineSmall: TextStyle(
        fontWeight: FontWeight.w600,
        fontSize: 24,
        letterSpacing: 0,
        color: colorScheme.onSurface,
        height: 1.33,
      ),

      // Titles - for card headers, dialog titles
      titleLarge: TextStyle(
        fontWeight: FontWeight.w600,
        fontSize: 22,
        letterSpacing: 0,
        color: colorScheme.onSurface,
        height: 1.27,
      ),
      titleMedium: TextStyle(
        fontWeight: FontWeight.w500,
        fontSize: 18,
        letterSpacing: 0.15,
        color: colorScheme.onSurface,
        height: 1.33,
      ),
      titleSmall: TextStyle(
        fontWeight: FontWeight.w500,
        fontSize: 14,
        letterSpacing: 0.1,
        color: colorScheme.onSurface,
        height: 1.43,
      ),

      // Body text
      bodyLarge: TextStyle(
        fontWeight: FontWeight.w400,
        fontSize: 16,
        letterSpacing: 0.15,
        color: colorScheme.onSurface,
        height: 1.5,
      ),
      bodyMedium: TextStyle(
        fontWeight: FontWeight.w400,
        fontSize: 14,
        letterSpacing: 0.25,
        color: colorScheme.onSurface,
        height: 1.43,
      ),
      bodySmall: TextStyle(
        fontWeight: FontWeight.w400,
        fontSize: 12,
        letterSpacing: 0.4,
        color: colorScheme.onSurfaceVariant,
        height: 1.33,
      ),

      // Labels - for buttons, form labels
      labelLarge: TextStyle(
        fontWeight: FontWeight.w600,
        fontSize: 16,
        letterSpacing: 0.1,
        color: colorScheme.onPrimary,
        height: 1.43,
      ),
      labelMedium: TextStyle(
        fontWeight: FontWeight.w500,
        fontSize: 14,
        letterSpacing: 0.5,
        color: colorScheme.onSurfaceVariant,
        height: 1.33,
      ),
      labelSmall: TextStyle(
        fontWeight: FontWeight.w500,
        fontSize: 11,
        letterSpacing: 0.5,
        color: colorScheme.onSurfaceVariant,
        height: 1.45,
      ),
    );

    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      colorScheme: colorScheme,
      textTheme: baseTextTheme,

      // Scaffold
      scaffoldBackgroundColor: colorScheme.surface,

      // App Bar - Modern, clean design
      appBarTheme: AppBarTheme(
        backgroundColor: colorScheme.surface,
        foregroundColor: colorScheme.onSurface,
        elevation: 0,
        scrolledUnderElevation: 1,
        centerTitle: false, // More modern alignment
        titleSpacing: 0,
        systemOverlayStyle: isDark
            ? SystemUiOverlayStyle.light
            : SystemUiOverlayStyle.dark,
        titleTextStyle: baseTextTheme.headlineSmall?.copyWith(
          fontWeight: FontWeight.w600,
        ),
      ),

      // Cards - Modern elevated design
      cardTheme: CardThemeData(
        color: colorScheme.surfaceContainer,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(color: colorScheme.outlineVariant, width: 1),
        ),
        margin: const EdgeInsets.all(8),
      ),

      // Elevated Button - Primary action button
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          foregroundColor: colorScheme.onPrimary,
          backgroundColor: colorScheme.primary,
          disabledForegroundColor: colorScheme.onSurface.withOpacity(0.38),
          disabledBackgroundColor: colorScheme.onSurface.withOpacity(0.12),
          elevation: 2,
          shadowColor: colorScheme.shadow.withOpacity(0.15),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          textStyle: baseTextTheme.labelLarge,
          minimumSize: const Size(64, 48),
        ),
      ),

      // Outlined Button - Secondary action button
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: colorScheme.primary,
          disabledForegroundColor: colorScheme.onSurface.withOpacity(0.38),
          side: BorderSide(color: colorScheme.outline, width: 1),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          textStyle: baseTextTheme.labelLarge?.copyWith(
            color: colorScheme.primary,
          ),
          minimumSize: const Size(64, 48),
        ),
      ),

      // Text Button - Tertiary action button
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: colorScheme.primary,
          disabledForegroundColor: colorScheme.onSurface.withOpacity(0.38),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          textStyle: baseTextTheme.labelLarge?.copyWith(
            color: colorScheme.primary,
            fontWeight: FontWeight.w500,
          ),
          minimumSize: const Size(48, 40),
        ),
      ),

      // Input Fields - Modern, accessible design
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: colorScheme.surfaceContainer,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 16,
        ),

        // Label and hint styling
        labelStyle: baseTextTheme.bodyLarge?.copyWith(
          color: colorScheme.onSurfaceVariant,
        ),
        floatingLabelStyle: baseTextTheme.bodySmall?.copyWith(
          color: colorScheme.primary,
          fontWeight: FontWeight.w500,
        ),
        hintStyle: baseTextTheme.bodyLarge?.copyWith(
          color: colorScheme.onSurfaceVariant.withOpacity(0.6),
        ),

        // Icon styling
        prefixIconColor: colorScheme.onSurfaceVariant,
        suffixIconColor: colorScheme.onSurfaceVariant,

        // Border styling
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: colorScheme.outline),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: colorScheme.outline),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: colorScheme.primary, width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: colorScheme.error, width: 2),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: colorScheme.error, width: 2),
        ),
        disabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(
            color: colorScheme.onSurface.withOpacity(0.12),
          ),
        ),

        // Error styling
        errorStyle: baseTextTheme.bodySmall?.copyWith(color: colorScheme.error),
      ),

      // Floating Action Button
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: colorScheme.primary,
        foregroundColor: colorScheme.onPrimary,
        elevation: 6,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),

      // Bottom Navigation Bar
      bottomNavigationBarTheme: BottomNavigationBarThemeData(
        backgroundColor: colorScheme.surface,
        selectedItemColor: colorScheme.primary,
        unselectedItemColor: colorScheme.onSurfaceVariant,
        elevation: 8,
        type: BottomNavigationBarType.fixed,
        selectedLabelStyle: baseTextTheme.labelSmall,
        unselectedLabelStyle: baseTextTheme.labelSmall,
      ),

      // Navigation Rail
      navigationRailTheme: NavigationRailThemeData(
        backgroundColor: colorScheme.surface,
        selectedIconTheme: IconThemeData(color: colorScheme.primary),
        unselectedIconTheme: IconThemeData(color: colorScheme.onSurfaceVariant),
        selectedLabelTextStyle: baseTextTheme.labelMedium?.copyWith(
          color: colorScheme.primary,
        ),
        unselectedLabelTextStyle: baseTextTheme.labelMedium?.copyWith(
          color: colorScheme.onSurfaceVariant,
        ),
      ),

      // Dialog Theme
      dialogTheme: DialogThemeData(
        backgroundColor: colorScheme.surface,
        elevation: 24,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        titleTextStyle: baseTextTheme.headlineSmall,
        contentTextStyle: baseTextTheme.bodyMedium,
      ),

      // Bottom Sheet
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: colorScheme.surface,
        elevation: 8,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
      ),

      // Chip Theme
      chipTheme: ChipThemeData(
        backgroundColor: colorScheme.surfaceContainer,
        selectedColor: colorScheme.primaryContainer,
        disabledColor: colorScheme.onSurface.withOpacity(0.12),
        labelStyle: baseTextTheme.labelLarge?.copyWith(
          color: colorScheme.onSurfaceVariant,
        ),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),

      // Switch Theme
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return colorScheme.onPrimary;
          }
          return colorScheme.outline;
        }),
        trackColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return colorScheme.primary;
          }
          return colorScheme.surfaceContainerHighest;
        }),
      ),

      // Divider
      dividerTheme: DividerThemeData(
        color: colorScheme.outlineVariant,
        thickness: 1,
        space: 1,
      ),

      // Icon Theme
      iconTheme: IconThemeData(color: colorScheme.onSurface, size: 24),
      primaryIconTheme: IconThemeData(color: colorScheme.onPrimary, size: 24),
    );
  }
}
