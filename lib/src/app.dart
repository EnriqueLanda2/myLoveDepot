import 'package:flutter/material.dart';

import 'inventory_store.dart';
import 'screens/home_screen.dart';
import 'screens/login_screen.dart';

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
    // ── Paleta principal ──────────────────────────────────────────────────────
    const magenta = Color(0xffd94f87);       // acento principal
    const magentaDim = Color(0x33d94f87);    // magenta translúcido
    const magentaGlow = Color(0x1ad94f87);   // brillo suave
    const bgDeep = Color(0xff030507);        // fondo más oscuro
    const bgBase = Color(0xff090b0f);        // fondo base
    const bgCard = Color(0xff0e1117);        // tarjetas
    const bgSurface = Color(0xff141820);     // superficies elevadas
    const stroke = Color(0x22ffffff);        // líneas sutiles
    const textPrimary = Color(0xfff0f2f5);
    const textSecondary = Color(0xff8892a4);

    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'My Love Depot',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: magenta,
          brightness: Brightness.dark,
          primary: magenta,
          onPrimary: Colors.black,
          secondary: const Color(0xffff9ecc),
          surface: bgBase,
          surfaceContainerLow: bgCard,
          surfaceContainerLowest: bgDeep,
          surfaceContainerHigh: bgSurface,
          onSurface: textPrimary,
          onSurfaceVariant: textSecondary,
          outline: stroke,
          error: const Color(0xffff5370),
        ),
        useMaterial3: true,
        scaffoldBackgroundColor: bgBase,

        // ── AppBar ────────────────────────────────────────────────────────────
        appBarTheme: AppBarTheme(
          backgroundColor: bgDeep,
          foregroundColor: textPrimary,
          centerTitle: false,
          elevation: 0,
          scrolledUnderElevation: 0,
          shadowColor: Colors.transparent,
          surfaceTintColor: Colors.transparent,
          titleTextStyle: const TextStyle(
            color: textPrimary,
            fontSize: 18,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.5,
          ),
          shape: const Border(
            bottom: BorderSide(color: magentaDim, width: 1),
          ),
        ),

        // ── NavigationBar (móvil) ─────────────────────────────────────────────
        navigationBarTheme: NavigationBarThemeData(
          backgroundColor: bgDeep,
          indicatorColor: magentaDim,
          height: 68,
          labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
          labelTextStyle: WidgetStateProperty.resolveWith((states) {
            if (states.contains(WidgetState.selected)) {
              return const TextStyle(
                color: magenta,
                fontWeight: FontWeight.w700,
                fontSize: 11,
                letterSpacing: 0.8,
              );
            }
            return const TextStyle(
              color: textSecondary,
              fontSize: 11,
              letterSpacing: 0.8,
            );
          }),
          iconTheme: WidgetStateProperty.resolveWith((states) {
            if (states.contains(WidgetState.selected)) {
              return const IconThemeData(color: magenta, size: 22);
            }
            return const IconThemeData(color: textSecondary, size: 22);
          }),
        ),

        // ── NavigationRail (escritorio) ───────────────────────────────────────
        navigationRailTheme: const NavigationRailThemeData(
          backgroundColor: bgDeep,
          indicatorColor: magentaDim,
          selectedIconTheme: IconThemeData(color: magenta),
          unselectedIconTheme: IconThemeData(color: textSecondary),
          selectedLabelTextStyle: TextStyle(
            color: magenta,
            fontWeight: FontWeight.w700,
            fontSize: 12,
            letterSpacing: 0.6,
          ),
          unselectedLabelTextStyle: TextStyle(
            color: textSecondary,
            fontSize: 12,
          ),
        ),

        // ── Cards ─────────────────────────────────────────────────────────────
        cardTheme: const CardThemeData(
          elevation: 0,
          color: bgCard,
          margin: EdgeInsets.zero,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.all(Radius.circular(4)),
            side: BorderSide(color: stroke, width: 1),
          ),
        ),

        // ── Inputs ────────────────────────────────────────────────────────────
        inputDecorationTheme: const InputDecorationTheme(
          filled: true,
          fillColor: bgDeep,
          labelStyle: TextStyle(color: textSecondary, fontSize: 13),
          hintStyle: TextStyle(color: Color(0xff4a5568)),
          contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.all(Radius.circular(4)),
            borderSide: BorderSide(color: stroke),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.all(Radius.circular(4)),
            borderSide: BorderSide(color: stroke),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.all(Radius.circular(4)),
            borderSide: BorderSide(color: magenta, width: 1.5),
          ),
          errorBorder: OutlineInputBorder(
            borderRadius: BorderRadius.all(Radius.circular(4)),
            borderSide: BorderSide(color: Color(0xffff5370)),
          ),
          focusedErrorBorder: OutlineInputBorder(
            borderRadius: BorderRadius.all(Radius.circular(4)),
            borderSide: BorderSide(color: Color(0xffff5370), width: 1.5),
          ),
        ),

        // ── Filled buttons ────────────────────────────────────────────────────
        filledButtonTheme: FilledButtonThemeData(
          style: ButtonStyle(
            backgroundColor: WidgetStateProperty.resolveWith((states) {
              if (states.contains(WidgetState.disabled)) {
                return const Color(0xff1e2030);
              }
              return magenta;
            }),
            foregroundColor: WidgetStateProperty.all(Colors.black),
            overlayColor:
                WidgetStateProperty.all(Colors.white.withOpacity(0.12)),
            padding: WidgetStateProperty.all(
              const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
            ),
            shape: WidgetStateProperty.all(
              const RoundedRectangleBorder(
                borderRadius: BorderRadius.all(Radius.circular(4)),
              ),
            ),
            textStyle: WidgetStateProperty.all(
              const TextStyle(
                fontWeight: FontWeight.w700,
                letterSpacing: 0.6,
                fontSize: 14,
              ),
            ),
          ),
        ),

        // ── Outlined buttons ──────────────────────────────────────────────────
        outlinedButtonTheme: OutlinedButtonThemeData(
          style: ButtonStyle(
            foregroundColor: WidgetStateProperty.all(textPrimary),
            side: WidgetStateProperty.all(
              const BorderSide(color: stroke, width: 1),
            ),
            padding: WidgetStateProperty.all(
              const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
            ),
            shape: WidgetStateProperty.all(
              const RoundedRectangleBorder(
                borderRadius: BorderRadius.all(Radius.circular(4)),
              ),
            ),
            textStyle: WidgetStateProperty.all(
              const TextStyle(
                fontWeight: FontWeight.w600,
                letterSpacing: 0.4,
                fontSize: 14,
              ),
            ),
          ),
        ),

        // ── Text buttons ──────────────────────────────────────────────────────
        textButtonTheme: TextButtonThemeData(
          style: ButtonStyle(
            foregroundColor: WidgetStateProperty.all(magenta),
            textStyle: WidgetStateProperty.all(
              const TextStyle(fontWeight: FontWeight.w600, letterSpacing: 0.4),
            ),
          ),
        ),

        // ── Chips ─────────────────────────────────────────────────────────────
        chipTheme: const ChipThemeData(
          side: BorderSide(color: stroke),
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.all(Radius.circular(4))),
          backgroundColor: bgCard,
          selectedColor: magentaGlow,
          labelStyle: TextStyle(fontSize: 12, letterSpacing: 0.4),
        ),

        // ── Dividers ──────────────────────────────────────────────────────────
        dividerTheme: const DividerThemeData(
          color: stroke,
          thickness: 1,
          space: 1,
        ),

        // ── Dialogs ───────────────────────────────────────────────────────────
        dialogTheme: const DialogThemeData(
          backgroundColor: bgSurface,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.all(Radius.circular(8)),
            side: BorderSide(color: stroke, width: 1),
          ),
          titleTextStyle: TextStyle(
            color: textPrimary,
            fontSize: 18,
            fontWeight: FontWeight.w700,
          ),
        ),

        // ── SnackBar ──────────────────────────────────────────────────────────
        snackBarTheme: const SnackBarThemeData(
          backgroundColor: bgSurface,
          contentTextStyle: TextStyle(color: textPrimary),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.all(Radius.circular(4)),
          ),
          behavior: SnackBarBehavior.floating,
        ),

        // ── Badges ────────────────────────────────────────────────────────────
        badgeTheme: const BadgeThemeData(
          backgroundColor: magenta,
          textColor: Colors.black,
          textStyle: TextStyle(fontWeight: FontWeight.w700, fontSize: 10),
        ),

        // ── Typography ────────────────────────────────────────────────────────
        textTheme: const TextTheme(
          displayLarge: TextStyle(
              color: textPrimary, fontWeight: FontWeight.w800, letterSpacing: -1),
          displayMedium: TextStyle(
              color: textPrimary, fontWeight: FontWeight.w800, letterSpacing: -0.5),
          headlineLarge: TextStyle(
              color: textPrimary, fontWeight: FontWeight.w700, letterSpacing: -0.3),
          headlineMedium: TextStyle(
              color: textPrimary, fontWeight: FontWeight.w700),
          headlineSmall: TextStyle(
              color: textPrimary, fontWeight: FontWeight.w700),
          titleLarge: TextStyle(
              color: textPrimary, fontWeight: FontWeight.w700, letterSpacing: 0.2),
          titleMedium: TextStyle(
              color: textPrimary, fontWeight: FontWeight.w600),
          titleSmall: TextStyle(
              color: textPrimary, fontWeight: FontWeight.w600),
          bodyLarge: TextStyle(color: textPrimary),
          bodyMedium: TextStyle(color: textSecondary),
          bodySmall: TextStyle(color: textSecondary, fontSize: 12),
          labelLarge: TextStyle(
              color: textPrimary, fontWeight: FontWeight.w700, letterSpacing: 0.8),
          labelMedium: TextStyle(
              color: textSecondary, letterSpacing: 1.2, fontWeight: FontWeight.w700, fontSize: 11),
          labelSmall: TextStyle(
              color: textSecondary, letterSpacing: 1.4, fontWeight: FontWeight.w700, fontSize: 10),
        ),

        // ── ListTile ──────────────────────────────────────────────────────────
        listTileTheme: const ListTileThemeData(
          tileColor: bgCard,
          textColor: textPrimary,
          iconColor: textSecondary,
          contentPadding: EdgeInsets.symmetric(horizontal: 18, vertical: 4),
        ),

        // ── PopupMenu ─────────────────────────────────────────────────────────
        popupMenuTheme: const PopupMenuThemeData(
          color: bgSurface,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.all(Radius.circular(6)),
            side: BorderSide(color: stroke, width: 1),
          ),
          textStyle: TextStyle(color: textPrimary, fontSize: 14),
        ),

        // ── Icon buttons ──────────────────────────────────────────────────────
        iconButtonTheme: IconButtonThemeData(
          style: ButtonStyle(
            foregroundColor: WidgetStateProperty.resolveWith((states) {
              if (states.contains(WidgetState.selected)) return magenta;
              return textSecondary;
            }),
            shape: WidgetStateProperty.all(
              const RoundedRectangleBorder(
                  borderRadius: BorderRadius.all(Radius.circular(4))),
            ),
          ),
        ),

        // ── Progress indicators ───────────────────────────────────────────────
        progressIndicatorTheme:
            const ProgressIndicatorThemeData(color: magenta),
      ),
      home: ListenableBuilder(
        listenable: store,
        builder: (_, __) => store.isAuthenticated
            ? HomeScreen(store: store)
            : LoginScreen(store: store),
      ),
    );
  }
}
