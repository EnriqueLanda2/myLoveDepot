import 'package:flutter/material.dart';

import 'inventory_store.dart';
import 'screens/home_screen.dart';
import 'screens/login_screen.dart';
import 'ui/tokens.dart';

class DepotApp extends StatefulWidget {
  const DepotApp({super.key});

  @override
  State<DepotApp> createState() => _DepotAppState();
}

class _DepotAppState extends State<DepotApp> {
  final InventoryStore store = InventoryStore();

  @override
  void initState() {
    super.initState();
    store.load();
  }

  @override
  void dispose() {
    store.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'My Love Depot',
      theme: buildAppTheme(),
      home: ListenableBuilder(
        listenable: store,
        builder: (_, __) => store.isAuthenticated
            ? HomeScreen(store: store)
            : LoginScreen(store: store),
      ),
    );
  }
}

/// Tema del rediseño: Figtree, fondo rosado claro, tarjetas blancas con borde
/// fino, sin sombras pesadas ni degradados.
ThemeData buildAppTheme() {
  final base = ThemeData(
    useMaterial3: true,
    fontFamily: kFontFamily,
    colorScheme: ColorScheme.fromSeed(
      seedColor: AppColors.primary,
      primary: AppColors.primary,
      onPrimary: Colors.white,
      secondary: AppColors.primaryHover,
      surface: AppColors.surface,
      onSurface: AppColors.text,
      onSurfaceVariant: AppColors.textSecondary,
      outline: AppColors.border,
      outlineVariant: AppColors.borderSoft,
      error: AppColors.error,
    ),
    scaffoldBackgroundColor: AppColors.background,
  );
  return base.copyWith(
    textTheme: base.textTheme.apply(
      bodyColor: AppColors.text,
      displayColor: AppColors.text,
      fontFamily: kFontFamily,
    ),
    dividerTheme:
        const DividerThemeData(color: AppColors.border, thickness: 1, space: 1),
    tooltipTheme: TooltipThemeData(
      decoration: BoxDecoration(
        color: AppColors.text,
        borderRadius: BorderRadius.circular(8),
      ),
      textStyle: const TextStyle(
          fontFamily: kFontFamily, color: Colors.white, fontSize: 12),
      waitDuration: const Duration(milliseconds: 400),
    ),
    popupMenuTheme: PopupMenuThemeData(
      color: AppColors.surface,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: const BorderSide(color: AppColors.border),
      ),
      textStyle: const TextStyle(
          fontFamily: kFontFamily, color: AppColors.text, fontSize: 14),
    ),
    dialogTheme: const DialogThemeData(
      backgroundColor: AppColors.surface,
      surfaceTintColor: Colors.transparent,
    ),
    navigationBarTheme: NavigationBarThemeData(
      labelTextStyle: WidgetStateProperty.resolveWith(
        (states) => TextStyle(
          fontFamily: kFontFamily,
          fontSize: 11,
          fontWeight: states.contains(WidgetState.selected)
              ? FontWeight.w600
              : FontWeight.w500,
          color: states.contains(WidgetState.selected)
              ? AppColors.primaryText
              : AppColors.navText,
        ),
      ),
      iconTheme: WidgetStateProperty.resolveWith(
        (states) => IconThemeData(
          size: 22,
          color: states.contains(WidgetState.selected)
              ? AppColors.primaryText
              : AppColors.navText,
        ),
      ),
    ),
    progressIndicatorTheme:
        const ProgressIndicatorThemeData(color: AppColors.primary),
    textSelectionTheme: const TextSelectionThemeData(
      cursorColor: AppColors.primary,
      selectionColor: AppColors.primarySoft,
      selectionHandleColor: AppColors.primary,
    ),
    // El login conserva sus campos y botones con el estilo de la app.
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: AppColors.surface,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: AppColors.border),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: AppColors.border),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: AppColors.primary, width: 1.5),
      ),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        textStyle: const TextStyle(
            fontFamily: kFontFamily, fontWeight: FontWeight.w600),
      ),
    ),
  );
}
