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
                    LoveMascot(size: 42),
                    SizedBox(width: 8),
                    Text('My Love Depot'),
                  ],
                ),
                actions: [
                  if (wide)
                    Center(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 8),
                        child: Chip(
                          avatar: const Icon(Icons.verified_user_outlined,
                              size: 18),
                          label: Text(widget.store.role),
                        ),
                      ),
                    ),
                  if (wide)
                    Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: FilledButton.tonalIcon(
                        onPressed: () => _scanProduct(context),
                        icon: const Icon(Icons.qr_code_scanner_rounded),
                        label: const Text('Escanear'),
                      ),
                    ),
                  if (!wide)
                    IconButton(
                      tooltip: 'Escanear producto',
                      onPressed: () => _scanProduct(context),
                      icon: const Icon(Icons.qr_code_scanner_rounded),
                    ),
                  IconButton(
                    tooltip: 'Cerrar sesión',
                    onPressed: widget.store.logout,
                    icon: const Icon(Icons.logout),
                  ),
                  if (wide)
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
                          icon: Icon(Icons.label_outline),
                          selectedIcon: Icon(Icons.label),
                          label: Text('Categorías'),
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
              floatingActionButton: wide
                  ? null
                  : FloatingActionButton.extended(
                      onPressed: () => _openProductForm(context),
                      icon: const Icon(Icons.add_rounded),
                      label: const Text('Nuevo producto'),
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
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('Tus productos',
              style: Theme.of(context).textTheme.headlineSmall),
          const SizedBox(height: 4),
          const Text('Busca, consulta existencias o registra algo nuevo.'),
          const SizedBox(height: 16),
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
                              IconButton.filledTonal(
                                tooltip: 'Ver detalle',
                                onPressed: () => _showDetails(context, product),
                                icon: const Icon(Icons.visibility_outlined),
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
                          onTap: () => _showDetails(context, product),
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
          appBar: AppBar(
            title: Text(product.name),
            leading: IconButton(
              onPressed: () => Navigator.pop(context),
              icon: const Icon(Icons.close),
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
    // El diálogo no escucha al store, así que el progreso se lleva aquí.
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
        color: Theme.of(context).colorScheme.surfaceContainerLow,
        child: hasModel && showModel
            ? _ModelStage(
                product: product,
                onShowPhotos: images.isEmpty
                    ? null
                    : () => setState(() => showModel = false),
              )
            : images.isEmpty
                ? const Center(
                    child: Icon(Icons.inventory_2_outlined, size: 110))
                : Column(children: [
                    if (hasModel)
                      Align(
                        alignment: Alignment.centerRight,
                        child: Padding(
                          padding: const EdgeInsets.only(top: 12, right: 12),
                          child: TextButton.icon(
                            onPressed: () => setState(() => showModel = true),
                            icon: const Icon(Icons.view_in_ar_outlined),
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
                      child: Text(images.length > 1
                          ? 'Desliza para girar · Vista ${imageIndex + 1} de ${images.length}'
                          : 'Pellizca para ampliar la imagen'),
                    ),
                  ]),
      );
      final info = SingleChildScrollView(
        padding: const EdgeInsets.all(28),
        child:
            Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Text(product.name, style: Theme.of(context).textTheme.headlineMedium),
          const SizedBox(height: 8),
          Wrap(spacing: 8, runSpacing: 8, children: [
            Chip(label: Text(product.category)),
            Chip(
                label: Text(product.hasLowStock ? 'Stock bajo' : 'Disponible'),
                avatar: Icon(product.hasLowStock
                    ? Icons.warning_amber
                    : Icons.check_circle_outline)),
          ]),
          const SizedBox(height: 24),
          _detailRow(Icons.qr_code, 'Código',
              product.barcode.isEmpty ? 'Sin código' : product.barcode),
          _detailRow(Icons.sell_outlined, 'SKU', product.sku),
          _detailRow(Icons.inventory_2_outlined, 'Existencias',
              '${product.stock} unidades'),
          _detailRow(Icons.low_priority, 'Stock mínimo',
              '${product.minimumStock} unidades'),
          _detailRow(Icons.payments_outlined, 'Precio',
              '\$${product.price.toStringAsFixed(2)}'),
          _detailRow(
              Icons.account_balance_wallet_outlined,
              'Valor en inventario',
              '\$${product.inventoryValue.toStringAsFixed(2)}'),
          const SizedBox(height: 24),
          FilledButton.icon(
              onPressed: widget.onStock,
              icon: const Icon(Icons.swap_horiz),
              label: const Text('Registrar movimiento')),
          const SizedBox(height: 10),
          OutlinedButton.icon(
              onPressed: widget.onEdit,
              icon: const Icon(Icons.edit_outlined),
              label: const Text('Editar producto')),
          const SizedBox(height: 10),
          _ModelButton(
            hasModel: hasModel,
            hasPhotos: images.isNotEmpty,
            building: building || widget.store.isBuildingModel(product.id),
            onPressed: _buildModel,
          ),
        ]),
      );
      return wide
          ? Row(children: [
              Expanded(flex: 3, child: gallery),
              Expanded(flex: 2, child: info)
            ])
          : Column(children: [
              Expanded(flex: 3, child: gallery),
              Expanded(flex: 4, child: info)
            ]);
    });
  }

  Widget _detailRow(IconData icon, String label, String value) => Padding(
        padding: const EdgeInsets.only(bottom: 16),
        child: Row(children: [
          Icon(icon),
          const SizedBox(width: 14),
          Expanded(
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                Text(label, style: Theme.of(context).textTheme.labelMedium),
                Text(value, style: Theme.of(context).textTheme.titleMedium)
              ])),
        ]),
      );
}

/// Visor del modelo generado a partir de las fotografías del producto.
class _ModelStage extends StatelessWidget {
  const _ModelStage({required this.product, this.onShowPhotos});

  final Product product;
  final VoidCallback? onShowPhotos;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
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
          backgroundColor: colors.surfaceContainerLow,
        ),
      ),
      Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Flexible(
              child: Text(
                'Arrastra para girar · pellizca para acercar · avatar calculado desde las fotos',
                textAlign: TextAlign.center,
              ),
            ),
            if (onShowPhotos != null) ...[
              const SizedBox(width: 12),
              TextButton.icon(
                onPressed: onShowPhotos,
                icon: const Icon(Icons.photo_library_outlined),
                label: const Text('Fotos'),
              ),
            ],
          ],
        ),
      ),
    ]);
  }
}

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
          child: CircularProgressIndicator(strokeWidth: 2),
        ),
        label: const Text('Generando modelo 3D…'),
      );
    }
    return OutlinedButton.icon(
      onPressed: hasPhotos ? onPressed : null,
      icon: const Icon(Icons.view_in_ar_outlined),
      label: Text(
        !hasPhotos
            ? 'Agrega fotos para generar el modelo'
            : hasModel
                ? 'Regenerar modelo 3D'
                : 'Generar modelo 3D',
      ),
    );
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
