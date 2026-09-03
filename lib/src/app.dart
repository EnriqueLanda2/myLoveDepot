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
    // ── Paleta principal (LIGHT) ──────────────────────────────────────────────
    const magenta = Color(0xffd94f87);          // acento principal

    // Colores del tema CLARO (los originales de la app)
    const bgBase = Color(0xfffff6fa);           // fondo scaffold (crema rosado)
    const bgCard = Color(0xffffffff);           // tarjetas blancas
    const bgSurface = Color(0xfffffbfd);        // superficies
    const bgNav = Color(0xfffffafd);            // nav bar/rail
    const indicatorColor = Color(0xffffd7e6);   // indicador nav
    const stroke = Color(0xffe8d0da);           // líneas sutiles rosadas
    const textPrimary = Color(0xff49343f);      // texto principal (rosa oscuro)
    const textSecondary = Color(0xff7a5c6b);    // texto secundario

    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'My Love Depot',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: magenta,
          brightness: Brightness.light,
          primary: magenta,
          onPrimary: Colors.white,
          secondary: const Color(0xffb5296b),
          surface: bgSurface,
          surfaceContainerLow: bgCard,
          surfaceContainerLowest: bgBase,
          surfaceContainerHigh: const Color(0xffffedf5),
          onSurface: textPrimary,
          onSurfaceVariant: textSecondary,
          outline: stroke,
          error: const Color(0xffb00020),
        ),
        useMaterial3: true,
        scaffoldBackgroundColor: bgBase,

        // ── AppBar ────────────────────────────────────────────────────────────
        appBarTheme: AppBarTheme(
          backgroundColor: bgBase,
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
            letterSpacing: 0.3,
          ),
          shape: const Border(
            bottom: BorderSide(color: stroke, width: 1),
          ),
        ),

        // ── NavigationBar (móvil) ─────────────────────────────────────────────
        navigationBarTheme: NavigationBarThemeData(
          backgroundColor: bgNav,
          indicatorColor: indicatorColor,
          height: 68,
          labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
          labelTextStyle: WidgetStateProperty.resolveWith((states) {
            if (states.contains(WidgetState.selected)) {
              return const TextStyle(
                color: magenta,
                fontWeight: FontWeight.w700,
                fontSize: 11,
                letterSpacing: 0.5,
              );
            }
            return const TextStyle(
              color: textSecondary,
              fontSize: 11,
              letterSpacing: 0.5,
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
          backgroundColor: bgNav,
          indicatorColor: indicatorColor,
          selectedIconTheme: IconThemeData(color: magenta),
          unselectedIconTheme: IconThemeData(color: textSecondary),
          selectedLabelTextStyle: TextStyle(
            color: magenta,
            fontWeight: FontWeight.w700,
            fontSize: 12,
            letterSpacing: 0.4,
          ),
          unselectedLabelTextStyle: TextStyle(
            color: textSecondary,
            fontSize: 12,
          ),
        ),

        // ── Cards ─────────────────────────────────────────────────────────────
        cardTheme: const CardThemeData(
          elevation: 1,
          color: bgCard,
          shadowColor: Color(0x1ad94f87),
          margin: EdgeInsets.zero,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.all(Radius.circular(16)),
            side: BorderSide(color: stroke, width: 1),
          ),
        ),

        // ── Inputs ────────────────────────────────────────────────────────────
        inputDecorationTheme: const InputDecorationTheme(
          filled: true,
          fillColor: Colors.white,
          labelStyle: TextStyle(color: textSecondary, fontSize: 13),
          hintStyle: TextStyle(color: Color(0xffb090a0)),
          contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.all(Radius.circular(12)),
            borderSide: BorderSide(color: stroke),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.all(Radius.circular(12)),
            borderSide: BorderSide(color: stroke),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.all(Radius.circular(12)),
            borderSide: BorderSide(color: magenta, width: 1.5),
          ),
          errorBorder: OutlineInputBorder(
            borderRadius: BorderRadius.all(Radius.circular(12)),
            borderSide: BorderSide(color: Color(0xffb00020)),
          ),
          focusedErrorBorder: OutlineInputBorder(
            borderRadius: BorderRadius.all(Radius.circular(12)),
            borderSide: BorderSide(color: Color(0xffb00020), width: 1.5),
          ),
        ),

        // ── Filled buttons ────────────────────────────────────────────────────
        filledButtonTheme: FilledButtonThemeData(
          style: ButtonStyle(
            backgroundColor: WidgetStateProperty.resolveWith((states) {
              if (states.contains(WidgetState.disabled)) {
                return const Color(0xffe0cdd6);
              }
              return magenta;
            }),
            foregroundColor: WidgetStateProperty.all(Colors.white),
            overlayColor: WidgetStateProperty.all(
                Colors.white.withValues(alpha: 0.15)),
            padding: WidgetStateProperty.all(
              const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
            ),
            shape: WidgetStateProperty.all(
              const RoundedRectangleBorder(
                borderRadius: BorderRadius.all(Radius.circular(12)),
              ),
            ),
            textStyle: WidgetStateProperty.all(
              const TextStyle(
                fontWeight: FontWeight.w700,
                letterSpacing: 0.4,
                fontSize: 14,
              ),
            ),
          ),
        ),

        // ── Outlined buttons ──────────────────────────────────────────────────
        outlinedButtonTheme: OutlinedButtonThemeData(
          style: ButtonStyle(
            foregroundColor: WidgetStateProperty.all(magenta),
            side: WidgetStateProperty.all(
              const BorderSide(color: magenta, width: 1),
            ),
            padding: WidgetStateProperty.all(
              const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
            ),
            shape: WidgetStateProperty.all(
              const RoundedRectangleBorder(
                borderRadius: BorderRadius.all(Radius.circular(12)),
              ),
            ),
            textStyle: WidgetStateProperty.all(
              const TextStyle(
                fontWeight: FontWeight.w600,
                letterSpacing: 0.3,
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
              const TextStyle(fontWeight: FontWeight.w600, letterSpacing: 0.3),
            ),
          ),
        ),

        // ── Chips ─────────────────────────────────────────────────────────────
        chipTheme: const ChipThemeData(
          side: BorderSide(color: Color(0xffffc4d9)),
          shape: StadiumBorder(),
          backgroundColor: bgSurface,
          selectedColor: indicatorColor,
          labelStyle: TextStyle(fontSize: 12, color: textPrimary),
        ),

        // ── Dividers ──────────────────────────────────────────────────────────
        dividerTheme: const DividerThemeData(
          color: stroke,
          thickness: 1,
          space: 1,
        ),

        // ── Dialogs ───────────────────────────────────────────────────────────
        dialogTheme: const DialogThemeData(
          backgroundColor: bgCard,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.all(Radius.circular(20)),
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
          backgroundColor: Color(0xff49343f),
          contentTextStyle: TextStyle(color: Colors.white),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.all(Radius.circular(10)),
          ),
          behavior: SnackBarBehavior.floating,
        ),

        // ── Badges ────────────────────────────────────────────────────────────
        badgeTheme: const BadgeThemeData(
          backgroundColor: magenta,
          textColor: Colors.white,
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
              color: textPrimary, fontWeight: FontWeight.w700, letterSpacing: 0.5),
          labelMedium: TextStyle(
              color: textSecondary, letterSpacing: 0.8, fontWeight: FontWeight.w700, fontSize: 11),
          labelSmall: TextStyle(
              color: textSecondary, letterSpacing: 1.0, fontWeight: FontWeight.w700, fontSize: 10),
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
          color: bgCard,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.all(Radius.circular(12)),
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
                  borderRadius: BorderRadius.all(Radius.circular(10))),
            ),
          ),
        ),

        // ── Progress indicators ───────────────────────────────────────────────
        progressIndicatorTheme:
            const ProgressIndicatorThemeData(color: magenta),

        // ── FloatingActionButton ──────────────────────────────────────────────
        floatingActionButtonTheme: const FloatingActionButtonThemeData(
          backgroundColor: magenta,
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.all(Radius.circular(16)),
          ),
        ),
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
