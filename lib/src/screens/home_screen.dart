import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:model_viewer_plus/model_viewer_plus.dart';

import '../inventory_store.dart';
import '../models.dart';
import 'product_form.dart';
import 'scanner_screen.dart';
import 'stock_dialog.dart';

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
            body: Center(child: CircularProgressIndicator()),
          );
        }
        return LayoutBuilder(
          builder: (context, constraints) {
            final wide = constraints.maxWidth >= 760;
            return Scaffold(
              appBar: AppBar(
                title: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.warehouse_rounded),
                    SizedBox(width: 10),
                    Text('My Love Depot'),
                  ],
                ),
                actions: [
                  Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: FilledButton.tonalIcon(
                      onPressed: () => _scanProduct(context),
                      icon: const Icon(Icons.qr_code_scanner_rounded),
                      label: const Text('Escanear'),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.only(right: 16),
                    child: FilledButton.icon(
                      onPressed: () => _openProductForm(context),
                      icon: const Icon(Icons.add),
                      label: const Text('Nuevo producto'),
                    ),
                  ),
                ],
              ),
              body: Row(
                children: [
                  if (wide)
                    NavigationRail(
                      selectedIndex: selectedIndex,
                      onDestinationSelected: (value) =>
                          setState(() => selectedIndex = value),
                      labelType: NavigationRailLabelType.all,
                      destinations: const [
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
                          icon: Icon(Icons.swap_horiz_rounded),
                          label: Text('Movimientos'),
                        ),
                      ],
                    ),
                  Expanded(child: _page()),
                ],
              ),
              bottomNavigationBar: wide
                  ? null
                  : NavigationBar(
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
                          icon: Icon(Icons.swap_horiz_rounded),
                          label: 'Movimientos',
                        ),
                      ],
                    ),
            );
          },
        );
      },
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
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: [
              SizedBox(
                width: 420,
                child: SearchBar(
                  leading: const Icon(Icons.search),
                  hintText: 'Buscar por nombre, SKU o categoría',
                  onChanged: (value) => setState(() => query = value),
                ),
              ),
              FilterChip(
                label: const Text('Solo stock bajo'),
                selected: lowStockOnly,
                onSelected: (value) => setState(() => lowStockOnly = value),
              ),
            ],
          ),
          const SizedBox(height: 18),
          Expanded(
            child: filtered.isEmpty
                ? const Center(child: Text('No se encontraron productos.'))
                : ListView.separated(
                    itemCount: filtered.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 10),
                    itemBuilder: (context, index) {
                      final product = filtered[index];
                      return Card(
                        child: ListTile(
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 18,
                            vertical: 10,
                          ),
                          leading: _ProductThumb(product: product),
                          title: Text(
                            product.name,
                            style: const TextStyle(fontWeight: FontWeight.w700),
                          ),
                          subtitle: Text(
                            '${product.sku} · ${product.category}\n'
                            '\$${product.price.toStringAsFixed(2)} por unidad',
                          ),
                          isThreeLine: true,
                          trailing: Wrap(
                            spacing: 4,
                            children: [
                              IconButton.filledTonal(
                                tooltip: 'Entrada o salida',
                                onPressed: () => showStockDialog(
                                  context,
                                  widget.store,
                                  product,
                                ),
                                icon: const Icon(Icons.swap_horiz),
                              ),
                              if (product.modelUrl.isNotEmpty)
                                IconButton.filledTonal(
                                  tooltip: 'Ver modelo 3D',
                                  onPressed: () => _showModel(context, product),
                                  icon: const Icon(Icons.view_in_ar_rounded),
                                ),
                              PopupMenuButton<String>(
                                onSelected: (value) {
                                  if (value == 'edit') {
                                    _openProductForm(context, product);
                                  } else {
                                    _confirmDelete(context, product);
                                  }
                                },
                                itemBuilder: (_) => const [
                                  PopupMenuItem(
                                    value: 'edit',
                                    child: Text('Editar'),
                                  ),
                                  PopupMenuItem(
                                    value: 'delete',
                                    child: Text('Eliminar'),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Future<void> _openProductForm(
    BuildContext context, [
    Product? product,
  ]) async {
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
      await widget.store.addOne(existing);
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            '${existing.name}: stock actualizado a ${existing.stock}',
          ),
        ),
      );
    } else {
      await showDialog<void>(
        context: context,
        builder: (_) => ProductForm(store: widget.store, initialBarcode: code),
      );
    }
  }

  Future<void> _showModel(BuildContext context, Product product) async {
    await showDialog<void>(
      context: context,
      builder: (context) => Dialog.fullscreen(
        child: Scaffold(
          appBar: AppBar(
            title: Text('${product.name} · Modelo 3D'),
            leading: IconButton(
              onPressed: () => Navigator.pop(context),
              icon: const Icon(Icons.close),
            ),
          ),
          body: ModelViewer(
            src: product.modelUrl,
            alt: 'Modelo 3D de ${product.name}',
            ar: true,
            autoRotate: true,
            cameraControls: true,
            backgroundColor: const Color(0xfffff8f0),
          ),
        ),
      ),
    );
  }

  Future<void> _confirmDelete(BuildContext context, Product product) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Eliminar producto'),
        content: Text('¿Deseas eliminar “${product.name}”?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Eliminar'),
          ),
        ],
      ),
    );
    if (confirmed == true) await widget.store.deleteProduct(product.id);
  }
}

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
        CircleAvatar(
          radius: 27,
          backgroundColor: Theme.of(context).colorScheme.primaryContainer,
          backgroundImage: bytes != null
              ? MemoryImage(bytes)
              : product.imageUrl.isNotEmpty
                  ? NetworkImage(product.imageUrl)
                  : null,
          child: bytes == null && product.imageUrl.isEmpty
              ? const Icon(Icons.inventory_2_outlined)
              : null,
        ),
        Positioned(
          right: -5,
          bottom: -5,
          child: Badge(label: Text('${product.stock}')),
        ),
      ],
    );
  }
}

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
          Text(
            'Resumen del almacén',
            style: Theme.of(context).textTheme.headlineMedium,
          ),
          const SizedBox(height: 6),
          const Text('Consulta rápidamente el estado de tu inventario.'),
          const SizedBox(height: 22),
          Wrap(
            spacing: 14,
            runSpacing: 14,
            children: [
              _MetricCard(
                icon: Icons.inventory_2,
                label: 'Productos',
                value: '${store.products.length}',
              ),
              _MetricCard(
                icon: Icons.layers_rounded,
                label: 'Unidades',
                value: '${store.totalUnits}',
              ),
              _MetricCard(
                icon: Icons.attach_money_rounded,
                label: 'Valor estimado',
                value: '\$${store.inventoryValue.toStringAsFixed(2)}',
              ),
              _MetricCard(
                icon: Icons.warning_amber_rounded,
                label: 'Stock bajo',
                value: '${store.lowStockCount}',
                warning: store.lowStockCount > 0,
                onTap: onShowProducts,
              ),
            ],
          ),
          const SizedBox(height: 28),
          Text(
            'Atención requerida',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 12),
          if (store.lowStockCount == 0)
            const Card(
              child: Padding(
                padding: EdgeInsets.all(20),
                child: Row(
                  children: [
                    Icon(Icons.check_circle_outline),
                    SizedBox(width: 12),
                    Text('Todos los productos tienen existencias suficientes.'),
                  ],
                ),
              ),
            )
          else
            ...store.products.where((item) => item.hasLowStock).map(
                  (product) => Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: Card(
                      child: ListTile(
                        leading: const Icon(Icons.warning_amber_rounded),
                        title: Text(product.name),
                        subtitle: Text(
                          '${product.stock} disponibles · mínimo ${product.minimumStock}',
                        ),
                        trailing: const Icon(Icons.chevron_right),
                        onTap: onShowProducts,
                      ),
                    ),
                  ),
                ),
        ],
      ),
    );
  }
}

class _MetricCard extends StatelessWidget {
  const _MetricCard({
    required this.icon,
    required this.label,
    required this.value,
    this.warning = false,
    this.onTap,
  });

  final IconData icon;
  final String label;
  final String value;
  final bool warning;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return SizedBox(
      width: 230,
      child: Card(
        color: warning ? colors.errorContainer : colors.surfaceContainerLowest,
        child: InkWell(
          borderRadius: BorderRadius.circular(20),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(icon, size: 30),
                const SizedBox(height: 18),
                Text(
                  value,
                  style: Theme.of(context)
                      .textTheme
                      .headlineSmall
                      ?.copyWith(fontWeight: FontWeight.w800),
                ),
                Text(label),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

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
          Text(
            'Historial de movimientos',
            style: Theme.of(context).textTheme.headlineSmall,
          ),
          const SizedBox(height: 18),
          Expanded(
            child: store.movements.isEmpty
                ? const Center(
                    child: Text(
                      'Todavía no hay entradas ni salidas registradas.',
                    ),
                  )
                : ListView.separated(
                    itemCount: store.movements.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 10),
                    itemBuilder: (context, index) {
                      final movement = store.movements[index];
                      final incoming = movement.type == MovementType.incoming;
                      return Card(
                        child: ListTile(
                          leading: CircleAvatar(
                            child: Icon(
                              incoming
                                  ? Icons.south_west_rounded
                                  : Icons.north_east_rounded,
                            ),
                          ),
                          title: Text(movement.productName),
                          subtitle: Text(
                            '${_date(movement.createdAt)}'
                            '${movement.note.isEmpty ? '' : ' · ${movement.note}'}',
                          ),
                          trailing: Text(
                            '${incoming ? '+' : '-'}${movement.quantity}',
                            style: Theme.of(context)
                                .textTheme
                                .titleMedium
                                ?.copyWith(fontWeight: FontWeight.bold),
                          ),
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
