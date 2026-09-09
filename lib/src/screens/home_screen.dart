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
    final filtered = widget.store.products.where((product) {
      final matchesQuery = normalized.isEmpty ||
          product.name.toLowerCase().contains(normalized) ||
          product.sku.toLowerCase().contains(normalized) ||
          product.category.toLowerCase().contains(normalized);
      return matchesQuery && (!lowStockOnly || product.hasLowStock);
    }).toList()
      ..sort((a, b) => a.name.compareTo(b.name));

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
                    '${widget.store.products.length} productos disponibles  ·  toca AGREGAR para registrar venta',
              ),
              const SizedBox(height: 16),

              // ── Filters row ──────────────────────────────────────────────────
              Row(
                children: [
                  Expanded(
                    child: _SearchField(
                      onChanged: (value) => setState(() => query = value),
                    ),
                  ),
                  const SizedBox(width: 10),
                  _FilterChip(
                    label: 'STOCK BAJO',
                    selected: lowStockOnly,
                    onSelected: (value) => setState(() => lowStockOnly = value),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // ── Products Grid ────────────────────────────────────────────────
              Expanded(
                child: filtered.isEmpty
                    ? const _EmptyState(
                        icon: Icons.search_off_rounded,
                        message: 'No se encontraron productos en el catálogo.',
                      )
                    : GridView.builder(
                        padding: const EdgeInsets.only(bottom: 24),
                        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: crossAxisCount,
                          crossAxisSpacing: isMobile ? 10 : 16,
                          mainAxisSpacing: isMobile ? 12 : 18,
                          childAspectRatio: isMobile ? 0.58 : 0.62,
                        ),
                        itemCount: filtered.length,
                        itemBuilder: (context, index) {
                          final product = filtered[index];
                          return _CatalogProductCard(
                            product: product,
                            onAdd: () async {
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
                                      '¡Venta registrada! 1x "${product.name}" agregada a ganancias.',
                                    ),
                                    backgroundColor: _Colors.green,
                                    duration: const Duration(seconds: 2),
                                  ),
                                );
                              }
                            },
                            onDetails: () => _showDetails(context, product),
                            onEdit: () => _openProductForm(context, product),
                            onDelete: () => _confirmDelete(context, product),
                          );
                        },
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

  Future<void> _showDetails(BuildContext context, Product product) async {
    await showDialog<void>(
      context: context,
      builder: (context) => Dialog.fullscreen(
        child: Scaffold(
          backgroundColor: _Colors.bgBase,
          appBar: AppBar(
            backgroundColor: _Colors.bgDeep,
            title: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  product.name.toUpperCase(),
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 1.5,
                  ),
                ),
                Text(
                  'DETALLE DEL PRODUCTO',
                  style: TextStyle(
                    color: _Colors.textSecondary,
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 2,
                  ),
                ),
              ],
            ),
            leading: IconButton(
              onPressed: () => Navigator.pop(context),
              icon: const Icon(Icons.close),
            ),
            bottom: PreferredSize(
              preferredSize: const Size.fromHeight(1),
              child: Container(height: 1, color: _Colors.strokeMagenta),
            ),
          ),
          body: _ProductDetails(
            product: product,
            store: widget.store,
            onStock: () => showStockDialog(context, widget.store, product),
            onEdit: () {
              Navigator.pop(context);
              _openProductForm(context, product);
            },
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

// ── Product tile ──────────────────────────────────────────────────────────────
// ── Card de Producto Tipo Catálogo (Referencia compartida) ────────────────────
class _CatalogProductCard extends StatelessWidget {
  const _CatalogProductCard({
    required this.product,
    required this.onAdd,
    required this.onDetails,
    required this.onEdit,
    required this.onDelete,
  });

  final Product product;
  final VoidCallback onAdd;
  final VoidCallback onDetails;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

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
            flex: 11,
            child: Stack(
              fit: StackFit.expand,
              children: [
                // Fondo oscuro estético (estilo estudio/desierto de la foto)
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

                // Badge superior izquierdo: Descuento "-22%"
                Positioned(
                  top: 8,
                  left: 8,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.85),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      '-${product.discountPercent}%',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 9.5,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.2,
                      ),
                    ),
                  ),
                ),

                // Badge superior derecho: "DISPONIBLES: X" o indicador de video
                Positioned(
                  top: 8,
                  right: 8,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (product.isVideo) ...[
                        Container(
                          padding: const EdgeInsets.all(4),
                          decoration: BoxDecoration(
                            color: Colors.black.withValues(alpha: 0.7),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(Icons.play_arrow_rounded,
                              color: Colors.white, size: 12),
                        ),
                        const SizedBox(width: 4),
                      ],
                      if (!isAgotado)
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 6, vertical: 3),
                          decoration: BoxDecoration(
                            color: const Color(0xff007a4d),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            'DISPONIBLES: ${product.stock}',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 9,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 0.3,
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

          // ── Cuerpo de Información ──────────────────────────────────────────
          Expanded(
            flex: 11,
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
                          fontSize: 12.5,
                          fontWeight: FontWeight.w800,
                          color: Color(0xff18181b),
                          height: 1.2,
                        ),
                      ),
                      const SizedBox(height: 4),

                      // Chip de Género / Categoría
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: categoryBg,
                          borderRadius: BorderRadius.circular(4),
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
                      const SizedBox(height: 2),

                      // "Sin reseñas"
                      const Text(
                        'Sin reseñas',
                        style: TextStyle(
                          color: Color(0xff94a3b8),
                          fontSize: 10,
                        ),
                      ),
                    ],
                  ),

                  // Precios
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.baseline,
                        textBaseline: TextBaseline.alphabetic,
                        children: [
                          Text(
                            '\$${product.price.toStringAsFixed(0)}',
                            style: const TextStyle(
                              fontSize: 17,
                              fontWeight: FontWeight.w900,
                              color: Color(0xff18181b),
                              letterSpacing: -0.5,
                            ),
                          ),
                          const SizedBox(width: 5),
                          Text(
                            '\$${product.effectiveOriginalPrice.toStringAsFixed(0)}',
                            style: const TextStyle(
                              fontSize: 11,
                              color: Color(0xff94a3b8),
                              decoration: TextDecoration.lineThrough,
                            ),
                          ),
                        ],
                      ),
                      const Text(
                        'PRECIO FINAL',
                        style: TextStyle(
                          color: Color(0xff64748b),
                          fontSize: 8,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.6,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '🏷️ Mayoreo \$${product.effectiveWholesalePrice.toStringAsFixed(2)}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Color(0xff059669),
                          fontSize: 9.5,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),

                  // ── Botones "AGREGAR" y "DETALLES" ─────────────────────────
                  Row(
                    children: [
                      // Botón AGREGAR (verde si hay stock, gris si agotado)
                      Expanded(
                        child: SizedBox(
                          height: 30,
                          child: ElevatedButton(
                            onPressed: isAgotado ? null : onAdd,
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
                            ),
                            child: const Text(
                              'AGREGAR',
                              style: TextStyle(
                                fontSize: 9.5,
                                fontWeight: FontWeight.w800,
                                letterSpacing: 0.6,
                              ),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 5),

                      // Botón DETALLES (negro)
                      Expanded(
                        child: SizedBox(
                          height: 30,
                          child: ElevatedButton(
                            onPressed: onDetails,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.black,
                              foregroundColor: Colors.white,
                              padding: EdgeInsets.zero,
                              elevation: 0,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(20),
                              ),
                            ),
                            child: const Text(
                              'DETALLES',
                              style: TextStyle(
                                fontSize: 9.5,
                                fontWeight: FontWeight.w800,
                                letterSpacing: 0.6,
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

// ── Product details ────────────────────────────────────────────────────────────
class _ProductDetails extends StatefulWidget {
  const _ProductDetails({
    required this.product,
    required this.store,
    required this.onStock,
    required this.onEdit,
  });
  final Product product;
  final InventoryStore store;
  final VoidCallback onStock;
  final VoidCallback onEdit;

  @override
  State<_ProductDetails> createState() => _ProductDetailsState();
}

class _ProductDetailsState extends State<_ProductDetails> {
  int imageIndex = 0;

  @override
  Widget build(BuildContext context) {
    final product = widget.product;
    final images = product.imageUrls.isNotEmpty
        ? product.imageUrls
        : product.imageUrl.isNotEmpty
            ? [product.imageUrl]
            : <String>[];
    Uint8List? memoryBytes;
    if (product.photoBase64.isNotEmpty) {
      try {
        memoryBytes = base64Decode(product.photoBase64);
      } on FormatException {
        memoryBytes = null;
      }
    }

    return LayoutBuilder(builder: (context, constraints) {
      final wide = constraints.maxWidth > 760;
      final gallery = Container(
        color: const Color(0xff18181b),
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
                        border: Border.all(color: Colors.white24, width: 2),
                      ),
                      child: const Icon(Icons.play_arrow_rounded,
                          size: 64, color: Colors.white),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Video de ${product.name}',
                      style: const TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(height: 4),
                    const Text(
                      'Video MP4 / WebM verificado e íntegro',
                      style: TextStyle(color: Colors.white60, fontSize: 12),
                    ),
                  ],
                ),
              )
            : memoryBytes != null
                ? InteractiveViewer(
                    minScale: 0.8,
                    maxScale: 4.0,
                    child: Center(
                      child: Image.memory(
                        memoryBytes,
                        fit: BoxFit.contain,
                      ),
                    ),
                  )
                : images.isNotEmpty
                    ? Column(
                        children: [
                          Expanded(
                            child: PageView.builder(
                              itemCount: images.length,
                              onPageChanged: (value) =>
                                  setState(() => imageIndex = value),
                              itemBuilder: (_, index) => InteractiveViewer(
                                minScale: 0.8,
                                maxScale: 4.0,
                                child: Center(
                                  child: Image.network(
                                    images[index],
                                    fit: BoxFit.contain,
                                    errorBuilder: (_, __, ___) => const Center(
                                      child: Icon(Icons.broken_image_outlined,
                                          size: 70, color: Colors.white38),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                          if (images.length > 1)
                            Padding(
                              padding: const EdgeInsets.all(12),
                              child: Text(
                                'Vista ${imageIndex + 1} de ${images.length}  ·  Desliza para explorar',
                                style: const TextStyle(
                                    color: Colors.white60, fontSize: 12),
                              ),
                            ),
                        ],
                      )
                    : const Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.inventory_2_outlined,
                                size: 80, color: Colors.white38),
                            SizedBox(height: 12),
                            Text('Sin imágenes registradas',
                                style: TextStyle(color: Colors.white60)),
                          ],
                        ),
                      ),
      );

      final isAgotado = product.stock <= 0;

      final info = SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              product.name,
              style: const TextStyle(
                color: _Colors.textPrimary,
                fontSize: 22,
                fontFamily: 'serif',
                fontWeight: FontWeight.w800,
                letterSpacing: 0.3,
              ),
            ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _DetailChip(label: product.category, icon: Icons.label_outline),
                _DetailChip(
                  label: isAgotado
                      ? 'AGOTADO'
                      : (product.hasLowStock ? 'STOCK BAJO' : 'DISPONIBLE'),
                  icon: isAgotado
                      ? Icons.cancel_outlined
                      : (product.hasLowStock
                          ? Icons.warning_amber_rounded
                          : Icons.check_circle_outline),
                  color: isAgotado
                      ? _Colors.red
                      : (product.hasLowStock ? _Colors.amber : _Colors.green),
                ),
                if (product.isVideo)
                  const _DetailChip(
                    label: 'VIDEO ADJUNTO',
                    icon: Icons.videocam_rounded,
                    color: Color(0xff0284c7),
                  ),
              ],
            ),
            const SizedBox(height: 24),

            _detailRow(Icons.qr_code, 'CÓDIGO',
                product.barcode.isEmpty ? 'Sin código' : product.barcode),
            _detailRow(Icons.sell_outlined, 'SKU', product.sku),
            _detailRow(Icons.inventory_2_outlined, 'EXISTENCIAS',
                '${product.stock} unidades'),
            _detailRow(Icons.low_priority, 'STOCK MÍNIMO',
                '${product.minimumStock} unidades'),
            _detailRow(Icons.payments_outlined, 'PRECIO FINAL',
                '\$${product.price.toStringAsFixed(2)}'),
            _detailRow(Icons.price_change_outlined, 'PRECIO REGULAR',
                '\$${product.effectiveOriginalPrice.toStringAsFixed(2)}'),
            _detailRow(Icons.local_offer_outlined, 'PRECIO MAYOREO',
                '\$${product.effectiveWholesalePrice.toStringAsFixed(2)}'),
            _detailRow(
                Icons.account_balance_wallet_outlined,
                'VALOR EN INVENTARIO',
                '\$${product.inventoryValue.toStringAsFixed(2)}'),

            const SizedBox(height: 24),
            const _SectionDivider(label: 'ACCIONES'),
            const SizedBox(height: 16),

            // Botón Venta Rápida (1 unidad)
            FilledButton.icon(
              onPressed: isAgotado
                  ? null
                  : () async {
                      final err = await widget.store.quickSale(product);
                      if (!context.mounted) return;
                      if (err != null) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text(err), backgroundColor: _Colors.red),
                        );
                      } else {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text('Venta registrada: \$${product.price.toStringAsFixed(2)} sumados a ganancias.'),
                            backgroundColor: _Colors.green,
                          ),
                        );
                      }
                    },
              icon: const Icon(Icons.point_of_sale_rounded, size: 18),
              style: FilledButton.styleFrom(
                backgroundColor: const Color(0xff006847),
                foregroundColor: Colors.white,
              ),
              label: const Text(
                'REGISTRAR VENTA (1 UNIDAD)',
                style: TextStyle(
                    fontWeight: FontWeight.w800, letterSpacing: 1.1, fontSize: 12),
              ),
            ),
            const SizedBox(height: 10),
            OutlinedButton.icon(
              onPressed: widget.onStock,
              icon: const Icon(Icons.swap_horiz, size: 18),
              label: const Text(
                'ENTRADA / SALIDA MANUAL',
                style: TextStyle(
                    fontWeight: FontWeight.w800, letterSpacing: 1.1, fontSize: 12),
              ),
            ),
            const SizedBox(height: 10),
            OutlinedButton.icon(
              onPressed: widget.onEdit,
              icon: const Icon(Icons.edit_outlined, size: 18),
              label: const Text('EDITAR PRODUCTO',
                  style: TextStyle(
                      fontWeight: FontWeight.w700,
                      letterSpacing: 1.1,
                      fontSize: 12)),
            ),
          ],
        ),
      );

      return wide
          ? Row(children: [
              Expanded(flex: 3, child: gallery),
              Container(width: 1, color: _Colors.stroke),
              Expanded(flex: 2, child: info),
            ])
          : Column(children: [
              Expanded(flex: 3, child: gallery),
              Expanded(flex: 4, child: info),
            ]);
    });
  }

  Widget _detailRow(IconData icon, String label, String value) => Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: Row(children: [
          Container(
            padding: const EdgeInsets.all(7),
            decoration: BoxDecoration(
              color: _Colors.bgSurface,
              borderRadius: BorderRadius.circular(4),
              border: Border.all(color: _Colors.stroke, width: 1),
            ),
            child: Icon(icon, color: _Colors.magenta, size: 16),
          ),
          const SizedBox(width: 12),
          Expanded(
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                Text(
                  label,
                  style: const TextStyle(
                    color: _Colors.textSecondary,
                    fontSize: 9,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 1.8,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  style: const TextStyle(
                    color: _Colors.textPrimary,
                    fontSize: 13.5,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ])),
        ]),
      );
}

// ── Detail chip & Section divider ──────────────────────────────────────────────
class _DetailChip extends StatelessWidget {
  const _DetailChip({
    required this.label,
    required this.icon,
    this.color,
  });

  final String label;
  final IconData icon;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final effectiveColor = color ?? _Colors.textSecondary;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: effectiveColor.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: effectiveColor.withValues(alpha: 0.25),
          width: 1,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: effectiveColor),
          const SizedBox(width: 5),
          Text(
            label,
            style: TextStyle(
              color: effectiveColor,
              fontSize: 11,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.4,
            ),
          ),
        ],
      ),
    );
  }
}

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
          // 1. Ganancias Hoy
          _MetricCard(
            icon: Icons.point_of_sale_rounded,
            label: 'GANANCIAS HOY',
            value: '\$${store.todayEarnings.toStringAsFixed(2)}',
            subtitle: '${store.todaySalesUnits} ventas hoy',
            accent: const Color(0xff059669),
            badgeColor: const Color(0xffecfdf5),
          ),
          // 2. Ganancias Mes
          _MetricCard(
            icon: Icons.savings_rounded,
            label: 'GANANCIAS DEL MES',
            value: '\$${store.monthEarnings.toStringAsFixed(2)}',
            subtitle: '${store.monthSalesUnits} ventas este mes',
            accent: const Color(0xff7c3aed),
            badgeColor: const Color(0xfff5f3ff),
          ),
          // 3. Productos en Catálogo
          _MetricCard(
            icon: Icons.inventory_2_rounded,
            label: 'PRODUCTOS',
            value: '${store.products.length}',
            subtitle: 'En catálogo activo',
            accent: _Colors.magenta,
            badgeColor: const Color(0xfffff1f2),
          ),
          // 4. Unidades en Stock
          _MetricCard(
            icon: Icons.layers_rounded,
            label: 'UNIDADES',
            value: '${store.totalUnits}',
            subtitle: 'Total en existencia',
            accent: const Color(0xff2563eb),
            badgeColor: const Color(0xffeff6ff),
          ),
          // 5. Valor Estimado
          _MetricCard(
            icon: Icons.attach_money_rounded,
            label: 'VALOR ALMACÉN',
            value: '\$${store.inventoryValue.toStringAsFixed(2)}',
            subtitle: 'Estimado actual',
            accent: const Color(0xff0d9488),
            badgeColor: const Color(0xfff0fdfa),
          ),
          // 6. Stock Bajo
          _MetricCard(
            icon: Icons.warning_amber_rounded,
            label: 'STOCK BAJO',
            value: '${store.lowStockCount}',
            subtitle: store.lowStockCount > 0 ? 'Requieren resurtido' : 'Inventario óptimo',
            accent: store.lowStockCount > 0 ? _Colors.amber : _Colors.green,
            badgeColor: store.lowStockCount > 0 ? const Color(0xfffffbeb) : const Color(0xfff0fdf4),
            warning: store.lowStockCount > 0,
            onTap: onShowProducts,
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
              const SizedBox(height: 18),

              // ── Metric Grid (2 cols en móvil, 3-6 en escritorio) ──────────
              GridView.count(
                crossAxisCount: isMobile ? 2 : (screenWidth < 1100 ? 3 : 6),
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                crossAxisSpacing: isMobile ? 10 : 14,
                mainAxisSpacing: isMobile ? 10 : 14,
                childAspectRatio: isMobile ? 1.05 : 1.35,
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

// ── Metric card ────────────────────────────────────────────────────────────────
class _MetricCard extends StatelessWidget {
  const _MetricCard({
    required this.icon,
    required this.label,
    required this.value,
    required this.accent,
    this.subtitle,
    this.badgeColor,
    this.warning = false,
    this.onTap,
  });

  final IconData icon;
  final String label;
  final String value;
  final Color accent;
  final String? subtitle;
  final Color? badgeColor;
  final bool warning;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: _Colors.bgCard,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: warning ? accent.withValues(alpha: 0.45) : const Color(0xffede0e7),
            width: warning ? 1.5 : 1,
          ),
          boxShadow: [
            BoxShadow(
              color: accent.withValues(alpha: 0.05),
              blurRadius: 8,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(7),
                  decoration: BoxDecoration(
                    color: badgeColor ?? accent.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(icon, color: accent, size: 18),
                ),
                if (onTap != null) ...[
                  const Spacer(),
                  Icon(Icons.arrow_forward_ios,
                      color: _Colors.textSecondary.withValues(alpha: 0.7), size: 11),
                ],
              ],
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: Text(
                    value,
                    style: TextStyle(
                      color: accent,
                      fontSize: 20,
                      fontWeight: FontWeight.w900,
                      letterSpacing: -0.5,
                    ),
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: _Colors.textSecondary,
                    fontSize: 9.5,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 1.0,
                  ),
                ),
                if (subtitle != null) ...[
                  const SizedBox(height: 2),
                  Text(
                    subtitle!,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: _Colors.textSecondary.withValues(alpha: 0.75),
                      fontSize: 9,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ],
            ),
          ],
        ),
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
