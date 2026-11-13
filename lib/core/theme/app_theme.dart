import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'app_colors.dart';

class AppTheme {
  AppTheme._();

  static const double radius = 32;

  static ThemeData get dark {
    final base = ThemeData(useMaterial3: true, brightness: Brightness.dark);
    final inter = GoogleFonts.interTextTheme(base.textTheme);
    TextStyle title(TextStyle? s) =>
        GoogleFonts.montserrat(textStyle: s, fontWeight: FontWeight.w700);

    final textTheme = inter.copyWith(
      headlineLarge: title(inter.headlineLarge),
      headlineMedium: title(inter.headlineMedium),
      headlineSmall: title(inter.headlineSmall),
      titleLarge: title(inter.titleLarge),
      titleMedium: title(inter.titleMedium),
    );

    final shape = RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(radius),
    );

    return base.copyWith(
      scaffoldBackgroundColor: AppColors.black,
      colorScheme: const ColorScheme.dark(
        primary: AppColors.violet,
        onPrimary: AppColors.white,
        secondary: AppColors.lime,
        onSecondary: AppColors.black,
        surface: AppColors.black,
        onSurface: AppColors.white,
      ),
      textTheme: textTheme,
      appBarTheme: const AppBarTheme(
        backgroundColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          shape: shape,
          minimumSize: const Size.fromHeight(56),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          shape: shape,
          minimumSize: const Size.fromHeight(56),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(shape: shape),
      ),
    );
  }
}
