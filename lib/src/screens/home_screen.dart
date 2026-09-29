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
import 'stock_dialog.dart';

// ── Paleta de colores centralizada (LIGHT — refinada) ─────────────────────────
class _C {
  static const magenta = Color(0xffd94f87);
  static const magentaDeep = Color(0xffb5296b);
  static const bgDeep = Color(0xfffff6fa);
  static const bgBase = Color(0xfffff6fa);
  static const bgCard = Color(0xffffffff);
  static const bgSurface = Color(0xfffffbfd);
  static const stroke = Color(0xffe8d0da);
  static const strokeLight = Color(0xfff3e4ed);
  static const strokeMagenta = Color(0x33d94f87);
  static const textPrimary = Color(0xff3a2633);
  static const textSecondary = Color(0xff7a5c6b);
  static const green = Color(0xff16a34a);
  static const amber = Color(0xffb45309);
  static const red = Color(0xffb00020);
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
          return Scaffold(
            backgroundColor: _C.bgBase,
            body: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const LoveMascot(size: 80, animate: true),
                  const SizedBox(height: 20),
                  const SizedBox(
                    width: 120,
                    child: LinearProgressIndicator(
                      color: _C.magenta,
                      backgroundColor: Color(0xffffedf5),
                      borderRadius: BorderRadius.all(Radius.circular(8)),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'Cargando tu inventario…',
                    style: TextStyle(
                      color: _C.textSecondary.withValues(alpha: 0.7),
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          );
        }
        return LayoutBuilder(
          builder: (context, constraints) {
            final wide = constraints.maxWidth >= 760;
            return Scaffold(
              backgroundColor: _C.bgBase,
              appBar: _buildAppBar(context, wide),
              body: Row(
                children: [
                  if (wide) _buildNavRail(constraints.maxWidth),
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
                  : Container(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(18),
                        gradient: const LinearGradient(
                          colors: [_C.magenta, _C.magentaDeep],
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: _C.magenta.withValues(alpha: 0.3),
                            blurRadius: 14,
                            offset: const Offset(0, 5),
                          ),
                        ],
                      ),
                      child: FloatingActionButton.extended(
                        onPressed: () => _openProductForm(context),
                        backgroundColor: Colors.transparent,
                        foregroundColor: Colors.white,
                        elevation: 0,
                        highlightElevation: 0,
                        icon: const Icon(Icons.add_rounded, size: 20),
                        label: const Text(
                          'NUEVO',
                          style: TextStyle(
                            fontWeight: FontWeight.w800,
                            letterSpacing: 1.2,
                            fontSize: 12,
                          ),
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
      backgroundColor: _C.bgDeep,
      elevation: 0,
      scrolledUnderElevation: 0,
      toolbarHeight: 58,
      title: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  _C.bgSurface,
                  _C.magenta.withValues(alpha: 0.06),
                ],
              ),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: _C.strokeMagenta, width: 1),
              boxShadow: [
                BoxShadow(
                  color: _C.magenta.withValues(alpha: 0.06),
                  blurRadius: 8,
                ),
              ],
            ),
            child: const LoveMascot(size: 28),
          ),
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              ShaderMask(
                shaderCallback: (bounds) => const LinearGradient(
                  colors: [_C.magenta, _C.magentaDeep],
                ).createShader(bounds),
                child: const Text(
                  'MY LOVE DEPOT',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 2,
                  ),
                ),
              ),
              Text(
                'GESTIÓN DE ALMACÉN',
                style: TextStyle(
                  color: _C.textSecondary.withValues(alpha: 0.7),
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
        // New product button (wide)
        if (wide)
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                gradient: const LinearGradient(
                  colors: [_C.magenta, _C.magentaDeep],
                ),
                boxShadow: [
                  BoxShadow(
                    color: _C.magenta.withValues(alpha: 0.25),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
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
                style: FilledButton.styleFrom(
                  backgroundColor: Colors.transparent,
                  foregroundColor: Colors.white,
                  shadowColor: Colors.transparent,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
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
            icon: const Icon(Icons.install_mobile_rounded, color: _C.magenta),
          ),
        // Logout
        Container(
          margin: const EdgeInsets.symmetric(horizontal: 4),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(8),
            color: _C.red.withValues(alpha: 0.06),
          ),
          child: IconButton(
            tooltip: 'Cerrar sesión',
            onPressed: widget.store.logout,
            icon: Icon(Icons.logout_rounded,
                color: _C.textSecondary.withValues(alpha: 0.7), size: 20),
          ),
        ),
        const SizedBox(width: 4),
      ],
      bottom: PreferredSize(
        preferredSize: const Size.fromHeight(1),
        child: Container(
          height: 1,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                _C.magenta.withValues(alpha: 0.1),
                _C.magenta.withValues(alpha: 0.25),
                _C.magenta.withValues(alpha: 0.1),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildNavRail(double width) {
    final isExtended = width >= 1000;
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
      NavigationRailDestination(
        icon: Icon(Icons.account_balance_wallet_outlined),
        selectedIcon: Icon(Icons.account_balance_wallet_rounded),
        label: Text('Finanzas'),
      ),
    ];

    return Container(
      decoration: BoxDecoration(
        color: _C.bgDeep,
        border: const Border(right: BorderSide(color: _C.stroke, width: 1)),
        boxShadow: [
          BoxShadow(
            color: _C.magenta.withValues(alpha: 0.03),
            blurRadius: 10,
          ),
        ],
      ),
      child: NavigationRail(
        extended: isExtended,
        leading: isExtended
            ? Padding(
                padding: const EdgeInsets.only(bottom: 16),
                child: Column(
                  children: [
                    const LoveMascot(size: 40),
                    const SizedBox(height: 8),
                    ShaderMask(
                      shaderCallback: (bounds) => const LinearGradient(
                        colors: [_C.magenta, _C.magentaDeep],
                      ).createShader(bounds),
                      child: const Text(
                        'DEPOT',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 2,
                        ),
                      ),
                    ),
                  ],
                ),
              )
            : const Padding(
                padding: EdgeInsets.only(bottom: 16),
                child: LoveMascot(size: 32),
              ),
        selectedIndex: selectedIndex,
        onDestinationSelected: (value) =>
            setState(() => selectedIndex = value),
        labelType: NavigationRailLabelType.all,
        destinations: destinations,
        backgroundColor: Colors.transparent,
      ),
    );
  }

  Widget _buildBottomNav() {
    return Container(
      decoration: BoxDecoration(
        border: const Border(top: BorderSide(color: _C.stroke, width: 1)),
        boxShadow: [
          BoxShadow(
            color: _C.magenta.withValues(alpha: 0.05),
            blurRadius: 12,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: NavigationBar(
        selectedIndex: selectedIndex,
        onDestinationSelected: (value) =>
            setState(() => selectedIndex = value),
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
          NavigationDestination(
            icon: Icon(Icons.account_balance_wallet_outlined),
            selectedIcon: Icon(Icons.account_balance_wallet_rounded),
            label: 'Finanzas',
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
        3 => _MovementsPage(store: widget.store),
        _ => _FinanzasPage(store: widget.store),
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
      return matchesQuery &&
          matchesCategory &&
          (!lowStockOnly || product.hasLowStock);
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
          crossAxisCount = 2;
        } else if (screenWidth < 900) {
          crossAxisCount = 3;
        } else if (screenWidth < 1200) {
          crossAxisCount = 4;
        } else {
          crossAxisCount = 5;
        }

        return Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 1400),
            child: Padding(
              padding: EdgeInsets.all(isMobile ? 12 : 24),
              child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // ── Page header ──────────────────────────────────────────────
              _PageHeader(
                icon: Icons.storefront_rounded,
                title: 'CATÁLOGO DE PRODUCTOS',
                subtitle:
                    '${widget.store.products.length} productos registrados  ·  Mostrando ${pagedProducts.length} de $totalCount',
              ),
              const SizedBox(height: 16),

              // ── Filters row ──────────────────────────────────────────────
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: _C.bgCard,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: _C.strokeLight, width: 1),
                  boxShadow: [
                    BoxShadow(
                      color: _C.magenta.withValues(alpha: 0.03),
                      blurRadius: 8,
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: _SearchField(
                        onChanged: (value) => setState(() {
                          query = value;
                          currentPage = 1;
                        }),
                      ),
                    ),
                    const SizedBox(width: 10),
                    _CategorySelect(
                      selectedCategory: selectedCategory,
                      categories: widget.store.categoryNames,
                      onChanged: (value) => setState(() {
                        selectedCategory = value;
                        currentPage = 1;
                      }),
                    ),
                    const SizedBox(width: 10),
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
              ),
              const SizedBox(height: 16),

              // ── Products Grid ────────────────────────────────────────────
              Expanded(
                child: pagedProducts.isEmpty
                    ? const _EmptyState(
                        icon: Icons.search_off_rounded,
                        message:
                            'No se encontraron productos en el catálogo.',
                      )
                    : Column(
                        children: [
                          Expanded(
                            child: GridView.builder(
                              padding: const EdgeInsets.only(bottom: 12),
                              gridDelegate:
                                  SliverGridDelegateWithFixedCrossAxisCount(
                                crossAxisCount: crossAxisCount,
                                crossAxisSpacing: isMobile ? 10 : 16,
                                mainAxisSpacing: isMobile ? 12 : 18,
                                childAspectRatio: isMobile ? 0.56 : 0.60,
                              ),
                              itemCount: pagedProducts.length,
                              itemBuilder: (context, index) {
                                final product = pagedProducts[index];
                                return _CatalogProductCard(
                                  product: product,
                                  onOutgoing: () async {
                                    final err = await widget.store
                                        .quickSale(product);
                                    if (!context.mounted) return;
                                    if (err != null) {
                                      ScaffoldMessenger.of(context)
                                          .showSnackBar(
                                        SnackBar(
                                          content: Text(err),
                                          backgroundColor: _C.red,
                                        ),
                                      );
                                    } else {
                                      ScaffoldMessenger.of(context)
                                          .showSnackBar(
                                        SnackBar(
                                          content: Text(
                                            '¡Salida registrada! 1x "${product.name}" agregada a ganancias.',
                                          ),
                                          backgroundColor: _C.green,
                                          duration:
                                              const Duration(seconds: 2),
                                        ),
                                      );
                                    }
                                  },
                                  onIncoming: () async {
                                    final err =
                                        await widget.store.moveStock(
                                      product: product,
                                      quantity: 1,
                                      type: MovementType.incoming,
                                      note:
                                          'Entrada rápida desde catálogo',
                                    );
                                    if (!context.mounted) return;
                                    if (err != null) {
                                      ScaffoldMessenger.of(context)
                                          .showSnackBar(
                                        SnackBar(
                                          content: Text(err),
                                          backgroundColor: _C.red,
                                        ),
                                      );
                                    } else {
                                      ScaffoldMessenger.of(context)
                                          .showSnackBar(
                                        SnackBar(
                                          content: Text(
                                            '¡Entrada registrada! 1x "${product.name}" agregada a inventario.',
                                          ),
                                          backgroundColor: _C.green,
                                          duration:
                                              const Duration(seconds: 2),
                                        ),
                                      );
                                    }
                                  },
                                  onStockDialog: () => showStockDialog(
                                      context, widget.store, product),
                                  onEdit: () =>
                                      _openProductForm(context, product),
                                  onDelete: () =>
                                      _confirmDelete(context, product),
                                  onViewMedia: () =>
                                      _showMediaViewer(context, product),
                                );
                              },
                            ),
                          ),

                          // ── Paginación ──────────────────────────────────
                          if (totalPages > 1) ...[
                            const SizedBox(height: 10),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 16, vertical: 10),
                              decoration: BoxDecoration(
                                color: _C.bgCard,
                                borderRadius: BorderRadius.circular(14),
                                border: Border.all(
                                    color: _C.strokeLight, width: 1),
                              ),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  _PaginationButton(
                                    icon: Icons.chevron_left_rounded,
                                    label: 'Anterior',
                                    enabled: activePage > 1,
                                    onPressed: () => setState(
                                        () => currentPage = activePage - 1),
                                  ),
                                  const SizedBox(width: 16),
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 14, vertical: 6),
                                    decoration: BoxDecoration(
                                      color: _C.magenta.withValues(alpha: 0.08),
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: Text(
                                      '$activePage / $totalPages',
                                      style: const TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.w800,
                                        color: _C.magenta,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 6),
                                  Text(
                                    '($totalCount productos)',
                                    style: TextStyle(
                                      fontSize: 11,
                                      color: _C.textSecondary
                                          .withValues(alpha: 0.7),
                                    ),
                                  ),
                                  const SizedBox(width: 16),
                                  _PaginationButton(
                                    icon: Icons.chevron_right_rounded,
                                    label: 'Siguiente',
                                    enabled: activePage < totalPages,
                                    onPressed: () => setState(
                                        () => currentPage = activePage + 1),
                                    iconAfter: true,
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ],
                      ),
              ),
            ],
              ),
            ),
          ),
        );
      },
    );
  }

  Future<void> _openProductForm(BuildContext context,
      [Product? product]) async {
    await showDialog<void>(
      context: context,
      builder: (_) => ProductForm(store: widget.store, product: product),
    );
  }

  Future<void> _showMediaViewer(
      BuildContext context, Product product) async {
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
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
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
                                color:
                                    Colors.white.withValues(alpha: 0.15),
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(Icons.play_arrow_rounded,
                                  size: 64, color: Colors.white),
                            ),
                            const SizedBox(height: 16),
                            Text(
                              'Video de ${product.name}',
                              style: const TextStyle(
                                  color: Colors.white, fontSize: 16),
                            ),
                          ],
                        ),
                      )
                    : memoryBytes != null
                        ? InteractiveViewer(
                            minScale: 0.8,
                            maxScale: 4.0,
                            child: Image.memory(memoryBytes,
                                fit: BoxFit.contain),
                          )
                        : product.imageUrl.isNotEmpty
                            ? InteractiveViewer(
                                minScale: 0.8,
                                maxScale: 4.0,
                                child: Image.network(
                                  product.imageUrl,
                                  fit: BoxFit.contain,
                                  errorBuilder: (_, __, ___) =>
                                      const Center(
                                    child: Icon(
                                        Icons.broken_image_rounded,
                                        size: 64,
                                        color: Colors.white38),
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

  Future<void> _confirmDelete(
      BuildContext context, Product product) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: _C.red.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(Icons.delete_forever_rounded,
                  color: _C.red, size: 20),
            ),
            const SizedBox(width: 12),
            const Text('ELIMINAR PRODUCTO'),
          ],
        ),
        content: Text(
          '¿Deseas eliminar "${product.name}"?\nEsta acción no se puede deshacer.',
          style: const TextStyle(
              color: _C.textSecondary, height: 1.5),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('CANCELAR'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            style: FilledButton.styleFrom(
              backgroundColor: _C.red,
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
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        child: Container(
          width: 500,
          padding: const EdgeInsets.all(28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          _C.magenta.withValues(alpha: 0.15),
                          _C.magenta.withValues(alpha: 0.05),
                        ],
                      ),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: const Icon(Icons.install_mobile_rounded,
                        color: _C.magenta, size: 24),
                  ),
                  const SizedBox(width: 14),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'INSTALAR APLICACIÓN',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 1.2,
                            color: _C.textPrimary,
                          ),
                        ),
                        Text(
                          'Instala My Love Depot en tu dispositivo',
                          style: TextStyle(
                              fontSize: 11, color: _C.textSecondary),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.pop(dialogContext),
                    icon: const Icon(Icons.close_rounded),
                  ),
                ],
              ),

              const SizedBox(height: 20),

              // Divider
              Container(
                height: 1,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      Colors.transparent,
                      _C.stroke,
                      Colors.transparent,
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 20),

              // iOS Guide
              _InstallSection(
                icon: Icons.apple,
                title: 'EN IPHONE / IPAD (iOS Safari):',
                color: _C.magenta,
                bgColor: const Color(0xfffff6fa),
                steps: const [
                  'Abre Safari y toca el botón Compartir (cuadro con flecha ⎋ arriba o abajo).',
                  'Desplázate hacia abajo y selecciona "Agregar a inicio" (Add to Home Screen 📲).',
                  'Toca "Agregar". ¡La app aparecerá en tu iPhone como una app nativa!',
                ],
              ),

              const SizedBox(height: 16),

              // Android Guide
              _InstallSection(
                icon: Icons.android_rounded,
                title: 'EN ANDROID / CHROME / EDGE:',
                color: _C.green,
                bgColor: const Color(0xfff0fdf4),
                steps: const [
                  'Toca los tres puntos (⋮) en la esquina de tu navegador Chrome o Edge.',
                  'Selecciona "Instalar aplicación" o "Agregar a la pantalla principal".',
                ],
              ),

              const SizedBox(height: 24),

              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  if (PwaHelpers.isPwaInstallAvailable()) ...[
                    Container(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(14),
                        gradient: const LinearGradient(
                          colors: [_C.magenta, _C.magentaDeep],
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: _C.magenta.withValues(alpha: 0.3),
                            blurRadius: 10,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: FilledButton.icon(
                        onPressed: () async {
                          Navigator.pop(dialogContext);
                          await PwaHelpers.triggerPwaInstall();
                        },
                        icon: const Icon(Icons.download_rounded,
                            size: 18),
                        style: FilledButton.styleFrom(
                          backgroundColor: Colors.transparent,
                          foregroundColor: Colors.white,
                          shadowColor: Colors.transparent,
                        ),
                        label: const Text('INSTALAR AHORA',
                            style: TextStyle(
                                fontWeight: FontWeight.w800,
                                letterSpacing: 1.1)),
                      ),
                    ),
                    const SizedBox(width: 12),
                  ],
                  OutlinedButton.icon(
                    onPressed: () => Navigator.pop(dialogContext),
                    icon: const Icon(
                        Icons.check_circle_outline_rounded,
                        size: 18),
                    label: const Text('¡ENTENDIDO!',
                        style: TextStyle(
                            fontWeight: FontWeight.w800,
                            letterSpacing: 1.1)),
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

// ── Install Section ────────────────────────────────────────────────────────────
class _InstallSection extends StatelessWidget {
  const _InstallSection({
    required this.icon,
    required this.title,
    required this.color,
    required this.bgColor,
    required this.steps,
  });
  final IconData icon;
  final String title;
  final Color color;
  final Color bgColor;
  final List<String> steps;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, color: color, size: 20),
            const SizedBox(width: 8),
            Text(
              title,
              style: TextStyle(
                fontWeight: FontWeight.w800,
                fontSize: 12,
                color: color,
                letterSpacing: 0.5,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: bgColor,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: color.withValues(alpha: 0.2)),
          ),
          child: Column(
            children: [
              for (int i = 0; i < steps.length; i++) ...[
                if (i > 0) const SizedBox(height: 8),
                _InstallStep(
                  number: '${i + 1}',
                  text: steps[i],
                  color: color,
                ),
              ],
            ],
          ),
        ),
      ],
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
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: _C.bgCard,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: _C.strokeLight, width: 1),
        boxShadow: [
          BoxShadow(
            color: _C.magenta.withValues(alpha: 0.04),
            blurRadius: 4,
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: _C.magenta),
          const SizedBox(width: 6),
          Text(
            label.toUpperCase(),
            style: const TextStyle(
              color: _C.textSecondary,
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
      {required this.icon,
      required this.label,
      required this.onPressed});
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
        foregroundColor: _C.textPrimary,
        side: const BorderSide(color: _C.strokeLight, width: 1),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
        ),
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
          width: 4,
          height: 40,
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [_C.magenta, _C.magentaDeep],
            ),
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        const SizedBox(width: 14),
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: _C.magenta.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, color: _C.magenta, size: 20),
        ),
        const SizedBox(width: 12),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: const TextStyle(
                color: _C.textPrimary,
                fontSize: 15,
                fontWeight: FontWeight.w800,
                letterSpacing: 2,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              subtitle,
              style: TextStyle(
                color: _C.textSecondary.withValues(alpha: 0.8),
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
        color: _C.bgDeep,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _C.strokeLight, width: 1),
      ),
      child: TextField(
        onChanged: onChanged,
        style: const TextStyle(color: _C.textPrimary, fontSize: 13),
        decoration: InputDecoration(
          hintText: 'Buscar por nombre, SKU o categoría…',
          hintStyle: TextStyle(
            color: _C.textSecondary.withValues(alpha: 0.5),
            fontSize: 13,
          ),
          prefixIcon:
              const Icon(Icons.search_rounded, color: _C.magenta, size: 20),
          border: InputBorder.none,
          enabledBorder: InputBorder.none,
          focusedBorder: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(vertical: 12),
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
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeOut,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: selected
              ? _C.magenta.withValues(alpha: 0.12)
              : _C.bgDeep,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: selected ? _C.magenta : _C.strokeLight,
            width: selected ? 1.5 : 1,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              selected
                  ? Icons.check_circle_rounded
                  : Icons.circle_outlined,
              size: 14,
              color: selected ? _C.magenta : _C.textSecondary,
            ),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                color: selected ? _C.magenta : _C.textSecondary,
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

// ── Pagination button ─────────────────────────────────────────────────────────
class _PaginationButton extends StatelessWidget {
  const _PaginationButton({
    required this.icon,
    required this.label,
    required this.enabled,
    required this.onPressed,
    this.iconAfter = false,
  });
  final IconData icon;
  final String label;
  final bool enabled;
  final VoidCallback onPressed;
  final bool iconAfter;

  @override
  Widget build(BuildContext context) {
    final iconW = Icon(icon, size: 18, color: enabled ? _C.magenta : _C.stroke);
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(8),
        onTap: enabled ? onPressed : null,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (!iconAfter) iconW,
              if (!iconAfter) const SizedBox(width: 4),
              Text(
                label,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: enabled ? _C.textPrimary : _C.stroke,
                ),
              ),
              if (iconAfter) const SizedBox(width: 4),
              if (iconAfter) iconW,
            ],
          ),
        ),
      ),
    );
  }
}

// ── Product Card (Premium Catalog Style) ───────────────────────────────────────
class _CatalogProductCard extends StatefulWidget {
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
  State<_CatalogProductCard> createState() => _CatalogProductCardState();
}

class _CatalogProductCardState extends State<_CatalogProductCard> {
  bool _hovering = false;

  @override
  Widget build(BuildContext context) {
    final product = widget.product;
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

    return MouseRegion(
      onEnter: (_) => setState(() => _hovering = true),
      onExit: (_) => setState(() => _hovering = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeOut,
        transform: _hovering ? (Matrix4.identity()..setEntry(0, 0, 1.02)..setEntry(1, 1, 1.02)) : Matrix4.identity(),
        transformAlignment: Alignment.center,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(24),
          boxShadow: [
            BoxShadow(
              color: _hovering
                  ? _C.magenta.withValues(alpha: 0.15)
                  : const Color(0xffe2d9e0).withValues(alpha: 0.5),
              blurRadius: _hovering ? 24 : 16,
              offset: Offset(0, _hovering ? 12 : 6),
            ),
          ],
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // ── Image area ─────────────────────────────────────────────────
            Expanded(
              flex: 12,
              child: GestureDetector(
                onTap: widget.onViewMedia,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    Container(
                      decoration: const BoxDecoration(
                        color: Color(0xfffaf8f9),
                      ),
                      child: memoryBytes != null
                          ? Image.memory(memoryBytes, fit: BoxFit.cover)
                          : product.imageUrl.isNotEmpty
                              ? Image.network(
                                  product.imageUrl,
                                  fit: BoxFit.cover,
                                  errorBuilder: (_, __, ___) =>
                                      const Center(
                                    child: Icon(Icons.broken_image_rounded,
                                        color: Colors.white38, size: 36),
                                  ),
                                )
                              : Center(
                                  child: Icon(
                                    product.isVideo
                                        ? Icons.videocam_rounded
                                        : Icons.inventory_2_outlined,
                                    color: Colors.white24,
                                    size: 44,
                                  ),
                                ),
                    ),

                    // Scrim si agotado
                    if (isAgotado)
                      Container(
                        color: Colors.black.withValues(alpha: 0.45),
                      ),

                    // Chip de Categoría
                    Positioned(
                      top: 8,
                      left: 8,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: categoryBg.withValues(alpha: 0.95),
                          borderRadius: BorderRadius.circular(8),
                          boxShadow: [
                            BoxShadow(
                              color:
                                  Colors.black.withValues(alpha: 0.1),
                              blurRadius: 4,
                            ),
                          ],
                        ),
                        child: Text(
                          product.category.toUpperCase(),
                          style: TextStyle(
                            color: categoryText,
                            fontSize: 8.5,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 0.5,
                          ),
                        ),
                      ),
                    ),

                    // Action buttons on hover or always on mobile
                    Positioned(
                      top: 6,
                      right: 6,
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (product.isVideo) ...[
                            _ImageActionBtn(
                              icon: Icons.play_arrow_rounded,
                              onTap: widget.onViewMedia,
                            ),
                            const SizedBox(width: 4),
                          ],
                          _ImageActionBtn(
                            icon: Icons.edit_rounded,
                            onTap: widget.onEdit,
                          ),
                          const SizedBox(width: 4),
                          _ImageActionBtn(
                            icon: Icons.delete_outline_rounded,
                            onTap: widget.onDelete,
                          ),
                        ],
                      ),
                    ),

                    // AGOTADO badge
                    if (isAgotado)
                      Center(
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 16, vertical: 6),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(6),
                            boxShadow: [
                              BoxShadow(
                                color:
                                    Colors.black.withValues(alpha: 0.2),
                                blurRadius: 8,
                              ),
                            ],
                          ),
                          child: const Text(
                            'AGOTADO',
                            style: TextStyle(
                              color: Color(0xff991b1b),
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

            // ── Info area ──────────────────────────────────────────────────
            Expanded(
              flex: 12,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(10, 8, 10, 8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          product.name,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w800,
                            color: Color(0xff18181b),
                            height: 1.2,
                          ),
                        ),
                        const SizedBox(height: 5),

                        // Stock badge
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 7, vertical: 3),
                              decoration: BoxDecoration(
                                color: isAgotado
                                    ? const Color(0xfffee2e2)
                                    : product.hasLowStock
                                        ? const Color(0xfffef3c7)
                                        : const Color(0xffdcfce7),
                                borderRadius:
                                    BorderRadius.circular(6),
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
                                  product.sku,
                                  maxLines: 1,
                                  overflow:
                                      TextOverflow.ellipsis,
                                  style: TextStyle(
                                    color: _C.textSecondary
                                        .withValues(alpha: 0.5),
                                    fontSize: 9,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                            ],
                          ],
                        ),
                      ],
                    ),

                    // Price + adjust
                    Row(
                      mainAxisAlignment:
                          MainAxisAlignment.spaceBetween,
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
                        InkWell(
                          onTap: widget.onStockDialog,
                          borderRadius: BorderRadius.circular(16),
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: _C.magenta
                                  .withValues(alpha: 0.08),
                              borderRadius:
                                  BorderRadius.circular(16),
                            ),
                            child: Row(
                              children: [
                                Icon(Icons.swap_vert_rounded,
                                    size: 13, color: _C.magenta),
                                const SizedBox(width: 2),
                                const Text(
                                  'Ajustar',
                                  style: TextStyle(
                                    fontSize: 10,
                                    color: _C.magenta,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),

                    // Action buttons
                    Row(
                      children: [
                        Expanded(
                          child: SizedBox(
                            height: 32,
                            child: OutlinedButton.icon(
                              onPressed: widget.onIncoming,
                              icon: const Icon(
                                  Icons.add_rounded,
                                  size: 14),
                              label: const Text('ENTRADA'),
                              style: OutlinedButton.styleFrom(
                                foregroundColor: _C.green,
                                side: const BorderSide(
                                    color: _C.green,
                                    width: 1.2),
                                padding: EdgeInsets.zero,
                                shape: RoundedRectangleBorder(
                                  borderRadius:
                                      BorderRadius.circular(24),
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
                        Expanded(
                          child: SizedBox(
                            height: 32,
                            child: Container(
                              decoration: BoxDecoration(
                                borderRadius:
                                    BorderRadius.circular(24),
                                gradient: isAgotado
                                    ? null
                                    : const LinearGradient(
                                        colors: [
                                          _C.magenta,
                                          _C.magentaDeep,
                                        ],
                                      ),
                                color: isAgotado
                                    ? const Color(0xffe2e8f0)
                                    : null,
                              ),
                              child: ElevatedButton.icon(
                                onPressed: isAgotado
                                    ? null
                                    : widget.onOutgoing,
                                icon: const Icon(
                                    Icons.remove_rounded,
                                    size: 14),
                                label: const Text('SALIDA'),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor:
                                      Colors.transparent,
                                  foregroundColor:
                                      Colors.white,
                                  disabledBackgroundColor:
                                      const Color(0xffe2e8f0),
                                  disabledForegroundColor:
                                      const Color(0xff94a3b8),
                                  padding: EdgeInsets.zero,
                                  elevation: 0,
                                  shadowColor:
                                      Colors.transparent,
                                  shape:
                                      RoundedRectangleBorder(
                                    borderRadius:
                                        BorderRadius.circular(
                                            24),
                                  ),
                                  textStyle: const TextStyle(
                                    fontSize: 9.5,
                                    fontWeight:
                                        FontWeight.w800,
                                    letterSpacing: 0.5,
                                  ),
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
      ),
    );
  }
}

// ── Image action button ────────────────────────────────────────────────────────
class _ImageActionBtn extends StatelessWidget {
  const _ImageActionBtn({required this.icon, required this.onTap});
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white.withValues(alpha: 0.95),
      shape: const CircleBorder(),
      elevation: 4,
      shadowColor: Colors.black.withValues(alpha: 0.15),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(7),
          child: Icon(icon, color: const Color(0xff4a3d46), size: 16),
        ),
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
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: _C.magenta.withValues(alpha: 0.06),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: _C.textSecondary, size: 48),
          ),
          const SizedBox(height: 16),
          Text(
            message,
            textAlign: TextAlign.center,
            style: const TextStyle(
                color: _C.textSecondary, fontSize: 14),
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
            color: _C.textSecondary,
            fontSize: 11,
            fontWeight: FontWeight.w800,
            letterSpacing: 1.2,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Container(
            height: 1,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [_C.stroke, _C.stroke.withValues(alpha: 0.2)],
              ),
            ),
          ),
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
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
      decoration: BoxDecoration(
        color: _C.bgDeep,
        borderRadius: BorderRadius.circular(30),
        border: Border.all(color: _C.strokeLight, width: 0.5),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          borderRadius: BorderRadius.circular(24),
          value: effectiveValue,
          icon: const Icon(Icons.keyboard_arrow_down_rounded,
              size: 18, color: _C.magenta),
          isDense: true,
          style: const TextStyle(
            color: _C.textPrimary,
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
          _MetricCard(
            icon: Icons.layers_rounded,
            label: 'UNIDADES (STOCK)',
            value: '${store.totalUnits}',
            subtitle: 'Total en existencia',
            accent: const Color(0xff2563eb),
            gradColors: const [Color(0xff2563eb), Color(0xff1d4ed8)],
          ),
          _MetricCard(
            icon: Icons.attach_money_rounded,
            label: 'VALOR ALMACÉN',
            value: '\$${store.inventoryValue.toStringAsFixed(2)}',
            subtitle: 'Estimado actual',
            accent: const Color(0xff0d9488),
            gradColors: const [Color(0xff0d9488), Color(0xff0f766e)],
          ),
          _MetricCard(
            icon: Icons.point_of_sale_rounded,
            label: 'GANANCIAS HOY',
            value: '\$${store.todayEarnings.toStringAsFixed(2)}',
            subtitle: '${store.todaySalesUnits} salidas hoy',
            accent: const Color(0xff059669),
            gradColors: const [Color(0xff059669), Color(0xff047857)],
          ),
          _MetricCard(
            icon: Icons.savings_rounded,
            label: 'GANANCIAS MES',
            value: '\$${store.monthEarnings.toStringAsFixed(2)}',
            subtitle: '${store.monthSalesUnits} salidas este mes',
            accent: const Color(0xff7c3aed),
            gradColors: const [Color(0xff7c3aed), Color(0xff6d28d9)],
          ),
        ];

        return Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 1200),
            child: SingleChildScrollView(
              padding: EdgeInsets.all(isMobile ? 14 : 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // ── Header ──────────────────────────────────────────────────
                  _PageHeader(
                    icon: Icons.dashboard_rounded,
                    title: 'RESUMEN DEL ALMACÉN',
                    subtitle:
                        'Estado en tiempo real  ·  ${now.day}/${now.month}/${now.year}',
                  ),
                  const SizedBox(height: 20),

                  // ── Metric Grid ─────────────────────────────────────────────
                  GridView.count(
                    crossAxisCount: isMobile ? 2 : 4,
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    crossAxisSpacing: isMobile ? 10 : 14,
                    mainAxisSpacing: isMobile ? 10 : 14,
                    childAspectRatio: isMobile ? 2.2 : 2.6,
                    children: cards,
                  ),

                  const SizedBox(height: 28),

                  const _SectionDivider(label: 'ATENCIÓN REQUERIDA'),
                  const SizedBox(height: 16),

                  // ── Low stock list ──────────────────────────────────────────
                  if (store.lowStockCount == 0)
                    Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: _C.bgCard,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                            color: _C.green.withValues(alpha: 0.2),
                            width: 1),
                        boxShadow: [
                          BoxShadow(
                            color: _C.green.withValues(alpha: 0.05),
                            blurRadius: 8,
                          ),
                        ],
                      ),
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: _C.green.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: const Icon(
                                Icons.check_circle_rounded,
                                color: _C.green,
                                size: 24),
                          ),
                          const SizedBox(width: 14),
                          const Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  '¡Todo en orden!',
                                  style: TextStyle(
                                    color: _C.textPrimary,
                                    fontWeight: FontWeight.w800,
                                    fontSize: 14,
                                  ),
                                ),
                                SizedBox(height: 2),
                                Text(
                                  'Todos los productos cuentan con existencias suficientes.',
                                  style: TextStyle(
                                      color: _C.textSecondary,
                                      fontSize: 12),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    )
                  else
                    ...store.products
                        .where((item) => item.hasLowStock)
                        .map(
                          (product) => Padding(
                            padding: const EdgeInsets.only(bottom: 8),
                            child: _LowStockTile(
                                product: product,
                                onTap: onShowProducts),
                          ),
                        ),
                ],
              ),
            ),
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
        padding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: _C.bgCard,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
              color: _C.amber.withValues(alpha: 0.25), width: 1),
          boxShadow: [
            BoxShadow(
              color: _C.amber.withValues(alpha: 0.05),
              blurRadius: 6,
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: _C.amber.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(Icons.warning_amber_rounded,
                  color: _C.amber, size: 18),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    product.name,
                    style: const TextStyle(
                      color: _C.textPrimary,
                      fontWeight: FontWeight.w700,
                      fontSize: 13,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '${product.stock} disponibles  ·  mínimo ${product.minimumStock}',
                    style: const TextStyle(
                        color: _C.textSecondary, fontSize: 12),
                  ),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: _C.magenta.withValues(alpha: 0.06),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(Icons.chevron_right_rounded,
                  color: _C.magenta, size: 18),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Metric card (Premium with gradient icon) ────────────────────────────────────
class _MetricCard extends StatelessWidget {
  const _MetricCard({
    required this.icon,
    required this.label,
    required this.value,
    required this.accent,
    this.subtitle,
    this.gradColors,
  });

  final IconData icon;
  final String label;
  final String value;
  final Color accent;
  final String? subtitle;
  final List<Color>? gradColors;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: _C.bgCard,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: accent.withValues(alpha: 0.12),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: accent.withValues(alpha: 0.06),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              gradient: gradColors != null
                  ? LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: gradColors!.map((c) => c.withValues(alpha: 0.12)).toList(),
                    )
                  : null,
              color: gradColors == null
                  ? accent.withValues(alpha: 0.1)
                  : null,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: accent, size: 20),
          ),
          const SizedBox(width: 12),
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
                      fontSize: 17,
                      fontWeight: FontWeight.w900,
                      letterSpacing: -0.3,
                    ),
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: _C.textSecondary,
                    fontSize: 8.5,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.8,
                  ),
                ),
                if (subtitle != null)
                  Text(
                    subtitle!,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color:
                          _C.textSecondary.withValues(alpha: 0.65),
                      fontSize: 8,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ── Movements page ─────────────────────────────────────────────────────────────
class _MovementsPage extends StatefulWidget {
  const _MovementsPage({required this.store});
  final InventoryStore store;

  @override
  State<_MovementsPage> createState() => _MovementsPageState();
}

class _MovementsPageState extends State<_MovementsPage> {
  MovementType? _typeFilter;
  int? _monthFilter;
  int? _yearFilter;
  String? _categoryFilter;
  bool _showFilters = false;

  InputDecoration _dropdownDecoration(String label) {
    return InputDecoration(
      labelText: label,
      labelStyle: const TextStyle(color: Color(0xff7a5c6b), fontSize: 13),
      filled: true,
      fillColor: const Color(0xfffffbfd),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(30),
        borderSide: const BorderSide(color: Color(0xfff3e4ed), width: 0.5),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(30),
        borderSide: const BorderSide(color: Color(0xfff3e4ed), width: 0.5),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(30),
        borderSide: const BorderSide(color: _C.magenta, width: 1.0),
      ),
    );
  }

  Future<void> _showExpenseDialog(BuildContext context) async {
    final amountCtrl = TextEditingController();
    final noteCtrl = TextEditingController();
    String? error;
    await showDialog<void>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setState) => AlertDialog(
          title: const Text('Registrar Gasto Personal', style: TextStyle(color: _C.magenta, fontWeight: FontWeight.bold)),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (error != null)
                Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Text(error!, style: const TextStyle(color: Colors.red, fontSize: 13)),
                ),
              TextFormField(
                controller: amountCtrl,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                decoration: InputDecoration(
                  labelText: 'Monto (\$)',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(30), borderSide: const BorderSide(width: 0.5)),
                  enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(30), borderSide: const BorderSide(color: Color(0xfff3e4ed), width: 0.5)),
                  focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(30), borderSide: const BorderSide(color: _C.magenta, width: 1.0)),
                ),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: noteCtrl,
                decoration: InputDecoration(
                  labelText: 'Descripción',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(30), borderSide: const BorderSide(width: 0.5)),
                  enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(30), borderSide: const BorderSide(color: Color(0xfff3e4ed), width: 0.5)),
                  focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(30), borderSide: const BorderSide(color: _C.magenta, width: 1.0)),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancelar', style: TextStyle(color: _C.textSecondary)),
            ),
            ElevatedButton(
              onPressed: () async {
                final amount = double.tryParse(amountCtrl.text) ?? 0.0;
                if (amount <= 0) {
                  setState(() => error = 'El monto debe ser mayor a cero.');
                  return;
                }
                final note = noteCtrl.text.trim();
                if (note.isEmpty) {
                  setState(() => error = 'Escribe una descripción.');
                  return;
                }
                final fail = await widget.store.addExpense(amount: amount, note: note);
                if (fail != null) {
                  setState(() => error = fail);
                } else {
                  if (ctx.mounted) Navigator.pop(ctx);
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: _C.magenta,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
              ),
              child: const Text('Guardar'),
            ),
          ],
        ),
      ),
    );
  }

  List<StockMovement> get _filtered {
    return widget.store.movements.where((m) {
      if (_typeFilter != null && m.type != _typeFilter) return false;
      if (_monthFilter != null && m.createdAt.month != _monthFilter) return false;
      if (_yearFilter != null && m.createdAt.year != _yearFilter) return false;
      if (_categoryFilter != null) {
        final p = widget.store.products.where((prod) => prod.id == m.productId).firstOrNull;
        if (p?.category != _categoryFilter) return false;
      }
      return true;
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final filtered = _filtered;
    final incomingCount =
        widget.store.movements.where((m) => m.type == MovementType.incoming).length;
    final outgoingCount =
        widget.store.movements.where((m) => m.type == MovementType.outgoing).length;

    final availableYears = widget.store.movements.map((m) => m.createdAt.year).toSet().toList()..sort();
    if (availableYears.isEmpty) availableYears.add(DateTime.now().year);

    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 900),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: _PageHeader(
                      icon: Icons.swap_horiz_rounded,
                      title: 'HISTORIAL DE MOVIMIENTOS',
                      subtitle:
                          '${widget.store.movements.length} movs registrados  ·  $incomingCount entradas  ·  $outgoingCount salidas',
                    ),
                  ),
                  ElevatedButton.icon(
                    onPressed: () => _showExpenseDialog(context),
                    icon: const Icon(Icons.add, size: 18),
                    label: const Text('NUEVO GASTO', style: TextStyle(fontWeight: FontWeight.bold)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _C.magenta,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                    ),
                  ),
                  const SizedBox(width: 8),
                  TextButton.icon(
                    onPressed: () => setState(() => _showFilters = !_showFilters),
                    icon: Icon(_showFilters ? Icons.expand_less : Icons.filter_alt_rounded, color: _C.magenta),
                    label: Text(_showFilters ? 'OCULTAR FILTROS' : 'FILTRAR', style: const TextStyle(color: _C.magenta, fontWeight: FontWeight.bold)),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              if (_showFilters)
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: _C.bgCard,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: _C.strokeLight, width: 1),
                    boxShadow: [
                      BoxShadow(
                        color: _C.magenta.withValues(alpha: 0.03),
                        blurRadius: 8,
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          _FilterChip(
                            label: 'TODAS',
                            selected: _typeFilter == null,
                            onSelected: (_) => setState(() => _typeFilter = null),
                          ),
                          _FilterChip(
                            label: 'ENTRADAS',
                            selected: _typeFilter == MovementType.incoming,
                            onSelected: (_) => setState(
                                () => _typeFilter = MovementType.incoming),
                          ),
                          _FilterChip(
                            label: 'SALIDAS (VENTAS)',
                            selected: _typeFilter == MovementType.outgoing,
                            onSelected: (_) => setState(
                                () => _typeFilter = MovementType.outgoing),
                          ),
                          _FilterChip(
                            label: 'GASTOS PERSONALES',
                            selected: _typeFilter == MovementType.expense,
                            onSelected: (_) => setState(
                                () => _typeFilter = MovementType.expense),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: DropdownButtonFormField<String?>(
                              initialValue: _categoryFilter,
                              borderRadius: BorderRadius.circular(24),
                              decoration: _dropdownDecoration('Categoría'),
                              isExpanded: true,
                              items: [
                                const DropdownMenuItem(value: null, child: Text('Todas las categorías')),
                                ...widget.store.categoryNames.map((c) => DropdownMenuItem(value: c, child: Text(c, overflow: TextOverflow.ellipsis))),
                              ],
                              onChanged: (val) => setState(() => _categoryFilter = val),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: DropdownButtonFormField<int?>(
                              initialValue: _monthFilter,
                              borderRadius: BorderRadius.circular(24),
                              decoration: _dropdownDecoration('Mes'),
                              items: const [
                                DropdownMenuItem(value: null, child: Text('Todos los meses')),
                                DropdownMenuItem(value: 1, child: Text('Enero')),
                                DropdownMenuItem(value: 2, child: Text('Febrero')),
                                DropdownMenuItem(value: 3, child: Text('Marzo')),
                                DropdownMenuItem(value: 4, child: Text('Abril')),
                                DropdownMenuItem(value: 5, child: Text('Mayo')),
                                DropdownMenuItem(value: 6, child: Text('Junio')),
                                DropdownMenuItem(value: 7, child: Text('Julio')),
                                DropdownMenuItem(value: 8, child: Text('Agosto')),
                                DropdownMenuItem(value: 9, child: Text('Septiembre')),
                                DropdownMenuItem(value: 10, child: Text('Octubre')),
                                DropdownMenuItem(value: 11, child: Text('Noviembre')),
                                DropdownMenuItem(value: 12, child: Text('Diciembre')),
                              ],
                              onChanged: (val) => setState(() => _monthFilter = val),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: DropdownButtonFormField<int?>(
                              initialValue: _yearFilter,
                              borderRadius: BorderRadius.circular(24),
                              decoration: _dropdownDecoration('Año'),
                              items: [
                                const DropdownMenuItem(value: null, child: Text('Todos los años')),
                                ...availableYears.map((y) => DropdownMenuItem(value: y, child: Text('$y'))),
                              ],
                              onChanged: (val) => setState(() => _yearFilter = val),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              if (_showFilters) const SizedBox(height: 16),

              Text(
                '${filtered.length} resultado${filtered.length == 1 ? '' : 's'}',
                style: TextStyle(
                  color: _C.textSecondary.withValues(alpha: 0.7),
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 10),

              // ── Movement list ─────────────────────────────────────────────
              Expanded(
                child: filtered.isEmpty
                    ? _EmptyState(
                        icon: Icons.swap_horiz_outlined,
                        message: 'No hay registros que coincidan con los filtros.',
                      )
                    : ListView.separated(
                        itemCount: filtered.length,
                        separatorBuilder: (_, __) =>
                            const SizedBox(height: 8),
                        itemBuilder: (context, index) {
                          final movement = filtered[index];
                          return _MovementTile(movement: movement);
                        },
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _MovementTile extends StatefulWidget {
  const _MovementTile({required this.movement});
  final StockMovement movement;

  @override
  State<_MovementTile> createState() => _MovementTileState();
}

class _MovementTileState extends State<_MovementTile> {
  bool _hovering = false;

  String _date(DateTime date) {
    String two(int value) => value.toString().padLeft(2, '0');
    return '${two(date.day)}/${two(date.month)}/${date.year} '
        '${two(date.hour)}:${two(date.minute)}';
  }

  @override
  Widget build(BuildContext context) {
    final movement = widget.movement;
    final incoming = movement.type == MovementType.incoming;
    final expense = movement.type == MovementType.expense;
    final color = expense ? Colors.orange : (incoming ? _C.green : _C.magenta);

    return MouseRegion(
      onEnter: (_) => setState(() => _hovering = true),
      onExit: (_) => setState(() => _hovering = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: _hovering ? _C.bgCard : _C.bgBase,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: _hovering ? color.withValues(alpha: 0.3) : color.withValues(alpha: 0.15),
            width: 1,
          ),
          boxShadow: _hovering
              ? [
                  BoxShadow(
                    color: color.withValues(alpha: 0.1),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ]
              : [
                  BoxShadow(
                    color: color.withValues(alpha: 0.02),
                    blurRadius: 4,
                  ),
                ],
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                expense ? Icons.money_off : (incoming ? Icons.south_west_rounded : Icons.north_east_rounded),
                color: color,
                size: 18,
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    movement.productName,
                    style: const TextStyle(
                      color: _C.textPrimary,
                      fontWeight: FontWeight.w700,
                      fontSize: 13,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    _date(movement.createdAt) +
                        (movement.note.isEmpty ? '' : '  ·  ${movement.note}'),
                    style: TextStyle(
                      color: _C.textSecondary.withValues(alpha: 0.8),
                      fontSize: 11,
                    ),
                  ),
                ],
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: color.withValues(alpha: 0.2),
                      width: 1,
                    ),
                  ),
                  child: Text(
                    expense ? '-\$${movement.unitPrice.toStringAsFixed(2)}' : '${incoming ? '+' : '-'}${movement.quantity}',
                    style: TextStyle(
                      color: color,
                      fontWeight: FontWeight.w800,
                      fontSize: 16,
                    ),
                  ),
                ),
                if (!incoming && !expense && movement.unitPrice > 0)
                  Padding(
                    padding: const EdgeInsets.only(top: 4, right: 2),
                    child: Text(
                      'Total: \$${(movement.quantity * movement.unitPrice).toStringAsFixed(2)}',
                      style: const TextStyle(
                        color: _C.green,
                        fontWeight: FontWeight.w900,
                        fontSize: 12,
                      ),
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _InstallStep extends StatelessWidget {
  const _InstallStep(
      {required this.number, required this.text, required this.color});
  final String number;
  final String text;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 22,
          height: 22,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: color.withValues(alpha: 0.3),
                blurRadius: 4,
              ),
            ],
          ),
          child: Text(
            number,
            style: const TextStyle(
                color: Colors.white,
                fontSize: 11,
                fontWeight: FontWeight.bold),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            text,
            style: const TextStyle(
                fontSize: 12,
                color: _C.textPrimary,
                height: 1.3),
          ),
        ),
      ],
    );
  }
}

class _FinanzasPage extends StatefulWidget {
  const _FinanzasPage({required this.store});
  final InventoryStore store;

  @override
  State<_FinanzasPage> createState() => _FinanzasPageState();
}

class _FinanzasPageState extends State<_FinanzasPage> {
  final _fundController = TextEditingController();

  @override
  void dispose() {
    _fundController.dispose();
    super.dispose();
  }

  Future<void> _showFundDialog() async {
    _fundController.text = widget.store.walletBaseBalance.toStringAsFixed(2);
    await showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Configurar Fondo Inicial', style: TextStyle(color: _C.magenta, fontWeight: FontWeight.bold)),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        content: TextFormField(
          controller: _fundController,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          decoration: InputDecoration(
            labelText: 'Monto (\$) inicial',
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(30), borderSide: const BorderSide(width: 0.5)),
            enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(30), borderSide: const BorderSide(color: Color(0xfff3e4ed), width: 0.5)),
            focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(30), borderSide: const BorderSide(color: _C.magenta, width: 1.0)),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancelar', style: TextStyle(color: _C.textSecondary)),
          ),
          ElevatedButton(
            onPressed: () {
              final val = double.tryParse(_fundController.text) ?? 0.0;
              widget.store.setWalletBaseBalance(val);
              Navigator.pop(ctx);
              setState(() {});
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: _C.magenta,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
            ),
            child: const Text('Guardar'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final expenses = widget.store.movements.where((m) => m.type == MovementType.expense).toList();
    final totalExpenses = expenses.fold(0.0, (sum, m) => sum + m.unitPrice);
    final currentBalance = widget.store.walletBaseBalance - totalExpenses;

    final stats = <String, double>{};
    for (final e in expenses) {
      final note = e.note.trim().isEmpty ? 'Sin descripción' : e.note.trim();
      stats[note] = (stats[note] ?? 0) + e.unitPrice;
    }
    final sortedStats = stats.entries.toList()..sort((a, b) => b.value.compareTo(a.value));

    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 900),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: _PageHeader(
                      icon: Icons.account_balance_wallet_rounded,
                      title: 'FINANZAS PERSONALES',
                      subtitle: 'Control de tus gastos y saldo disponible',
                    ),
                  ),
                  ElevatedButton.icon(
                    onPressed: _showFundDialog,
                    icon: const Icon(Icons.edit, size: 18),
                    label: const Text('FONDO INICIAL', style: TextStyle(fontWeight: FontWeight.bold)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _C.bgCard,
                      foregroundColor: _C.magenta,
                      elevation: 0,
                      side: const BorderSide(color: _C.magenta, width: 1),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              Row(
                children: [
                  Expanded(
                    child: _SummaryCard(
                      title: 'FONDO INICIAL',
                      value: '\$${widget.store.walletBaseBalance.toStringAsFixed(2)}',
                      icon: Icons.account_balance,
                      color: Colors.blue,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: _SummaryCard(
                      title: 'GASTOS TOTALES',
                      value: '-\$${totalExpenses.toStringAsFixed(2)}',
                      icon: Icons.trending_down_rounded,
                      color: Colors.orange,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: _SummaryCard(
                      title: 'SALDO DISPONIBLE',
                      value: '\$${currentBalance.toStringAsFixed(2)}',
                      icon: Icons.account_balance_wallet,
                      color: currentBalance < 0 ? Colors.red : _C.green,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 32),
              const Text(
                'ESTADÍSTICAS DE GASTOS',
                style: TextStyle(
                  color: _C.textSecondary,
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 1.2,
                ),
              ),
              const SizedBox(height: 16),
              Expanded(
                child: sortedStats.isEmpty
                    ? _EmptyState(
                        icon: Icons.pie_chart_outline,
                        message: 'Aún no has registrado ningún gasto personal.',
                      )
                    : ListView.separated(
                        itemCount: sortedStats.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 8),
                        itemBuilder: (context, index) {
                          final entry = sortedStats[index];
                          final percentage = totalExpenses > 0 ? (entry.value / totalExpenses) * 100 : 0.0;
                          return Container(
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                            decoration: BoxDecoration(
                              color: _C.bgCard,
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(color: _C.strokeLight, width: 1),
                            ),
                            child: Row(
                              children: [
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        entry.key,
                                        style: const TextStyle(fontWeight: FontWeight.bold, color: _C.textPrimary, fontSize: 14),
                                      ),
                                      const SizedBox(height: 6),
                                      LinearProgressIndicator(
                                        value: percentage / 100,
                                        backgroundColor: Colors.orange.withValues(alpha: 0.1),
                                        color: Colors.orange,
                                        borderRadius: BorderRadius.circular(4),
                                        minHeight: 6,
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(width: 24),
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.end,
                                  children: [
                                    Text(
                                      '\$${entry.value.toStringAsFixed(2)}',
                                      style: const TextStyle(fontWeight: FontWeight.w900, color: Colors.orange, fontSize: 15),
                                    ),
                                    Text(
                                      '${percentage.toStringAsFixed(1)}%',
                                      style: TextStyle(color: _C.textSecondary.withValues(alpha: 0.8), fontSize: 11, fontWeight: FontWeight.bold),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          );
                        },
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SummaryCard extends StatelessWidget {
  const _SummaryCard({required this.title, required this.value, required this.icon, required this.color});
  final String title;
  final String value;
  final IconData icon;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: color.withValues(alpha: 0.12),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: color, size: 20),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  title,
                  style: TextStyle(color: color.withValues(alpha: 0.8), fontSize: 10, fontWeight: FontWeight.w800, letterSpacing: 0.5),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              value,
              style: TextStyle(color: color, fontSize: 24, fontWeight: FontWeight.w900, letterSpacing: -0.5),
            ),
          ),
        ],
      ),
    );
  }
}
