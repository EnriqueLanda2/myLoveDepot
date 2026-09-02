import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:model_viewer_plus/model_viewer_plus.dart';

import '../inventory_store.dart';
import '../models.dart';
import '../widgets/love_mascot.dart';
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
                  Expanded(child: _page()),
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

    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // ── Page header ──────────────────────────────────────────────────
          _PageHeader(
            icon: Icons.inventory_2_outlined,
            title: 'INVENTARIO DE PRODUCTOS',
            subtitle:
                '${widget.store.products.length} productos registrados  ·  busca, consulta o registra nuevo stock',
          ),
          const SizedBox(height: 20),

          // ── Filters row ──────────────────────────────────────────────────
          Row(
            children: [
              Expanded(
                child: _SearchField(
                  onChanged: (value) => setState(() => query = value),
                ),
              ),
              const SizedBox(width: 12),
              _FilterChip(
                label: 'STOCK BAJO',
                selected: lowStockOnly,
                onSelected: (value) => setState(() => lowStockOnly = value),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // ── Products list ────────────────────────────────────────────────
          Expanded(
            child: filtered.isEmpty
                ? _EmptyState(
                    icon: Icons.search_off_rounded,
                    message: 'No se encontraron productos.',
                  )
                : ListView.separated(
                    itemCount: filtered.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 8),
                    itemBuilder: (context, index) {
                      final product = filtered[index];
                      return _ProductTile(
                        product: product,
                        store: widget.store,
                        onStock: () => showStockDialog(
                            context, widget.store, product),
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

              Center(
                child: FilledButton.icon(
                  onPressed: () => Navigator.pop(dialogContext),
                  icon: const Icon(Icons.check_circle_outline_rounded, size: 18),
                  label: const Text('¡ENTENDIDO!', style: TextStyle(fontWeight: FontWeight.w800, letterSpacing: 1.1)),
                ),
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
class _ProductTile extends StatelessWidget {
  const _ProductTile({
    required this.product,
    required this.store,
    required this.onStock,
    required this.onDetails,
    required this.onEdit,
    required this.onDelete,
  });

  final Product product;
  final InventoryStore store;
  final VoidCallback onStock;
  final VoidCallback onDetails;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final lowStock = product.hasLowStock;
    return GestureDetector(
      onTap: onDetails,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: _Colors.bgCard,
          borderRadius: BorderRadius.circular(4),
          border: Border.all(
            color: lowStock ? _Colors.amber.withOpacity(0.25) : _Colors.stroke,
            width: 1,
          ),
        ),
        child: Row(
          children: [
            // Thumb
            _ProductThumb(product: product),
            const SizedBox(width: 16),
            // Info
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    product.name,
                    style: const TextStyle(
                      color: _Colors.textPrimary,
                      fontWeight: FontWeight.w700,
                      fontSize: 14,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Wrap(
                    spacing: 8,
                    children: [
                      _InfoTag(label: product.sku),
                      _InfoTag(label: product.category),
                      _InfoTag(
                        label:
                            '\$${product.price.toStringAsFixed(2)} / ud.',
                        highlight: false,
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            // Stock badge
            _StockBadge(
              stock: product.stock,
              minimum: product.minimumStock,
              isLow: lowStock,
            ),
            const SizedBox(width: 8),
            // Actions
            _TileActions(
              onStock: onStock,
              onDetails: onDetails,
              onEdit: onEdit,
              onDelete: onDelete,
            ),
          ],
        ),
      ),
    );
  }
}

class _InfoTag extends StatelessWidget {
  const _InfoTag({required this.label, this.highlight = true});
  final String label;
  final bool highlight;

  @override
  Widget build(BuildContext context) {
    return Text(
      label,
      style: TextStyle(
        color: highlight ? _Colors.textSecondary : _Colors.textSecondary,
        fontSize: 11,
        letterSpacing: 0.3,
      ),
    );
  }
}

class _StockBadge extends StatelessWidget {
  const _StockBadge(
      {required this.stock,
      required this.minimum,
      required this.isLow});
  final int stock;
  final int minimum;
  final bool isLow;

  @override
  Widget build(BuildContext context) {
    final color = isLow ? _Colors.amber : _Colors.green;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withOpacity(0.08),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: color.withOpacity(0.25), width: 1),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            '$stock',
            style: TextStyle(
              color: color,
              fontWeight: FontWeight.w800,
              fontSize: 16,
            ),
          ),
          Text(
            'UIDS.',
            style: TextStyle(
              color: color.withOpacity(0.7),
              fontSize: 8,
              fontWeight: FontWeight.w700,
              letterSpacing: 1,
            ),
          ),
        ],
      ),
    );
  }
}

class _TileActions extends StatelessWidget {
  const _TileActions({
    required this.onStock,
    required this.onDetails,
    required this.onEdit,
    required this.onDelete,
  });
  final VoidCallback onStock;
  final VoidCallback onDetails;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        _IconActionButton(
          icon: Icons.swap_horiz_rounded,
          tooltip: 'Entrada / Salida',
          onPressed: onStock,
        ),
        _IconActionButton(
          icon: Icons.visibility_outlined,
          tooltip: 'Ver detalle',
          onPressed: onDetails,
        ),
        PopupMenuButton<String>(
          icon: const Icon(Icons.more_vert,
              color: _Colors.textSecondary, size: 20),
          padding: const EdgeInsets.all(4),
          onSelected: (value) {
            if (value == 'edit') {
              onEdit();
            } else {
              onDelete();
            }
          },
          itemBuilder: (_) => const [
            PopupMenuItem(
              value: 'edit',
              child: Row(
                children: [
                  Icon(Icons.edit_outlined, size: 16),
                  SizedBox(width: 8),
                  Text('Editar'),
                ],
              ),
            ),
            PopupMenuItem(
              value: 'delete',
              child: Row(
                children: [
                  Icon(Icons.delete_outline, size: 16, color: _Colors.red),
                  SizedBox(width: 8),
                  Text('Eliminar', style: TextStyle(color: _Colors.red)),
                ],
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _IconActionButton extends StatelessWidget {
  const _IconActionButton(
      {required this.icon,
      required this.tooltip,
      required this.onPressed});
  final IconData icon;
  final String tooltip;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(4),
        child: Container(
          padding: const EdgeInsets.all(6),
          child: Icon(icon, color: _Colors.textSecondary, size: 18),
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
  bool showModel = true;
  bool building = false;

  Future<void> _buildModel() async {
    final messenger = ScaffoldMessenger.of(context);
    setState(() => building = true);
    final failure = await widget.store.buildModel(widget.product);
    if (!mounted) return;
    messenger.showSnackBar(SnackBar(
      content: Text(failure ?? 'Modelo 3D generado a partir de las fotos.'),
    ));
    setState(() {
      building = false;
      showModel = failure == null;
    });
  }

  @override
  Widget build(BuildContext context) {
    final product = widget.product;
    final images = product.imageUrls.isNotEmpty
        ? product.imageUrls
        : product.imageUrl.isNotEmpty
            ? [product.imageUrl]
            : <String>[];
    final hasModel = product.modelUrl.isNotEmpty;

    return LayoutBuilder(builder: (context, constraints) {
      final wide = constraints.maxWidth > 760;
      final gallery = Container(
        color: _Colors.bgDeep,
        child: hasModel && showModel
            ? _ModelStage(
                product: product,
                onShowPhotos: images.isEmpty
                    ? null
                    : () => setState(() => showModel = false),
              )
            : images.isEmpty
                ? Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.inventory_2_outlined,
                            size: 80, color: _Colors.textSecondary),
                        const SizedBox(height: 12),
                        const Text('Sin imágenes',
                            style: TextStyle(color: _Colors.textSecondary)),
                      ],
                    ),
                  )
                : Column(children: [
                    if (hasModel)
                      Align(
                        alignment: Alignment.centerRight,
                        child: Padding(
                          padding: const EdgeInsets.only(top: 12, right: 12),
                          child: TextButton.icon(
                            onPressed: () =>
                                setState(() => showModel = true),
                            icon: const Icon(Icons.view_in_ar_outlined,
                                size: 16),
                            label: const Text('Ver modelo 3D'),
                          ),
                        ),
                      ),
                    Expanded(
                      child: PageView.builder(
                        itemCount: images.length,
                        onPageChanged: (value) =>
                            setState(() => imageIndex = value),
                        itemBuilder: (_, index) => AnimatedScale(
                          scale: imageIndex == index ? 1 : .92,
                          duration: const Duration(milliseconds: 250),
                          child: InteractiveViewer(
                            minScale: .8,
                            maxScale: 4,
                            child: Image.network(
                              images[index],
                              fit: BoxFit.contain,
                              errorBuilder: (_, __, ___) => const Center(
                                  child: Icon(Icons.broken_image_outlined,
                                      size: 70)),
                            ),
                          ),
                        ),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.all(16),
                      child: Text(
                        images.length > 1
                            ? 'Desliza para girar · Vista ${imageIndex + 1} de ${images.length}'
                            : 'Pellizca para ampliar la imagen',
                        style: const TextStyle(
                            color: _Colors.textSecondary, fontSize: 12),
                      ),
                    ),
                  ]),
      );

      final info = SingleChildScrollView(
        padding: const EdgeInsets.all(28),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // ── Product name ──────────────────────────────────────────
            Text(
              product.name,
              style: const TextStyle(
                color: _Colors.textPrimary,
                fontSize: 22,
                fontWeight: FontWeight.w800,
                letterSpacing: 0.5,
              ),
            ),
            const SizedBox(height: 8),
            Wrap(spacing: 8, runSpacing: 8, children: [
              _DetailChip(label: product.category, icon: Icons.label_outline),
              _DetailChip(
                label: product.hasLowStock ? 'STOCK BAJO' : 'DISPONIBLE',
                icon: product.hasLowStock
                    ? Icons.warning_amber_rounded
                    : Icons.check_circle_outline,
                color:
                    product.hasLowStock ? _Colors.amber : _Colors.green,
              ),
            ]),
            const SizedBox(height: 24),

            // ── Detail rows ───────────────────────────────────────────
            _detailRow(Icons.qr_code, 'CÓDIGO',
                product.barcode.isEmpty ? 'Sin código' : product.barcode),
            _detailRow(Icons.sell_outlined, 'SKU', product.sku),
            _detailRow(Icons.inventory_2_outlined, 'EXISTENCIAS',
                '${product.stock} unidades'),
            _detailRow(Icons.low_priority, 'STOCK MÍNIMO',
                '${product.minimumStock} unidades'),
            _detailRow(Icons.payments_outlined, 'PRECIO POR UNIDAD',
                '\$${product.price.toStringAsFixed(2)}'),
            _detailRow(
                Icons.account_balance_wallet_outlined,
                'VALOR EN INVENTARIO',
                '\$${product.inventoryValue.toStringAsFixed(2)}'),

            const SizedBox(height: 28),
            const _SectionDivider(label: 'ACCIONES'),
            const SizedBox(height: 20),

            // ── Action buttons ────────────────────────────────────────
            FilledButton.icon(
              onPressed: widget.onStock,
              icon: const Icon(Icons.swap_horiz, size: 18),
              label: const Text(
                'REGISTRAR MOVIMIENTO',
                style: TextStyle(
                    fontWeight: FontWeight.w800, letterSpacing: 1.2, fontSize: 12),
              ),
            ),
            const SizedBox(height: 10),
            OutlinedButton.icon(
              onPressed: widget.onEdit,
              icon: const Icon(Icons.edit_outlined, size: 18),
              label: const Text('EDITAR PRODUCTO',
                  style: TextStyle(
                      fontWeight: FontWeight.w700,
                      letterSpacing: 1.2,
                      fontSize: 12)),
            ),
            const SizedBox(height: 10),
            _ModelButton(
              hasModel: hasModel,
              hasPhotos: images.isNotEmpty,
              building: building || widget.store.isBuildingModel(product.id),
              onPressed: _buildModel,
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
        padding: const EdgeInsets.only(bottom: 14),
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
          const SizedBox(width: 14),
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
                    letterSpacing: 2,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  style: const TextStyle(
                    color: _Colors.textPrimary,
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ])),
        ]),
      );
}

class _DetailChip extends StatelessWidget {
  const _DetailChip({required this.label, required this.icon, this.color});
  final String label;
  final IconData icon;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final c = color ?? _Colors.textSecondary;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: c.withOpacity(0.08),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: c.withOpacity(0.25), width: 1),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: c, size: 13),
          const SizedBox(width: 5),
          Text(
            label,
            style: TextStyle(
                color: c,
                fontSize: 11,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.8),
          ),
        ],
      ),
    );
  }
}

// ── _SectionDivider (shared) ──────────────────────────────────────────────────
class _SectionDivider extends StatelessWidget {
  const _SectionDivider({required this.label});
  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(child: Container(height: 1, color: _Colors.stroke)),
        const SizedBox(width: 10),
        Text(
          label,
          style: const TextStyle(
            color: _Colors.textSecondary,
            fontSize: 9,
            fontWeight: FontWeight.w700,
            letterSpacing: 2.5,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(child: Container(height: 1, color: _Colors.stroke)),
      ],
    );
  }
}

// ── Model stage ────────────────────────────────────────────────────────────────
class _ModelStage extends StatelessWidget {
  const _ModelStage({required this.product, this.onShowPhotos});
  final Product product;
  final VoidCallback? onShowPhotos;

  @override
  Widget build(BuildContext context) {
    return Column(children: [
      Expanded(
        child: ModelViewer(
          key: ValueKey(product.modelUrl),
          src: product.modelUrl,
          alt: 'Modelo 3D de ${product.name}',
          autoRotate: true,
          autoRotateDelay: 600,
          cameraControls: true,
          cameraOrbit: '25deg 70deg 105%',
          shadowIntensity: 0.85,
          exposure: 1.05,
          backgroundColor: _Colors.bgDeep,
        ),
      ),
      Container(
        padding: const EdgeInsets.all(16),
        decoration: const BoxDecoration(
          border: Border(top: BorderSide(color: _Colors.stroke, width: 1)),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Flexible(
              child: Text(
                'Arrastra para girar  ·  pellizca para acercar',
                textAlign: TextAlign.center,
                style: TextStyle(color: _Colors.textSecondary, fontSize: 11),
              ),
            ),
            if (onShowPhotos != null) ...[
              const SizedBox(width: 12),
              TextButton.icon(
                onPressed: onShowPhotos,
                icon: const Icon(Icons.photo_library_outlined, size: 16),
                label: const Text('Fotos'),
              ),
            ],
          ],
        ),
      ),
    ]);
  }
}

// ── Model button ───────────────────────────────────────────────────────────────
class _ModelButton extends StatelessWidget {
  const _ModelButton({
    required this.hasModel,
    required this.hasPhotos,
    required this.building,
    required this.onPressed,
  });
  final bool hasModel;
  final bool hasPhotos;
  final bool building;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    if (building) {
      return OutlinedButton.icon(
        onPressed: null,
        icon: const SizedBox(
          width: 18,
          height: 18,
          child: CircularProgressIndicator(
              strokeWidth: 2, color: _Colors.magenta),
        ),
        label: const Text('GENERANDO MODELO 3D…',
            style: TextStyle(
                letterSpacing: 1.2,
                fontWeight: FontWeight.w700,
                fontSize: 12)),
      );
    }
    return OutlinedButton.icon(
      onPressed: hasPhotos ? onPressed : null,
      icon: const Icon(Icons.view_in_ar_outlined, size: 18),
      label: Text(
        !hasPhotos
            ? 'AGREGA FOTOS PARA GENERAR MODELO'
            : hasModel
                ? 'REGENERAR MODELO 3D'
                : 'GENERAR MODELO 3D',
        style: const TextStyle(
            letterSpacing: 1.2, fontWeight: FontWeight.w700, fontSize: 12),
      ),
    );
  }
}

// ── Product thumbnail ─────────────────────────────────────────────────────────
class _ProductThumb extends StatelessWidget {
  const _ProductThumb({required this.product});
  final Product product;

  @override
  Widget build(BuildContext context) {
    Uint8List? bytes;
    if (product.photoBase64.isNotEmpty) {
      try {
        bytes = base64Decode(product.photoBase64);
      } on FormatException {
        bytes = null;
      }
    }
    return Stack(
      clipBehavior: Clip.none,
      children: [
        Container(
          width: 52,
          height: 52,
          decoration: BoxDecoration(
            color: _Colors.bgSurface,
            borderRadius: BorderRadius.circular(4),
            border: Border.all(color: _Colors.strokeMagenta, width: 1),
            image: bytes != null
                ? DecorationImage(
                    image: MemoryImage(bytes), fit: BoxFit.cover)
                : product.imageUrl.isNotEmpty
                    ? DecorationImage(
                        image: NetworkImage(product.imageUrl),
                        fit: BoxFit.cover)
                    : null,
          ),
          child: bytes == null && product.imageUrl.isEmpty
              ? const Icon(Icons.inventory_2_outlined,
                  color: _Colors.textSecondary, size: 22)
              : null,
        ),
        if (product.hasLowStock)
          Positioned(
            right: -4,
            top: -4,
            child: Container(
              width: 10,
              height: 10,
              decoration: BoxDecoration(
                color: _Colors.amber,
                shape: BoxShape.circle,
                border: Border.all(color: _Colors.bgCard, width: 1.5),
              ),
            ),
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
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Header ────────────────────────────────────────────────────
          _PageHeader(
            icon: Icons.dashboard_outlined,
            title: 'RESUMEN DEL ALMACÉN',
            subtitle:
                'Estado en tiempo real  ·  ${DateTime.now().day}/${DateTime.now().month}/${DateTime.now().year}',
          ),
          const SizedBox(height: 24),

          // ── Metric cards ──────────────────────────────────────────────
          Wrap(
            spacing: 14,
            runSpacing: 14,
            children: [
              _MetricCard(
                icon: Icons.inventory_2_rounded,
                label: 'PRODUCTOS',
                value: '${store.products.length}',
                accent: _Colors.magenta,
              ),
              _MetricCard(
                icon: Icons.layers_rounded,
                label: 'UNIDADES',
                value: '${store.totalUnits}',
                accent: const Color(0xff60a5fa),
              ),
              _MetricCard(
                icon: Icons.attach_money_rounded,
                label: 'VALOR ESTIMADO',
                value: '\$${store.inventoryValue.toStringAsFixed(2)}',
                accent: const Color(0xff34d399),
              ),
              _MetricCard(
                icon: Icons.warning_amber_rounded,
                label: 'STOCK BAJO',
                value: '${store.lowStockCount}',
                accent: store.lowStockCount > 0
                    ? _Colors.amber
                    : _Colors.green,
                warning: store.lowStockCount > 0,
                onTap: onShowProducts,
              ),
            ],
          ),

          const SizedBox(height: 32),
          const _SectionDivider(label: 'ATENCIÓN REQUERIDA'),
          const SizedBox(height: 20),

          // ── Low stock list ────────────────────────────────────────────
          if (store.lowStockCount == 0)
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: _Colors.bgCard,
                borderRadius: BorderRadius.circular(4),
                border: Border.all(
                    color: _Colors.green.withOpacity(0.25), width: 1),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: _Colors.green.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: const Icon(Icons.check_circle_outline,
                        color: _Colors.green, size: 20),
                  ),
                  const SizedBox(width: 14),
                  const Text(
                    'Todos los productos tienen existencias suficientes.',
                    style: TextStyle(
                        color: _Colors.textSecondary, fontSize: 13),
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
          borderRadius: BorderRadius.circular(4),
          border: Border.all(
              color: _Colors.amber.withOpacity(0.25), width: 1),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(7),
              decoration: BoxDecoration(
                color: _Colors.amber.withOpacity(0.1),
                borderRadius: BorderRadius.circular(4),
              ),
              child: const Icon(Icons.warning_amber_rounded,
                  color: _Colors.amber, size: 16),
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
    this.warning = false,
    this.onTap,
  });
  final IconData icon;
  final String label;
  final String value;
  final Color accent;
  final bool warning;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 220,
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: _Colors.bgCard,
          borderRadius: BorderRadius.circular(4),
          border: Border.all(
            color: warning
                ? accent.withOpacity(0.35)
                : _Colors.stroke,
            width: 1,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(7),
                  decoration: BoxDecoration(
                    color: accent.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Icon(icon, color: accent, size: 18),
                ),
                if (onTap != null) ...[
                  const Spacer(),
                  Icon(Icons.arrow_forward_ios,
                      color: _Colors.textSecondary, size: 12),
                ],
              ],
            ),
            const SizedBox(height: 16),
            Text(
              value,
              style: TextStyle(
                color: accent,
                fontSize: 26,
                fontWeight: FontWeight.w800,
                letterSpacing: -0.5,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: const TextStyle(
                color: _Colors.textSecondary,
                fontSize: 10,
                fontWeight: FontWeight.w700,
                letterSpacing: 2,
              ),
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
                                color: color.withOpacity(0.1),
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
                                color: color.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(4),
                                border: Border.all(
                                    color: color.withOpacity(0.25), width: 1),
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
                  border: Border.all(color: Colors.green.shade200),
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

              Center(
                child: FilledButton.icon(
                  onPressed: () => Navigator.pop(dialogContext),
                  icon: const Icon(Icons.check_circle_outline_rounded, size: 18),
                  label: const Text('¡ENTENDIDO!', style: TextStyle(fontWeight: FontWeight.w800, letterSpacing: 1.1)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
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
