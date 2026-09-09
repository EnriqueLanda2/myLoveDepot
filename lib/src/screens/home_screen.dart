import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';

import '../inventory_store.dart';
import '../models.dart';
import '../widgets/love_mascot.dart';
import '../widgets/pwa_helpers.dart';
import '../widgets/pwa_install_banner.dart';
import 'categories_screen.dart';
import 'product_form.dart';
import 'scanner_screen.dart';
import 'stock_dialog.dart';

// ── Paleta de colores centralizada (LIGHT) ────────────────────────────────────
class _Colors {
  static const magenta = Color(0xffd94f87);
  static const magentaGlow = Color(0x1ad94f87);
  static const bgDeep = Color(0xfffff6fa);      // crema rosada (original)
  static const bgBase = Color(0xfffff6fa);      // fondo base claro
  static const bgCard = Color(0xffffffff);      // tarjetas blancas
  static const bgSurface = Color(0xfffffbfd);   // superficies
  static const stroke = Color(0xffe8d0da);      // borde rosado suave
  static const strokeMagenta = Color(0x33d94f87);
  static const textPrimary = Color(0xff49343f); // texto oscuro rosado (original)
  static const textSecondary = Color(0xff7a5c6b);
  static const green = Color(0xff16a34a);       // verde más oscuro (visible en claro)
  static const amber = Color(0xffb45309);       // ámbar oscuro (visible en claro)
  static const red = Color(0xffb00020);         // rojo oscuro (visible en claro)
}

// ── HomeScreen ────────────────────────────────────────────────────────────────
class HomeScreen extends StatefulWidget {
  const HomeScreen({required this.store, super.key});
  final InventoryStore store;

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int selectedIndex = 0;
  String query = '';
  bool lowStockOnly = false;
  String selectedCategory = 'Todas las categorías';
  int currentPage = 1;
  static const int pageSize = 30;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: widget.store,
      builder: (context, _) {
        if (widget.store.isLoading) {
          return const Scaffold(
            body: Center(
              child: CircularProgressIndicator(color: _Colors.magenta),
            ),
          );
        }
        return LayoutBuilder(
          builder: (context, constraints) {
            final wide = constraints.maxWidth >= 760;
            return Scaffold(
              backgroundColor: _Colors.bgBase,
              appBar: _buildAppBar(context, wide),
              body: Row(
                children: [
                  if (wide) _buildNavRail(),
                  Expanded(
                    child: Column(
                      children: [
                        const PwaInstallBanner(),
                        Expanded(child: _page()),
                      ],
                    ),
                  ),
                ],
              ),
              bottomNavigationBar: wide ? null : _buildBottomNav(),
              floatingActionButton: wide
                  ? null
                  : FloatingActionButton.extended(
                      onPressed: () => _openProductForm(context),
                      backgroundColor: _Colors.magenta,
                      foregroundColor: Colors.black,
                      icon: const Icon(Icons.add_rounded),
                      label: const Text(
                        'NUEVO PRODUCTO',
                        style: TextStyle(
                          fontWeight: FontWeight.w800,
                          letterSpacing: 1.2,
                          fontSize: 12,
                        ),
                      ),
                    ),
            );
          },
        );
      },
    );
  }

  PreferredSizeWidget _buildAppBar(BuildContext context, bool wide) {
    return AppBar(
      backgroundColor: _Colors.bgDeep,
      elevation: 0,
      scrolledUnderElevation: 0,
      title: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.all(5),
            decoration: BoxDecoration(
              color: _Colors.bgSurface,
              borderRadius: BorderRadius.circular(6),
              border: Border.all(color: _Colors.strokeMagenta, width: 1),
            ),
            child: const LoveMascot(size: 30),
          ),
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'MY LOVE DEPOT',
                style: TextStyle(
                  color: _Colors.textPrimary,
                  fontSize: 14,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 2,
                ),
              ),
              Text(
                'GESTIÓN DE ALMACÉN',
                style: TextStyle(
                  color: _Colors.textSecondary,
                  fontSize: 9,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 2.5,
                ),
              ),
            ],
          ),
        ],
      ),
      actions: [
        // Role chip
        if (wide)
          _AppBarChip(
            icon: Icons.verified_user_outlined,
            label: widget.store.role,
          ),
        if (wide) const SizedBox(width: 8),
        // Scanner button (wide)
        if (wide)
          _AppBarAction(
            icon: Icons.qr_code_scanner_rounded,
            label: 'ESCANEAR',
            onPressed: () => _scanProduct(context),
          ),
        if (wide) const SizedBox(width: 8),
        // New product button (wide)
        if (wide)
          Padding(
            padding: const EdgeInsets.only(right: 16),
            child: FilledButton.icon(
              onPressed: () => _openProductForm(context),
              icon: const Icon(Icons.add, size: 16),
              label: const Text(
                'NUEVO PRODUCTO',
                style: TextStyle(
                  fontWeight: FontWeight.w800,
                  letterSpacing: 1.2,
                  fontSize: 12,
                ),
              ),
            ),
          ),
        if (wide) const SizedBox(width: 8),
        // Install App button
        if (wide)
          _AppBarAction(
            icon: Icons.install_mobile_rounded,
            label: 'DESCARGAR APP',
            onPressed: () => _showInstallAppDialog(context),
          ),
        if (wide) const SizedBox(width: 8),
        if (!wide)
          IconButton(
            tooltip: 'Descargar / Instalar App',
            onPressed: () => _showInstallAppDialog(context),
            icon: const Icon(Icons.install_mobile_rounded, color: _Colors.magenta),
          ),
        // Logout
        IconButton(
          tooltip: 'Cerrar sesión',
          onPressed: widget.store.logout,
          icon: const Icon(Icons.logout, color: _Colors.textSecondary),
        ),
        const SizedBox(width: 4),
      ],
      bottom: PreferredSize(
        preferredSize: const Size.fromHeight(1),
        child: Container(
          height: 1,
          color: _Colors.strokeMagenta,
        ),
      ),
    );
  }

  Widget _buildNavRail() {
    const destinations = [
      NavigationRailDestination(
        icon: Icon(Icons.dashboard_outlined),
        selectedIcon: Icon(Icons.dashboard_rounded),
        label: Text('Resumen'),
      ),
      NavigationRailDestination(
        icon: Icon(Icons.inventory_2_outlined),
        selectedIcon: Icon(Icons.inventory_2),
        label: Text('Productos'),
      ),
      NavigationRailDestination(
        icon: Icon(Icons.label_outline),
        selectedIcon: Icon(Icons.label),
        label: Text('Categorías'),
      ),
      NavigationRailDestination(
        icon: Icon(Icons.swap_horiz_rounded),
        selectedIcon: Icon(Icons.swap_horiz_rounded),
        label: Text('Movimientos'),
      ),
    ];

    return Container(
      decoration: const BoxDecoration(
        color: _Colors.bgDeep,
        border: Border(right: BorderSide(color: _Colors.stroke, width: 1)),
      ),
      child: NavigationRail(
        selectedIndex: selectedIndex,
        onDestinationSelected: (value) => setState(() => selectedIndex = value),
        labelType: NavigationRailLabelType.all,
        destinations: destinations,
        backgroundColor: Colors.transparent,
      ),
    );
  }

  Widget _buildBottomNav() {
    return Container(
      decoration: const BoxDecoration(
        border: Border(top: BorderSide(color: _Colors.stroke, width: 1)),
      ),
      child: NavigationBar(
        selectedIndex: selectedIndex,
        onDestinationSelected: (value) => setState(() => selectedIndex = value),
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.dashboard_outlined),
            selectedIcon: Icon(Icons.dashboard_rounded),
            label: 'Resumen',
          ),
          NavigationDestination(
            icon: Icon(Icons.inventory_2_outlined),
            selectedIcon: Icon(Icons.inventory_2),
            label: 'Productos',
          ),
          NavigationDestination(
            icon: Icon(Icons.label_outline),
            selectedIcon: Icon(Icons.label),
            label: 'Categorías',
          ),
          NavigationDestination(
            icon: Icon(Icons.swap_horiz_rounded),
            label: 'Movimientos',
          ),
        ],
      ),
    );
  }

  Widget _page() => switch (selectedIndex) {
        0 => _Dashboard(
            store: widget.store,
            onShowProducts: () {
              setState(() {
                lowStockOnly = true;
                selectedIndex = 1;
              });
            },
          ),
        1 => _productsPage(),
        2 => CategoriesPage(store: widget.store),
        _ => _MovementsPage(store: widget.store),
      };

  Widget _productsPage() {
    final normalized = query.trim().toLowerCase();
    final catNormalized = selectedCategory.trim().toLowerCase();
    final isCategoryFilter = catNormalized.isNotEmpty &&
        catNormalized != 'todas' &&
        catNormalized != 'todas las categorías';

    final filteredAll = widget.store.products.where((product) {
      final matchesQuery = normalized.isEmpty ||
          product.name.toLowerCase().contains(normalized) ||
          product.sku.toLowerCase().contains(normalized) ||
          product.category.toLowerCase().contains(normalized);
      final matchesCategory = !isCategoryFilter ||
          product.category.toLowerCase() == catNormalized;
      return matchesQuery && matchesCategory && (!lowStockOnly || product.hasLowStock);
    }).toList()
      ..sort((a, b) => a.name.compareTo(b.name));

    final totalCount = filteredAll.length;
    final totalPages = (totalCount / pageSize).ceil().clamp(1, 9999);
    final activePage = currentPage.clamp(1, totalPages);
    final startIndex = (activePage - 1) * pageSize;
    final pagedProducts = filteredAll.skip(startIndex).take(pageSize).toList();

    return LayoutBuilder(
      builder: (context, constraints) {
        final screenWidth = constraints.maxWidth;
        final isMobile = screenWidth < 600;
        final int crossAxisCount;
        if (screenWidth < 600) {
          crossAxisCount = 2; // 2 columnas fijas en móvil
        } else if (screenWidth < 900) {
          crossAxisCount = 3;
        } else if (screenWidth < 1200) {
          crossAxisCount = 4;
        } else {
          crossAxisCount = 5;
        }

        return Padding(
          padding: EdgeInsets.all(isMobile ? 12 : 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // ── Page header ──────────────────────────────────────────────────
              _PageHeader(
                icon: Icons.storefront_rounded,
                title: 'CATÁLOGO DE PRODUCTOS',
                subtitle:
                    '${widget.store.products.length} productos registrados  ·  Mostrando ${pagedProducts.length} de $totalCount',
              ),
              const SizedBox(height: 16),

              // ── Filters row (Buscador, Categoría Select y Stock Bajo) ─────────
              Row(
                children: [
                  Expanded(
                    child: _SearchField(
                      onChanged: (value) => setState(() {
                        query = value;
                        currentPage = 1;
                      }),
                    ),
                  ),
                  const SizedBox(width: 8),
                  _CategorySelect(
                    selectedCategory: selectedCategory,
                    categories: widget.store.categoryNames,
                    onChanged: (value) => setState(() {
                      selectedCategory = value;
                      currentPage = 1;
                    }),
                  ),
                  const SizedBox(width: 8),
                  _FilterChip(
                    label: 'STOCK BAJO',
                    selected: lowStockOnly,
                    onSelected: (value) => setState(() {
                      lowStockOnly = value;
                      currentPage = 1;
                    }),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // ── Products Grid ────────────────────────────────────────────────
              Expanded(
                child: pagedProducts.isEmpty
                    ? const _EmptyState(
                        icon: Icons.search_off_rounded,
                        message: 'No se encontraron productos en el catálogo.',
                      )
                    : Column(
                        children: [
                          Expanded(
                            child: GridView.builder(
                              padding: const EdgeInsets.only(bottom: 12),
                              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                                crossAxisCount: crossAxisCount,
                                crossAxisSpacing: isMobile ? 10 : 16,
                                mainAxisSpacing: isMobile ? 12 : 18,
                                childAspectRatio: isMobile ? 0.58 : 0.62,
                              ),
                              itemCount: pagedProducts.length,
                              itemBuilder: (context, index) {
                                final product = pagedProducts[index];
                                return _CatalogProductCard(
                                  product: product,
                                  onOutgoing: () async {
                                    final err = await widget.store.quickSale(product);
                                    if (!context.mounted) return;
                                    if (err != null) {
                                      ScaffoldMessenger.of(context).showSnackBar(
                                        SnackBar(
                                          content: Text(err),
                                          backgroundColor: _Colors.red,
                                        ),
                                      );
                                    } else {
                                      ScaffoldMessenger.of(context).showSnackBar(
                                        SnackBar(
                                          content: Text(
                                            '¡Salida registrada! 1x "${product.name}" agregada a ganancias.',
                                          ),
                                          backgroundColor: _Colors.green,
                                          duration: const Duration(seconds: 2),
                                        ),
                                      );
                                    }
                                  },
                                  onIncoming: () async {
                                    final err = await widget.store.moveStock(
                                      product: product,
                                      quantity: 1,
                                      type: MovementType.incoming,
                                      note: 'Entrada rápida desde catálogo',
                                    );
                                    if (!context.mounted) return;
                                    if (err != null) {
                                      ScaffoldMessenger.of(context).showSnackBar(
                                        SnackBar(
                                          content: Text(err),
                                          backgroundColor: _Colors.red,
                                        ),
                                      );
                                    } else {
                                      ScaffoldMessenger.of(context).showSnackBar(
                                        SnackBar(
                                          content: Text(
                                            '¡Entrada registrada! 1x "${product.name}" agregada a inventario.',
                                          ),
                                          backgroundColor: _Colors.green,
                                          duration: const Duration(seconds: 2),
                                        ),
                                      );
                                    }
                                  },
                                  onStockDialog: () =>
                                      showStockDialog(context, widget.store, product),
                                  onEdit: () => _openProductForm(context, product),
                                  onDelete: () => _confirmDelete(context, product),
                                  onViewMedia: () => _showMediaViewer(context, product),
                                );
                              },
                            ),
                          ),

                          // ── Paginación de 30 Productos ─────────────────────
                          if (totalPages > 1) ...[
                            const SizedBox(height: 8),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                OutlinedButton.icon(
                                  onPressed: activePage > 1
                                      ? () => setState(() => currentPage = activePage - 1)
                                      : null,
                                  icon: const Icon(Icons.chevron_left, size: 16),
                                  label: const Text('Anterior'),
                                  style: OutlinedButton.styleFrom(
                                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                    textStyle: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Text(
                                  'Página $activePage de $totalPages  ($totalCount productos)',
                                  style: const TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w700,
                                    color: _Colors.textSecondary,
                                  ),
                                ),
                                const SizedBox(width: 12),
                                OutlinedButton.icon(
                                  onPressed: activePage < totalPages
                                      ? () => setState(() => currentPage = activePage + 1)
                                      : null,
                                  icon: const Icon(Icons.chevron_right, size: 16),
                                  label: const Text('Siguiente'),
                                  style: OutlinedButton.styleFrom(
                                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                    textStyle: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ],
                      ),
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _openProductForm(BuildContext context, [Product? product]) async {
    await showDialog<void>(
      context: context,
      builder: (_) => ProductForm(store: widget.store, product: product),
    );
  }

  Future<void> _scanProduct(BuildContext context) async {
    final code = await Navigator.push<String>(
      context,
      MaterialPageRoute(builder: (_) => const ScannerScreen()),
    );
    if (!context.mounted || code == null || code.isEmpty) return;

    final existing = widget.store.findByBarcode(code);
    if (existing != null) {
      await showStockDialog(context, widget.store, existing,
          incomingOnly: true, initialQuantity: 1);
    } else {
      await showDialog<void>(
        context: context,
        builder: (_) => ProductForm(store: widget.store, initialBarcode: code),
      );
    }
  }

  Future<void> _showMediaViewer(BuildContext context, Product product) async {
    Uint8List? memoryBytes;
    if (product.photoBase64.isNotEmpty) {
      try {
        memoryBytes = base64Decode(product.photoBase64);
      } on FormatException {
        memoryBytes = null;
      }
    }
    await showDialog<void>(
      context: context,
      builder: (dialogContext) => Dialog(
        backgroundColor: const Color(0xff18181b),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        clipBehavior: Clip.antiAlias,
        child: SizedBox(
          width: 550,
          height: 480,
          child: Column(
            children: [
              AppBar(
                backgroundColor: Colors.transparent,
                elevation: 0,
                title: Text(
                  product.name,
                  style: const TextStyle(color: Colors.white, fontSize: 14),
                ),
                leading: IconButton(
                  icon: const Icon(Icons.close, color: Colors.white),
                  onPressed: () => Navigator.pop(dialogContext),
                ),
              ),
              Expanded(
                child: product.isVideo
                    ? Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(
                              padding: const EdgeInsets.all(20),
                              decoration: BoxDecoration(
                                color: Colors.white.withValues(alpha: 0.15),
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(Icons.play_arrow_rounded,
                                  size: 64, color: Colors.white),
                            ),
                            const SizedBox(height: 16),
                            Text(
                              'Video de ${product.name}',
                              style: const TextStyle(color: Colors.white, fontSize: 16),
                            ),
                          ],
                        ),
                      )
                    : memoryBytes != null
                        ? InteractiveViewer(
                            minScale: 0.8,
                            maxScale: 4.0,
                            child: Image.memory(memoryBytes, fit: BoxFit.contain),
                          )
                        : product.imageUrl.isNotEmpty
                            ? InteractiveViewer(
                                minScale: 0.8,
                                maxScale: 4.0,
                                child: Image.network(
                                  product.imageUrl,
                                  fit: BoxFit.contain,
                                  errorBuilder: (_, __, ___) => const Center(
                                    child: Icon(Icons.broken_image_rounded,
                                        size: 64, color: Colors.white38),
                                  ),
                                ),
                              )
                            : const Center(
                                child: Icon(Icons.inventory_2_outlined,
                                    size: 64, color: Colors.white38),
                              ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _confirmDelete(BuildContext context, Product product) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('ELIMINAR PRODUCTO'),
        content: Text(
          '¿Deseas eliminar "${product.name}"?\nEsta acción no se puede deshacer.',
          style: const TextStyle(color: _Colors.textSecondary, height: 1.5),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('CANCELAR'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            style: FilledButton.styleFrom(
              backgroundColor: _Colors.red,
              foregroundColor: Colors.white,
            ),
            child: const Text('ELIMINAR'),
          ),
        ],
      ),
    );
    if (confirmed == true) await widget.store.deleteProduct(product.id);
  }

  void _showInstallAppDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (dialogContext) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        child: Container(
          width: 500,
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: _Colors.magenta.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(Icons.install_mobile_rounded, color: _Colors.magenta, size: 24),
                  ),
                  const SizedBox(width: 14),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'DESCARGAR / INSTALAR APLICACIÓN',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 1.2,
                            color: _Colors.textPrimary,
                          ),
                        ),
                        Text(
                          'Instala My Love Depot en tu Android, iPhone o iPad',
                          style: TextStyle(fontSize: 11, color: _Colors.textSecondary),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.pop(dialogContext),
                    icon: const Icon(Icons.close),
                  ),
                ],
              ),

              const SizedBox(height: 16),
              const Divider(),
              const SizedBox(height: 16),

              // iOS Guide
              const Row(
                children: [
                  Icon(Icons.apple, color: _Colors.magenta, size: 20),
                  SizedBox(width: 8),
                  Text(
                    'EN IPHONE / IPAD (iOS Safari):',
                    style: TextStyle(fontWeight: FontWeight.w800, fontSize: 12, color: _Colors.magenta, letterSpacing: 0.5),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xfffff6fa),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: _Colors.stroke),
                ),
                child: const Column(
                  children: [
                    _InstallStep(number: '1', text: 'Abre Safari y toca el botón Compartir (cuadro con flecha ⎋ arriba o abajo).'),
                    SizedBox(height: 6),
                    _InstallStep(number: '2', text: 'Desplázate hacia abajo y selecciona "Agregar a inicio" (Add to Home Screen 📲).'),
                    SizedBox(height: 6),
                    _InstallStep(number: '3', text: 'Toca "Agregar". ¡La app aparecerá en tu iPhone como una app nativa!'),
                  ],
                ),
              ),

              const SizedBox(height: 16),

              // Android Guide
              const Row(
                children: [
                  Icon(Icons.android_rounded, color: _Colors.green, size: 20),
                  SizedBox(width: 8),
                  Text(
                    'EN ANDROID / CHROME / EDGE:',
                    style: TextStyle(fontWeight: FontWeight.w800, fontSize: 12, color: _Colors.green, letterSpacing: 0.5),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xfff0fdf4),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.green),
                ),
                child: const Column(
                  children: [
                    _InstallStep(number: '1', text: 'Toca los tres puntos (⋮) en la esquina de tu navegador Chrome o Edge.'),
                    SizedBox(height: 6),
                    _InstallStep(number: '2', text: 'Selecciona "Instalar aplicación" o "Agregar a la pantalla principal".'),
                  ],
                ),
              ),

              const SizedBox(height: 20),

              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  if (PwaHelpers.isPwaInstallAvailable()) ...[
                    FilledButton.icon(
                      onPressed: () async {
                        Navigator.pop(dialogContext);
                        await PwaHelpers.triggerPwaInstall();
                      },
                      icon: const Icon(Icons.download_rounded, size: 18),
                      style: FilledButton.styleFrom(
                        backgroundColor: _Colors.magenta,
                        foregroundColor: Colors.white,
                      ),
                      label: const Text('INSTALAR AHORA', style: TextStyle(fontWeight: FontWeight.w800, letterSpacing: 1.1)),
                    ),
                    const SizedBox(width: 12),
                  ],
                  OutlinedButton.icon(
                    onPressed: () => Navigator.pop(dialogContext),
                    icon: const Icon(Icons.check_circle_outline_rounded, size: 18),
                    label: const Text('¡ENTENDIDO!', style: TextStyle(fontWeight: FontWeight.w800, letterSpacing: 1.1)),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── AppBar helpers ─────────────────────────────────────────────────────────────
class _AppBarChip extends StatelessWidget {
  const _AppBarChip({required this.icon, required this.label});
  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: _Colors.bgCard,
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: _Colors.stroke, width: 1),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: _Colors.magenta),
          const SizedBox(width: 6),
          Text(
            label.toUpperCase(),
            style: const TextStyle(
              color: _Colors.textSecondary,
              fontSize: 11,
              fontWeight: FontWeight.w700,
              letterSpacing: 1,
            ),
          ),
        ],
      ),
    );
  }
}

class _AppBarAction extends StatelessWidget {
  const _AppBarAction(
      {required this.icon, required this.label, required this.onPressed});
  final IconData icon;
  final String label;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return OutlinedButton.icon(
      onPressed: onPressed,
      icon: Icon(icon, size: 16),
      label: Text(
        label,
        style: const TextStyle(
          fontWeight: FontWeight.w700,
          letterSpacing: 1.2,
          fontSize: 11,
        ),
      ),
      style: OutlinedButton.styleFrom(
        foregroundColor: _Colors.textPrimary,
        side: const BorderSide(color: _Colors.stroke, width: 1),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      ),
    );
  }
}

// ── Page header ────────────────────────────────────────────────────────────────
class _PageHeader extends StatelessWidget {
  const _PageHeader(
      {required this.icon,
      required this.title,
      required this.subtitle});
  final IconData icon;
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 3,
          height: 36,
          decoration: BoxDecoration(
            color: _Colors.magenta,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        const SizedBox(width: 14),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: const TextStyle(
                color: _Colors.textPrimary,
                fontSize: 15,
                fontWeight: FontWeight.w800,
                letterSpacing: 2,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              subtitle,
              style: const TextStyle(
                color: _Colors.textSecondary,
                fontSize: 11,
                letterSpacing: 0.3,
              ),
            ),
          ],
        ),
      ],
    );
  }
}

// ── Search field ──────────────────────────────────────────────────────────────
class _SearchField extends StatelessWidget {
  const _SearchField({required this.onChanged});
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 42,
      decoration: BoxDecoration(
        color: _Colors.bgDeep,
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: _Colors.stroke, width: 1),
      ),
      child: TextField(
        onChanged: onChanged,
        style: const TextStyle(color: _Colors.textPrimary, fontSize: 13),
        decoration: const InputDecoration(
          hintText: 'Buscar por nombre, SKU o categoría…',
          hintStyle: TextStyle(color: _Colors.textSecondary, fontSize: 13),
          prefixIcon:
              Icon(Icons.search, color: _Colors.textSecondary, size: 18),
          border: InputBorder.none,
          enabledBorder: InputBorder.none,
          focusedBorder: InputBorder.none,
          contentPadding: EdgeInsets.symmetric(vertical: 12),
        ),
      ),
    );
  }
}

// ── Filter chip ────────────────────────────────────────────────────────────────
class _FilterChip extends StatelessWidget {
  const _FilterChip(
      {required this.label,
      required this.selected,
      required this.onSelected});
  final String label;
  final bool selected;
  final ValueChanged<bool> onSelected;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => onSelected(!selected),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: selected ? _Colors.magentaGlow : _Colors.bgDeep,
          borderRadius: BorderRadius.circular(4),
          border: Border.all(
            color: selected ? _Colors.magenta : _Colors.stroke,
            width: 1,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              selected
                  ? Icons.warning_amber_rounded
                  : Icons.warning_amber_outlined,
              size: 14,
              color: selected ? _Colors.magenta : _Colors.textSecondary,
            ),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                color: selected ? _Colors.magenta : _Colors.textSecondary,
                fontSize: 11,
                fontWeight: FontWeight.w700,
                letterSpacing: 1.5,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Card de Producto Tipo Catálogo (Sin Mayoreo / Interacción Directa) ─────────
class _CatalogProductCard extends StatelessWidget {
  const _CatalogProductCard({
    required this.product,
    required this.onIncoming,
    required this.onOutgoing,
    required this.onStockDialog,
    required this.onEdit,
    required this.onDelete,
    required this.onViewMedia,
  });

  final Product product;
  final VoidCallback onIncoming;
  final VoidCallback onOutgoing;
  final VoidCallback onStockDialog;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  final VoidCallback onViewMedia;

  @override
  Widget build(BuildContext context) {
    final isAgotado = product.stock <= 0;
    Uint8List? memoryBytes;
    if (product.photoBase64.isNotEmpty) {
      try {
        memoryBytes = base64Decode(product.photoBase64);
      } on FormatException {
        memoryBytes = null;
      }
    }

    final categoryLower = product.category.toLowerCase();
    Color categoryBg;
    Color categoryText;
    if (categoryLower.contains('hombre')) {
      categoryBg = const Color(0xffe0f2fe);
      categoryText = const Color(0xff0284c7);
    } else if (categoryLower.contains('mujer')) {
      categoryBg = const Color(0xfffce7f3);
      categoryText = const Color(0xffdb2777);
    } else if (categoryLower.contains('unisex')) {
      categoryBg = const Color(0xfff3e8ff);
      categoryText = const Color(0xff9333ea);
    } else {
      categoryBg = const Color(0xfff1f5f9);
      categoryText = const Color(0xff475569);
    }

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xffefe4eb), width: 1),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // ── Contenedor Superior de Imagen / Video ──────────────────────────
          Expanded(
            flex: 12,
            child: GestureDetector(
              onTap: onViewMedia,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  // Fondo oscuro estético
                  Container(
                    color: const Color(0xff1f1d1e),
                    child: memoryBytes != null
                        ? Image.memory(
                            memoryBytes,
                            fit: BoxFit.cover,
                          )
                        : product.imageUrl.isNotEmpty
                            ? Image.network(
                                product.imageUrl,
                                fit: BoxFit.cover,
                                errorBuilder: (_, __, ___) => const Center(
                                  child: Icon(Icons.broken_image_rounded,
                                      color: Colors.white38, size: 36),
                                ),
                              )
                            : Center(
                                child: Icon(
                                  product.isVideo
                                      ? Icons.videocam_rounded
                                      : Icons.inventory_2_outlined,
                                  color: Colors.white38,
                                  size: 44,
                                ),
                              ),
                  ),

                  // Scrim oscurecido si está agotado
                  if (isAgotado)
                    Container(
                      color: Colors.black.withValues(alpha: 0.42),
                    ),

                  // Chip de Categoría (Superior Izquierda)
                  Positioned(
                    top: 8,
                    left: 8,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: categoryBg.withValues(alpha: 0.95),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        product.category.toUpperCase(),
                        style: TextStyle(
                          color: categoryText,
                          fontSize: 9,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ),
                  ),

                  // Botones de acción rápida sobre la imagen (Superior Derecha)
                  Positioned(
                    top: 6,
                    right: 6,
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (product.isVideo) ...[
                          Container(
                            padding: const EdgeInsets.all(5),
                            decoration: BoxDecoration(
                              color: Colors.black.withValues(alpha: 0.65),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(Icons.play_arrow_rounded,
                                color: Colors.white, size: 14),
                          ),
                          const SizedBox(width: 4),
                        ],
                        // Botón Editar (Lápiz)
                        Material(
                          color: Colors.black.withValues(alpha: 0.55),
                          shape: const CircleBorder(),
                          clipBehavior: Clip.antiAlias,
                          child: InkWell(
                            onTap: onEdit,
                            child: const Padding(
                              padding: EdgeInsets.all(6),
                              child: Icon(Icons.edit_rounded,
                                  color: Colors.white, size: 14),
                            ),
                          ),
                        ),
                        const SizedBox(width: 4),
                        // Botón Eliminar (Basura)
                        Material(
                          color: Colors.black.withValues(alpha: 0.55),
                          shape: const CircleBorder(),
                          clipBehavior: Clip.antiAlias,
                          child: InkWell(
                            onTap: onDelete,
                            child: const Padding(
                              padding: EdgeInsets.all(6),
                              child: Icon(Icons.delete_outline_rounded,
                                  color: Colors.white, size: 14),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                  // Insignia central blanca "AGOTADO"
                  if (isAgotado)
                    Center(
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 14, vertical: 6),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(2),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.25),
                              blurRadius: 6,
                            ),
                          ],
                        ),
                        child: const Text(
                          'AGOTADO',
                          style: TextStyle(
                            color: Colors.black,
                            fontSize: 11,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 1.8,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),

          // ── Cuerpo de Información e Interacción Directa ─────────────────────
          Expanded(
            flex: 12,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(10, 8, 10, 10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Título con tipografía editorial / elegante
                      Text(
                        product.name,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontFamily: 'serif',
                          fontSize: 13,
                          fontWeight: FontWeight.w800,
                          color: Color(0xff18181b),
                          height: 1.2,
                        ),
                      ),
                      const SizedBox(height: 4),

                      // Stock e Indicador
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: isAgotado
                                  ? const Color(0xfffee2e2)
                                  : product.hasLowStock
                                      ? const Color(0xfffef3c7)
                                      : const Color(0xffdcfce7),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              isAgotado
                                  ? 'SIN STOCK'
                                  : 'STOCK: ${product.stock}',
                              style: TextStyle(
                                color: isAgotado
                                    ? const Color(0xff991b1b)
                                    : product.hasLowStock
                                        ? const Color(0xff92400e)
                                        : const Color(0xff166534),
                                fontSize: 9.5,
                                fontWeight: FontWeight.w800,
                                letterSpacing: 0.3,
                              ),
                            ),
                          ),
                          if (product.sku.isNotEmpty) ...[
                            const SizedBox(width: 6),
                            Expanded(
                              child: Text(
                                'SKU: ${product.sku}',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  color: Color(0xff94a3b8),
                                  fontSize: 9.5,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ],
                  ),

                  // Precio Limpio (Sin mayoreo ni precios tachados irrelevantes)
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        '\$${product.price.toStringAsFixed(product.price.truncateToDouble() == product.price ? 0 : 2)}',
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w900,
                          color: Color(0xff18181b),
                          letterSpacing: -0.5,
                        ),
                      ),

                      // Botón para ajustar existencias arbitrarias
                      InkWell(
                        onTap: onStockDialog,
                        borderRadius: BorderRadius.circular(6),
                        child: Padding(
                          padding: const EdgeInsets.all(4),
                          child: Row(
                            children: [
                              Icon(Icons.swap_vert_rounded,
                                  size: 15, color: Colors.grey.shade600),
                              const SizedBox(width: 2),
                              Text(
                                'Ajustar',
                                style: TextStyle(
                                  fontSize: 10,
                                  color: Colors.grey.shade700,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),

                  // ── Botones Directos de ENTRADA (+1) y SALIDA/VENTA (-1) ───
                  Row(
                    children: [
                      // Botón ENTRADA (+1)
                      Expanded(
                        child: SizedBox(
                          height: 32,
                          child: OutlinedButton.icon(
                            onPressed: onIncoming,
                            icon: const Icon(Icons.add_rounded, size: 14),
                            label: const Text('ENTRADA'),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: const Color(0xff0284c7),
                              side: const BorderSide(
                                  color: Color(0xff0284c7), width: 1.2),
                              padding: EdgeInsets.zero,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(20),
                              ),
                              textStyle: const TextStyle(
                                fontSize: 9.5,
                                fontWeight: FontWeight.w800,
                                letterSpacing: 0.5,
                              ),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 6),

                      // Botón SALIDA / VENTA (-1)
                      Expanded(
                        child: SizedBox(
                          height: 32,
                          child: ElevatedButton.icon(
                            onPressed: isAgotado ? null : onOutgoing,
                            icon: const Icon(Icons.remove_rounded, size: 14),
                            label: const Text('SALIDA'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xff006847),
                              foregroundColor: Colors.white,
                              disabledBackgroundColor: const Color(0xffe2e8f0),
                              disabledForegroundColor: const Color(0xff94a3b8),
                              padding: EdgeInsets.zero,
                              elevation: 0,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(20),
                              ),
                              textStyle: const TextStyle(
                                fontSize: 9.5,
                                fontWeight: FontWeight.w800,
                                letterSpacing: 0.5,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Empty state ────────────────────────────────────────────────────────────────
class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.icon, required this.message});
  final IconData icon;
  final String message;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: _Colors.textSecondary, size: 48),
          const SizedBox(height: 12),
          Text(
            message,
            style: const TextStyle(color: _Colors.textSecondary, fontSize: 14),
          ),
        ],
      ),
    );
  }
}

// ── Section divider ─────────────────────────────────────────────────────────────

class _SectionDivider extends StatelessWidget {
  const _SectionDivider({required this.label});
  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Text(
          label,
          style: const TextStyle(
            color: _Colors.textSecondary,
            fontSize: 11,
            fontWeight: FontWeight.w800,
            letterSpacing: 1.2,
          ),
        ),
        const SizedBox(width: 10),
        const Expanded(
          child: Divider(color: _Colors.stroke, thickness: 1),
        ),
      ],
    );
  }
}

// ── Category Select Dropdown ───────────────────────────────────────────────────
class _CategorySelect extends StatelessWidget {
  const _CategorySelect({
    required this.selectedCategory,
    required this.categories,
    required this.onChanged,
  });

  final String selectedCategory;
  final List<String> categories;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    final allCategories = <String>[
      'Todas las categorías',
      ...categories.where((c) => c.trim().isNotEmpty),
    ];

    final effectiveValue = allCategories.contains(selectedCategory)
        ? selectedCategory
        : 'Todas las categorías';

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
      decoration: BoxDecoration(
        color: _Colors.bgDeep,
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: _Colors.stroke, width: 1),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: effectiveValue,
          icon: const Icon(Icons.keyboard_arrow_down_rounded,
              size: 16, color: _Colors.textSecondary),
          isDense: true,
          style: const TextStyle(
            color: _Colors.textPrimary,
            fontSize: 10.5,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.5,
          ),
          items: allCategories.map((cat) {
            return DropdownMenuItem<String>(
              value: cat,
              child: Text(cat.toUpperCase()),
            );
          }).toList(),
          onChanged: (val) {
            if (val != null) onChanged(val);
          },
        ),
      ),
    );
  }
}

// ── Dashboard ──────────────────────────────────────────────────────────────────
class _Dashboard extends StatelessWidget {
  const _Dashboard({required this.store, required this.onShowProducts});
  final InventoryStore store;
  final VoidCallback onShowProducts;

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();

    return LayoutBuilder(
      builder: (context, constraints) {
        final screenWidth = constraints.maxWidth;
        final isMobile = screenWidth < 680;

        final cards = [
          // 1. Unidades en Stock
          _MetricCard(
            icon: Icons.layers_rounded,
            label: 'UNIDADES (STOCK)',
            value: '${store.totalUnits}',
            subtitle: 'Total en existencia',
            accent: const Color(0xff2563eb),
            badgeColor: const Color(0xffeff6ff),
          ),
          // 2. Valor Almacén
          _MetricCard(
            icon: Icons.attach_money_rounded,
            label: 'VALOR ALMACÉN',
            value: '\$${store.inventoryValue.toStringAsFixed(2)}',
            subtitle: 'Estimado actual',
            accent: const Color(0xff0d9488),
            badgeColor: const Color(0xfff0fdfa),
          ),
          // 3. Ganancias Hoy
          _MetricCard(
            icon: Icons.point_of_sale_rounded,
            label: 'GANANCIAS HOY',
            value: '\$${store.todayEarnings.toStringAsFixed(2)}',
            subtitle: '${store.todaySalesUnits} salidas hoy',
            accent: const Color(0xff059669),
            badgeColor: const Color(0xffecfdf5),
          ),
          // 4. Ganancias Mes
          _MetricCard(
            icon: Icons.savings_rounded,
            label: 'GANANCIAS MES',
            value: '\$${store.monthEarnings.toStringAsFixed(2)}',
            subtitle: '${store.monthSalesUnits} salidas este mes',
            accent: const Color(0xff7c3aed),
            badgeColor: const Color(0xfff5f3ff),
          ),
        ];

        return SingleChildScrollView(
          padding: EdgeInsets.all(isMobile ? 14 : 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── Header ────────────────────────────────────────────────────
              _PageHeader(
                icon: Icons.dashboard_outlined,
                title: 'RESUMEN DEL ALMACÉN',
                subtitle:
                    'Estado en tiempo real  ·  ${now.day}/${now.month}/${now.year}',
              ),
              const SizedBox(height: 16),

              // ── Subtler Compact Metric Grid (Sutil y elegante) ─────────────
              GridView.count(
                crossAxisCount: isMobile ? 2 : 4,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                crossAxisSpacing: isMobile ? 10 : 14,
                mainAxisSpacing: isMobile ? 10 : 14,
                childAspectRatio: isMobile ? 2.3 : 2.8,
                children: cards,
              ),

              const SizedBox(height: 28),
              const _SectionDivider(label: 'ATENCIÓN REQUERIDA'),
              const SizedBox(height: 16),

              // ── Low stock list ────────────────────────────────────────────
              if (store.lowStockCount == 0)
                Container(
                  padding: const EdgeInsets.all(18),
                  decoration: BoxDecoration(
                    color: _Colors.bgCard,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                        color: _Colors.green.withValues(alpha: 0.3), width: 1),
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: _Colors.green.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Icon(Icons.check_circle_outline,
                            color: _Colors.green, size: 22),
                      ),
                      const SizedBox(width: 14),
                      const Expanded(
                        child: Text(
                          'Excelente: Todos los productos cuentan con existencias suficientes.',
                          style: TextStyle(
                              color: _Colors.textPrimary,
                              fontSize: 13,
                              fontWeight: FontWeight.w600),
                        ),
                      ),
                    ],
                  ),
                )
              else
                ...store.products.where((item) => item.hasLowStock).map(
                      (product) => Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: _LowStockTile(
                            product: product, onTap: onShowProducts),
                      ),
                    ),
            ],
          ),
        );
      },
    );
  }
}

class _LowStockTile extends StatelessWidget {
  const _LowStockTile({required this.product, required this.onTap});
  final Product product;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: _Colors.bgCard,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
              color: _Colors.amber.withValues(alpha: 0.35), width: 1),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(7),
              decoration: BoxDecoration(
                color: _Colors.amber.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(6),
              ),
              child: const Icon(Icons.warning_amber_rounded,
                  color: _Colors.amber, size: 18),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    product.name,
                    style: const TextStyle(
                      color: _Colors.textPrimary,
                      fontWeight: FontWeight.w700,
                      fontSize: 13,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '${product.stock} disponibles  ·  mínimo ${product.minimumStock}',
                    style: const TextStyle(
                        color: _Colors.textSecondary, fontSize: 12),
                  ),
                ],
              ),
            ),
            const Icon(Icons.chevron_right, color: _Colors.textSecondary),
          ],
        ),
      ),
    );
  }
}

// ── Metric card (Subtle & Compact) ─────────────────────────────────────────────
class _MetricCard extends StatelessWidget {
  const _MetricCard({
    required this.icon,
    required this.label,
    required this.value,
    required this.accent,
    this.subtitle,
    this.badgeColor,
  });

  final IconData icon;
  final String label;
  final String value;
  final Color accent;
  final String? subtitle;
  final Color? badgeColor;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: _Colors.bgCard,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: const Color(0xffede0e7),
            width: 1,
          ),
          boxShadow: [
            BoxShadow(
              color: accent.withValues(alpha: 0.04),
              blurRadius: 6,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(7),
              decoration: BoxDecoration(
                color: badgeColor ?? accent.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(icon, color: accent, size: 18),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: Alignment.centerLeft,
                    child: Text(
                      value,
                      style: TextStyle(
                        color: accent,
                        fontSize: 16,
                        fontWeight: FontWeight.w900,
                        letterSpacing: -0.3,
                      ),
                    ),
                  ),
                  const SizedBox(height: 1),
                  Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: _Colors.textSecondary,
                      fontSize: 8.5,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0.8,
                    ),
                  ),
                  if (subtitle != null) ...[
                    Text(
                      subtitle!,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: _Colors.textSecondary.withValues(alpha: 0.75),
                        fontSize: 8,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      );
    }
}

// ── Movements page ─────────────────────────────────────────────────────────────
class _MovementsPage extends StatelessWidget {
  const _MovementsPage({required this.store});
  final InventoryStore store;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _PageHeader(
            icon: Icons.swap_horiz_rounded,
            title: 'HISTORIAL DE MOVIMIENTOS',
            subtitle: 'Registro de entradas y salidas de inventario',
          ),
          const SizedBox(height: 20),
          Expanded(
            child: store.movements.isEmpty
                ? _EmptyState(
                    icon: Icons.swap_horiz_outlined,
                    message:
                        'Todavía no hay entradas ni salidas registradas.',
                  )
                : ListView.separated(
                    itemCount: store.movements.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 8),
                    itemBuilder: (context, index) {
                      final movement = store.movements[index];
                      final incoming =
                          movement.type == MovementType.incoming;
                      final color =
                          incoming ? _Colors.green : _Colors.magenta;
                      return Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 14),
                        decoration: BoxDecoration(
                          color: _Colors.bgCard,
                          borderRadius: BorderRadius.circular(4),
                          border: Border.all(color: _Colors.stroke, width: 1),
                        ),
                        child: Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: color.withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Icon(
                                incoming
                                    ? Icons.south_west_rounded
                                    : Icons.north_east_rounded,
                                color: color,
                                size: 18,
                              ),
                            ),
                            const SizedBox(width: 14),
                            Expanded(
                              child: Column(
                                crossAxisAlignment:
                                    CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    movement.productName,
                                    style: const TextStyle(
                                      color: _Colors.textPrimary,
                                      fontWeight: FontWeight.w700,
                                      fontSize: 13,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    _date(movement.createdAt) +
                                        (movement.note.isEmpty
                                            ? ''
                                            : '  ·  ${movement.note}'),
                                    style: const TextStyle(
                                        color: _Colors.textSecondary,
                                        fontSize: 11),
                                  ),
                                ],
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 10, vertical: 5),
                              decoration: BoxDecoration(
                                color: color.withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(4),
                                border: Border.all(
                                    color: color.withValues(alpha: 0.25), width: 1),
                              ),
                              child: Text(
                                '${incoming ? '+' : '-'}${movement.quantity}',
                                style: TextStyle(
                                  color: color,
                                  fontWeight: FontWeight.w800,
                                  fontSize: 16,
                                ),
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  String _date(DateTime date) {
    String two(int value) => value.toString().padLeft(2, '0');
    return '${two(date.day)}/${two(date.month)}/${date.year} '
        '${two(date.hour)}:${two(date.minute)}';
  }
}

class _InstallStep extends StatelessWidget {
  const _InstallStep({required this.number, required this.text});
  final String number;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 20,
          height: 20,
          alignment: Alignment.center,
          decoration: const BoxDecoration(
            color: _Colors.magenta,
            shape: BoxShape.circle,
          ),
          child: Text(
            number,
            style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            text,
            style: const TextStyle(fontSize: 12, color: _Colors.textPrimary, height: 1.3),
          ),
        ),
      ],
    );
  }
}
