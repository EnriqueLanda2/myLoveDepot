import 'package:flutter/material.dart';

import '../inventory_store.dart';
import '../models.dart';
import '../ui/components.dart';
import '../ui/tokens.dart';
import 'movement_modal.dart';

/// Filtros del catálogo. Viven en el shell para que Resumen y Categorías
/// puedan abrir Productos ya filtrado.
class ProductFilter {
  String query = '';
  String category = allCategories;
  bool lowOnly = false;
  bool listLayout = false;
  int visible = pageSize;

  static const allCategories = 'Todas';
  static const pageSize = 24;

  void reset({String category = allCategories, bool lowOnly = false}) {
    query = '';
    this.category = category;
    this.lowOnly = lowOnly;
    visible = pageSize;
  }
}

class ProductosView extends StatefulWidget {
  const ProductosView({
    required this.store,
    required this.filter,
    required this.onFilterChanged,
    required this.onNewProduct,
    required this.onEditProduct,
    super.key,
  });

  final InventoryStore store;
  final ProductFilter filter;
  final VoidCallback onFilterChanged;
  final VoidCallback onNewProduct;
  final ValueChanged<Product> onEditProduct;

  @override
  State<ProductosView> createState() => _ProductosViewState();
}

class _ProductosViewState extends State<ProductosView> {
  late final search = TextEditingController(text: widget.filter.query);

  ProductFilter get filter => widget.filter;

  @override
  void dispose() {
    search.dispose();
    super.dispose();
  }

  void _update(VoidCallback change) {
    change();
    widget.onFilterChanged();
  }

  void _delete(Product product) {
    final undo = widget.store.deleteProductWithUndo(product);
    AppToast.show(context, 'Producto eliminado', onUndo: undo);
  }

  @override
  Widget build(BuildContext context) {
    final store = widget.store;
    final products = store.products;
    final lowCount = products.where((p) => p.hasLowStock).length;
    final q = filter.query.trim().toLowerCase();
    final filtered = products.where((p) {
      final matchesCategory = filter.category == ProductFilter.allCategories ||
          p.category == filter.category;
      final matchesLow = !filter.lowOnly || p.hasLowStock;
      final haystack =
          '${p.name} ${p.shade} ${p.sku} ${p.category}'.toLowerCase();
      return matchesCategory &&
          matchesLow &&
          (q.isEmpty || haystack.contains(q));
    }).toList()
      ..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
    final visible = filtered.take(filter.visible).toList();
    final hasFilters = q.isNotEmpty ||
        filter.lowOnly ||
        filter.category != ProductFilter.allCategories;

    final categories = [ProductFilter.allCategories, ...store.categoryNames];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        PageHeader(
          eyebrow: '${products.length} productos · $lowCount con stock bajo',
          title: 'Catálogo de productos',
          actions: [
            AppButton(
              label: 'Nuevo producto',
              icon: Icons.add_a_photo_outlined,
              onPressed: widget.onNewProduct,
            ),
          ],
        ),
        const SizedBox(height: 20),
        Wrap(
          spacing: 10,
          runSpacing: 10,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            ConstrainedBox(
              constraints: const BoxConstraints(minWidth: 240, maxWidth: 520),
              child: SizedBox(
                width: MediaQuery.sizeOf(context).width < 600
                    ? double.infinity
                    : 420,
                child: TextField(
                  controller: search,
                  onChanged: (value) => _update(() {
                    filter.query = value;
                    filter.visible = ProductFilter.pageSize;
                  }),
                  style: appText(size: 14),
                  decoration: appInputDecoration(
                    hint: 'Buscar por nombre, tono o SKU',
                    prefix: const Icon(Icons.search_rounded,
                        color: AppColors.textSecondary),
                    suffix: search.text.isEmpty
                        ? null
                        : IconButton(
                            tooltip: 'Borrar búsqueda',
                            icon: const Icon(Icons.close_rounded, size: 18),
                            onPressed: () {
                              search.clear();
                              _update(() => filter.query = '');
                            },
                          ),
                  ),
                ),
              ),
            ),
            AppChip(
              label: 'Stock bajo',
              icon: Icons.warning_amber_rounded,
              selected: filter.lowOnly,
              selectedColor: AppColors.warningSoft,
              selectedForeground: AppColors.warning,
              selectedBorder: AppColors.warningBorder,
              onTap: () => _update(() {
                filter.lowOnly = !filter.lowOnly;
                filter.visible = ProductFilter.pageSize;
              }),
            ),
            AppSegmented<bool>(
              selected: filter.listLayout,
              onChanged: (value) => _update(() => filter.listLayout = value),
              options: const [
                AppSegment(
                    value: false,
                    icon: Icons.grid_view_rounded,
                    tooltip: 'Cuadrícula'),
                AppSegment(
                    value: true,
                    icon: Icons.view_list_rounded,
                    tooltip: 'Lista'),
              ],
            ),
          ],
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final category in categories)
              AppChip(
                label: category,
                count: category == ProductFilter.allCategories
                    ? products.length
                    : products.where((p) => p.category == category).length,
                selected: filter.category == category,
                onTap: () => _update(() {
                  filter.category = category;
                  filter.visible = ProductFilter.pageSize;
                }),
              ),
          ],
        ),
        const SizedBox(height: 20),
        if (filtered.isEmpty)
          products.isEmpty
              ? EmptyBox(
                  icon: Icons.inventory_2_outlined,
                  title: 'Todavía no tienes productos',
                  message:
                      'Sube la foto de un producto y la IA te ayuda a llenar su ficha.',
                  action: AppButton(
                    label: 'Nuevo producto',
                    icon: Icons.add_a_photo_outlined,
                    onPressed: widget.onNewProduct,
                  ),
                )
              : EmptyBox(
                  title: 'Ningún producto coincide con la búsqueda.',
                  action: hasFilters
                      ? AppButton(
                          label: 'Quitar filtros',
                          variant: AppButtonVariant.secondary,
                          onPressed: () {
                            search.clear();
                            _update(filter.reset);
                          },
                        )
                      : null,
                )
        else if (filter.listLayout)
          AppCard(
            padding: EdgeInsets.zero,
            child: Column(
              children: [
                for (var i = 0; i < visible.length; i++)
                  DecoratedBox(
                    decoration: BoxDecoration(
                      border: i == visible.length - 1
                          ? null
                          : const Border(
                              bottom: BorderSide(color: AppColors.borderSoft)),
                    ),
                    child: _ProductRow(
                      product: visible[i],
                      onIncoming: () => showMovementModal(
                          context, store, visible[i],
                          type: MovementType.incoming),
                      onOutgoing: () =>
                          showMovementModal(context, store, visible[i]),
                      onEdit: () => widget.onEditProduct(visible[i]),
                      onDelete: () => _delete(visible[i]),
                    ),
                  ),
              ],
            ),
          )
        else
          LayoutBuilder(builder: (context, constraints) {
            final phone = constraints.maxWidth < 600;
            final columns = columnsFor(
                constraints.maxWidth, phone ? 160 : 230, 14,
                max: 6, min: phone ? 2 : 1);
            final gap = phone ? 10.0 : 14.0;
            final width =
                (constraints.maxWidth - gap * (columns - 1)) / columns;
            return Wrap(
              spacing: gap,
              runSpacing: gap,
              children: [
                for (final product in visible)
                  SizedBox(
                    width: width,
                    child: _ProductCard(
                      product: product,
                      compact: phone,
                      onIncoming: () => showMovementModal(
                          context, store, product,
                          type: MovementType.incoming),
                      onOutgoing: () =>
                          showMovementModal(context, store, product),
                      onEdit: () => widget.onEditProduct(product),
                      onDelete: () => _delete(product),
                    ),
                  ),
              ],
            );
          }),
        if (filtered.length > visible.length) ...[
          const SizedBox(height: 20),
          Center(
            child: AppButton(
              label:
                  'Mostrar más (${filtered.length - visible.length} restantes)',
              variant: AppButtonVariant.secondary,
              onPressed: () =>
                  _update(() => filter.visible += ProductFilter.pageSize),
            ),
          ),
        ],
      ],
    );
  }
}

class _ProductCard extends StatefulWidget {
  const _ProductCard({
    required this.product,
    required this.compact,
    required this.onIncoming,
    required this.onOutgoing,
    required this.onEdit,
    required this.onDelete,
  });

  final Product product;
  final bool compact;
  final VoidCallback onIncoming;
  final VoidCallback onOutgoing;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  @override
  State<_ProductCard> createState() => _ProductCardState();
}

class _ProductCardState extends State<_ProductCard> {
  bool hovering = false;

  @override
  Widget build(BuildContext context) {
    final product = widget.product;
    final compact = widget.compact;
    return MouseRegion(
      onEnter: (_) => setState(() => hovering = true),
      onExit: (_) => setState(() => hovering = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.border),
          boxShadow: hovering
              ? const [
                  BoxShadow(
                      color: Color(0x122A1F24),
                      blurRadius: 24,
                      offset: Offset(0, 8))
                ]
              : null,
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            AspectRatio(
              aspectRatio: 4 / 3,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  ProductImage(product: product),
                  Positioned(
                    top: 10,
                    left: 10,
                    right: 84,
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: AppColors.surface,
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: Text(
                          product.category.toUpperCase(),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: appText(
                            size: 11,
                            weight: FontWeight.w600,
                            color: AppColors.textSecondary,
                            letterSpacing: 0.4,
                          ),
                        ),
                      ),
                    ),
                  ),
                  Positioned(
                    top: 8,
                    right: 8,
                    child: Row(
                      children: [
                        AppIconButton(
                          icon: Icons.edit_outlined,
                          tooltip: 'Editar',
                          color: AppColors.text,
                          background: AppColors.surface,
                          onPressed: widget.onEdit,
                        ),
                        const SizedBox(width: 4),
                        AppIconButton(
                          icon: Icons.delete_outline_rounded,
                          tooltip: 'Eliminar',
                          color: AppColors.text,
                          hoverColor: AppColors.errorStrong,
                          background: AppColors.surface,
                          onPressed: widget.onDelete,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: EdgeInsets.fromLTRB(
                  compact ? 12 : 16, 14, compact ? 12 : 16, 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  SizedBox(
                    height: 40,
                    child: Text(
                      product.name,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: appText(
                          size: 15, weight: FontWeight.w600, height: 1.3),
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    product.shade.isEmpty ? '—' : product.shade,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: appText(size: 13, color: AppColors.textSecondary),
                  ),
                  const SizedBox(height: 12),
                  Wrap(
                    alignment: WrapAlignment.spaceBetween,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    spacing: 8,
                    runSpacing: 6,
                    children: [
                      Text(money0(product.price),
                          style: appText(size: 20, weight: FontWeight.w700)),
                      StockPill(product: product),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: _CardAction(
                          label: 'Entrada',
                          icon: Icons.add_rounded,
                          foreground: AppColors.success,
                          background: AppColors.surface,
                          hover: AppColors.successSoft,
                          border: AppColors.successBorder,
                          onPressed: widget.onIncoming,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: _CardAction(
                          label: 'Salida',
                          icon: Icons.remove_rounded,
                          foreground: Colors.white,
                          background: AppColors.primary,
                          hover: AppColors.primaryHover,
                          tooltip: product.isOutOfStock
                              ? 'Sin existencias para vender'
                              : null,
                          onPressed:
                              product.isOutOfStock ? null : widget.onOutgoing,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CardAction extends StatelessWidget {
  const _CardAction({
    required this.label,
    required this.icon,
    required this.foreground,
    required this.background,
    required this.hover,
    required this.onPressed,
    this.border,
    this.tooltip,
  });

  final String label;
  final IconData icon;
  final Color foreground;
  final Color background;
  final Color hover;
  final Color? border;
  final String? tooltip;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final enabled = onPressed != null;
    final button = TextButton(
      onPressed: onPressed,
      style: ButtonStyle(
        padding: const WidgetStatePropertyAll(
            EdgeInsets.symmetric(vertical: 9, horizontal: 4)),
        minimumSize: const WidgetStatePropertyAll(Size(0, 0)),
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        overlayColor: const WidgetStatePropertyAll(Colors.transparent),
        backgroundColor: WidgetStateProperty.resolveWith((states) {
          if (!enabled) return const Color(0xFFF3EDEF);
          return states.contains(WidgetState.hovered) ? hover : background;
        }),
        foregroundColor:
            WidgetStatePropertyAll(enabled ? foreground : AppColors.textMuted),
        shape: WidgetStatePropertyAll(RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
          side: border != null && enabled
              ? BorderSide(color: border!)
              : BorderSide.none,
        )),
        mouseCursor: WidgetStatePropertyAll(
            enabled ? SystemMouseCursors.click : SystemMouseCursors.forbidden),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 18),
          const SizedBox(width: 4),
          Flexible(
            // En tarjetas angostas la etiqueta se encoge en lugar de cortarse.
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(label,
                  style: appText(
                    size: 13,
                    weight: FontWeight.w600,
                    color: enabled ? foreground : AppColors.textMuted,
                  )),
            ),
          ),
        ],
      ),
    );
    return tooltip == null ? button : Tooltip(message: tooltip!, child: button);
  }
}

class _ProductRow extends StatelessWidget {
  const _ProductRow({
    required this.product,
    required this.onIncoming,
    required this.onOutgoing,
    required this.onEdit,
    required this.onDelete,
  });

  final Product product;
  final VoidCallback onIncoming;
  final VoidCallback onOutgoing;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final wide = MediaQuery.sizeOf(context).width >= 760;
    final subtitle = [
      if (product.shade.isNotEmpty) product.shade,
      if (product.sku.isNotEmpty) product.sku,
      if (!wide) money0(product.price),
    ].join(' · ');
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Row(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: SizedBox.square(
              dimension: 44,
              child: ProductImage(product: product, showPlaceholderText: false),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(product.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: appText(size: 14, weight: FontWeight.w600)),
                const SizedBox(height: 2),
                Text(subtitle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: appText(size: 12, color: AppColors.textSecondary)),
              ],
            ),
          ),
          if (wide) ...[
            SizedBox(
              width: 100,
              child: Text(product.category,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: appText(size: 13, color: AppColors.textSecondary)),
            ),
            SizedBox(
              width: 90,
              child: Text(money0(product.price),
                  style: appText(size: 14, weight: FontWeight.w700)),
            ),
            SizedBox(
                width: 120,
                child: Align(
                    alignment: Alignment.centerLeft,
                    child: StockPill(product: product))),
          ] else ...[
            const SizedBox(width: 8),
            StockPill(product: product),
            const SizedBox(width: 8),
          ],
          AppIconButton(
            icon: Icons.add_rounded,
            tooltip: 'Entrada',
            size: 34,
            color: AppColors.success,
            hoverColor: AppColors.success,
            borderColor: AppColors.successBorder,
            onPressed: onIncoming,
          ),
          const SizedBox(width: 4),
          AppIconButton(
            icon: Icons.remove_rounded,
            tooltip:
                product.isOutOfStock ? 'Sin existencias para vender' : 'Salida',
            size: 34,
            color: AppColors.primary,
            borderColor: AppColors.primaryBorder,
            onPressed: product.isOutOfStock ? null : onOutgoing,
          ),
          if (wide) ...[
            const SizedBox(width: 4),
            AppIconButton(
                icon: Icons.edit_outlined,
                tooltip: 'Editar',
                size: 34,
                onPressed: onEdit),
            AppIconButton(
              icon: Icons.delete_outline_rounded,
              tooltip: 'Eliminar',
              size: 34,
              hoverColor: AppColors.errorStrong,
              onPressed: onDelete,
            ),
          ] else
            PopupMenuButton<String>(
              tooltip: 'Más acciones',
              icon: const Icon(Icons.more_vert_rounded,
                  size: 20, color: AppColors.textSecondary),
              onSelected: (value) => value == 'edit' ? onEdit() : onDelete(),
              itemBuilder: (_) => const [
                PopupMenuItem(value: 'edit', child: Text('Editar')),
                PopupMenuItem(value: 'delete', child: Text('Eliminar')),
              ],
            ),
        ],
      ),
    );
  }
}
