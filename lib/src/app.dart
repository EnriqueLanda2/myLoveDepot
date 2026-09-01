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
    const seed = Color(0xffd94f87);
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'My Love Depot',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: seed,
          brightness: Brightness.light,
          surface: const Color(0xfffffbfd),
        ),
        useMaterial3: true,
        scaffoldBackgroundColor: const Color(0xfffff6fa),
        appBarTheme: const AppBarTheme(
          backgroundColor: Color(0xfffff6fa),
          foregroundColor: Color(0xff49343f),
          centerTitle: false,
          elevation: 0,
        ),
        navigationBarTheme: const NavigationBarThemeData(
          backgroundColor: Color(0xfffffafd),
          indicatorColor: Color(0xffffd7e6),
          height: 72,
        ),
        navigationRailTheme: const NavigationRailThemeData(
          backgroundColor: Color(0xfffffafd),
          indicatorColor: Color(0xffffd7e6),
        ),
        cardTheme: const CardThemeData(
          elevation: 1,
          color: Color(0xffffffff),
          shadowColor: Color(0x1ad94f87),
          margin: EdgeInsets.zero,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.all(Radius.circular(20)),
          ),
        ),
        inputDecorationTheme: const InputDecorationTheme(
          filled: true,
          fillColor: Colors.white,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.all(Radius.circular(14)),
          ),
        ),
        filledButtonTheme: FilledButtonThemeData(
          style: FilledButton.styleFrom(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          ),
        ),
        chipTheme: const ChipThemeData(
          side: BorderSide(color: Color(0xffffc4d9)),
          shape: StadiumBorder(),
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
