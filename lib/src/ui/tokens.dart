import 'package:flutter/material.dart';

/// Paleta del rediseño. Un solo lugar para todos los colores de la app.
abstract final class AppColors {
  static const background = Color(0xFFFBF7F8);
  static const surface = Color(0xFFFFFFFF);
  static const text = Color(0xFF2A1F24);
  static const textSecondary = Color(0xFF7A6B71);
  static const textMuted = Color(0xFFB5A6AC);
  static const navText = Color(0xFF4A3D42);
  static const border = Color(0xFFEFE4E8);
  static const borderSoft = Color(0xFFF5EEF1);
  static const stripe = Color(0xFFF7F0F3);

  static const primary = Color(0xFFC8457A);
  static const primaryHover = Color(0xFFB23A6B);
  static const primarySoft = Color(0xFFFBE8EF);
  static const primaryText = Color(0xFFA8335F);
  static const primaryBorder = Color(0xFFF3D3DF);
  static const primaryDisabled = Color(0xFFEBDDE3);

  static const success = Color(0xFF21704B);
  static const successStrong = Color(0xFF2E8A5F);
  static const successSoft = Color(0xFFE6F4EC);
  static const successBorder = Color(0xFFCFE7DA);

  static const warning = Color(0xFF9A5A0C);
  static const warningDark = Color(0xFF6E420A);
  static const warningSoft = Color(0xFFFBF0DF);
  static const warningBorder = Color(0xFFEBC98F);
  static const warningDot = Color(0xFFD08A1E);

  static const error = Color(0xFFB03030);
  static const errorStrong = Color(0xFFC23B3B);
  static const errorSoft = Color(0xFFFBE7E7);

  static const ai = Color(0xFF5B3478);
  static const aiSoft = Color(0xFFF6EEFB);

  static const info = Color(0xFF5B6FB0);
  static const chartBar = Color(0xFFE9B5C9);
  static const chartOver = Color(0xFFE38B8B);
  static const chartLine = Color(0xFFB5A6AC);
  static const scrim = Color(0x592A1F24);
}

/// Colores consistentes por índice para categorías (gastos y catálogo).
abstract final class CategoryPalette {
  static const _hues = [355.0, 55.0, 150.0, 235.0, 300.0, 20.0, 190.0];

  static Color color(int index) =>
      HSLColor.fromAHSL(1, _hues[index % _hues.length], 0.42, 0.6).toColor();

  static Color soft(int index) =>
      HSLColor.fromAHSL(1, _hues[index % _hues.length], 0.55, 0.95).toColor();
}

const kFontFamily = 'Figtree';

/// Números con ancho fijo: las cifras no "bailan" al cambiar.
const kTabular = [FontFeature.tabularFigures()];

TextStyle appText({
  double size = 14,
  FontWeight weight = FontWeight.w400,
  Color color = AppColors.text,
  double? height,
  double? letterSpacing,
}) =>
    TextStyle(
      fontFamily: kFontFamily,
      fontSize: size,
      fontWeight: weight,
      color: color,
      height: height,
      letterSpacing: letterSpacing,
      fontFeatures: kTabular,
    );

// ── Formato ──────────────────────────────────────────────────────────────────

String _thousands(int value) {
  final digits = value.abs().toString();
  final buffer = StringBuffer();
  for (var i = 0; i < digits.length; i++) {
    if (i > 0 && (digits.length - i) % 3 == 0) buffer.write(',');
    buffer.write(digits[i]);
  }
  return buffer.toString();
}

/// `$1,234.50`, con signo menos tipográfico para negativos.
String money(double value) {
  final cents = (value.abs() * 100).round();
  final text =
      '\$${_thousands(cents ~/ 100)}.${(cents % 100).toString().padLeft(2, '0')}';
  return value < 0 && cents > 0 ? '−$text' : text;
}

/// `$1,235` (sin centavos).
String money0(double value) {
  final rounded = value.round();
  return '${rounded < 0 ? '−' : ''}\$${_thousands(rounded)}';
}

const _months = [
  'ene',
  'feb',
  'mar',
  'abr',
  'may',
  'jun',
  'jul',
  'ago',
  'sep',
  'oct',
  'nov',
  'dic',
];
const _monthsLong = [
  'enero',
  'febrero',
  'marzo',
  'abril',
  'mayo',
  'junio',
  'julio',
  'agosto',
  'septiembre',
  'octubre',
  'noviembre',
  'diciembre',
];
const _weekdays = [
  'Lunes',
  'Martes',
  'Miércoles',
  'Jueves',
  'Viernes',
  'Sábado',
  'Domingo',
];

String shortDate(DateTime date) => '${date.day} ${_months[date.month - 1]}';

/// "Jueves 8 de octubre, 2026".
String longDate(DateTime date) =>
    '${_weekdays[date.weekday - 1]} ${date.day} de ${_monthsLong[date.month - 1]}, ${date.year}';

/// "Hoy, 10:12", "Ayer, 18:05" o "3 oct".
String relativeDate(DateTime date, {DateTime? now}) {
  final today = now ?? DateTime.now();
  final day = DateTime(date.year, date.month, date.day);
  final diff =
      DateTime(today.year, today.month, today.day).difference(day).inDays;
  final time =
      '${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
  if (diff <= 0) return 'Hoy, $time';
  if (diff == 1) return 'Ayer, $time';
  return shortDate(date);
}

/// Acepta "450.50" y "450,50".
double? parseAmount(String text) =>
    double.tryParse(text.trim().replaceAll(',', '.').replaceAll('\$', ''));
