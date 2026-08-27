import 'package:flutter/material.dart';

import 'inventory_store.dart';
import 'screens/home_screen.dart';

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
    const seed = Color(0xff6f4e37);
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'My Love Depot',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: seed,
          brightness: Brightness.light,
          surface: const Color(0xfffffbf7),
        ),
        useMaterial3: true,
        scaffoldBackgroundColor: const Color(0xfffff8f0),
        cardTheme: const CardThemeData(
          elevation: 0,
          margin: EdgeInsets.zero,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.all(Radius.circular(20)),
          ),
        ),
        inputDecorationTheme: const InputDecorationTheme(
          border: OutlineInputBorder(
            borderRadius: BorderRadius.all(Radius.circular(14)),
          ),
        ),
      ),
      home: HomeScreen(store: store),
    );
  }
}
