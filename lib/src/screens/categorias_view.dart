import 'package:flutter/material.dart';

import '../inventory_store.dart';
import '../models.dart';
import '../ui/components.dart';
import '../ui/tokens.dart';

class CategoriasView extends StatefulWidget {
  const CategoriasView(
      {required this.store, required this.onViewProducts, super.key});

  final InventoryStore store;
  final ValueChanged<String> onViewProducts;

  @override
  State<CategoriasView> createState() => _CategoriasViewState();
}

class _CategoriasViewState extends State<CategoriasView> {
  final newCategory = TextEditingController();
  bool creating = false;

  @override
  void dispose() {
    newCategory.dispose();
    super.dispose();
  }

  Future<void> _create() async {
    final name = newCategory.text.trim();
    if (name.isEmpty || creating) return;
    setState(() => creating = true);
    final failure = await widget.store.saveCategory(name);
    if (!mounted) return;
    setState(() => creating = false);
    if (failure != null) {
      AppToast.show(context, failure, warning: true);
      return;
    }
    newCategory.clear();
    AppToast.show(context, 'Categoría creada');
  }

  Future<void> _rename(ProductCategory category) async {
    final controller = TextEditingController(text: category.name);
    final name = await showAppModal<String>(
      context,
      maxWidth: 420,
      builder: (dialogContext) => ModalBody(
        title: 'Renombrar categoría',
        subtitle: 'Los productos de esta categoría se actualizan solos.',
        body: [
          TextField(
            controller: controller,
            autofocus: true,
            style: appText(size: 14),
            decoration: appInputDecoration(hint: 'Nombre'),
            onSubmitted: (value) => Navigator.pop(dialogContext, value),
          ),
        ],
        actions: [
          AppButton(
            label: 'Cancelar',
            variant: AppButtonVariant.secondary,
            onPressed: () => Navigator.pop(dialogContext),
          ),
          AppButton(
            label: 'Guardar',
            onPressed: () => Navigator.pop(dialogContext, controller.text),
          ),
        ],
      ),
    );
    controller.dispose();
    if (name == null || name.trim() == category.name || !mounted) return;
    final failure = await widget.store.renameCategory(category, name);
    if (!mounted) return;
    AppToast.show(context, failure ?? 'Categoría renombrada',
        warning: failure != null);
  }

  Future<void> _delete(ProductCategory category) async {
    final failure = await widget.store.deleteCategory(category);
    if (!mounted) return;
    AppToast.show(context, failure ?? 'Categoría eliminada',
        warning: failure != null);
  }

  @override
  Widget build(BuildContext context) {
    final store = widget.store;
    final products = store.products;
    // Incluye categorías que solo existen en productos (aún sin registrar).
    final registered = {for (final c in store.categories) c.name: c};
    final names = store.categoryNames;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        PageHeader(
          eyebrow: '${names.length} categorías · ${products.length} productos',
          title: 'Categorías',
        ),
        const SizedBox(height: 20),
        Wrap(
          spacing: 10,
          runSpacing: 10,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            SizedBox(
              width: MediaQuery.sizeOf(context).width < 600
                  ? double.infinity
                  : 360,
              child: TextField(
                controller: newCategory,
                onSubmitted: (_) => _create(),
                onChanged: (_) => setState(() {}),
                textCapitalization: TextCapitalization.sentences,
                style: appText(size: 14),
                decoration:
                    appInputDecoration(hint: 'Nombre de la nueva categoría'),
              ),
            ),
            AppButton(
              label: 'Crear categoría',
              icon: Icons.add_rounded,
              onPressed:
                  newCategory.text.trim().isEmpty || creating ? null : _create,
            ),
          ],
        ),
        const SizedBox(height: 20),
        if (names.isEmpty)
          const EmptyBox(
            icon: Icons.sell_outlined,
            title: 'Aún no hay categorías',
            message:
                'Agrupan tus productos (por ejemplo Makeup, Skincare o Perfumes). Crea la primera arriba.',
          )
        else
          LayoutBuilder(builder: (context, constraints) {
            final columns = columnsFor(constraints.maxWidth, 260, 14, max: 4);
            final width = (constraints.maxWidth - 14 * (columns - 1)) / columns;
            return Wrap(
              spacing: 14,
              runSpacing: 14,
              children: [
                for (var i = 0; i < names.length; i++)
                  SizedBox(
                    width: width,
                    child: _CategoryCard(
                      index: i,
                      name: names[i],
                      products: products
                          .where((p) => p.category == names[i])
                          .toList(),
                      onView: () => widget.onViewProducts(names[i]),
                      onRename: registered[names[i]] == null
                          ? null
                          : () => _rename(registered[names[i]]!),
                      onDelete: registered[names[i]] == null
                          ? null
                          : () => _delete(registered[names[i]]!),
                    ),
                  ),
              ],
            );
          }),
      ],
    );
  }
}

class _CategoryCard extends StatelessWidget {
  const _CategoryCard({
    required this.index,
    required this.name,
    required this.products,
    required this.onView,
    required this.onRename,
    required this.onDelete,
  });

  final int index;
  final String name;
  final List<Product> products;
  final VoidCallback onView;
  final VoidCallback? onRename;
  final VoidCallback? onDelete;

  @override
  Widget build(BuildContext context) {
    final count = products.length;
    final units = products.fold(0, (sum, p) => sum + p.stock);
    final value = products.fold(0.0, (sum, p) => sum + p.inventoryValue);
    final canDelete = count == 0 && onDelete != null;

    Widget stat(String label, String text) => Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label,
                style: appText(size: 12, color: AppColors.textSecondary)),
            const SizedBox(height: 2),
            FittedBox(
              fit: BoxFit.scaleDown,
              child:
                  Text(text, style: appText(size: 14, weight: FontWeight.w700)),
            ),
          ],
        );

    return AppCard(
      padding: const EdgeInsets.fromLTRB(20, 18, 14, 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: CategoryPalette.soft(index),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(Icons.sell_outlined,
                    size: 20, color: CategoryPalette.color(index)),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: appText(size: 16, weight: FontWeight.w700)),
              ),
              if (onRename != null)
                AppIconButton(
                    icon: Icons.edit_outlined,
                    tooltip: 'Renombrar',
                    onPressed: onRename),
              AppIconButton(
                icon: Icons.delete_outline_rounded,
                tooltip: canDelete
                    ? 'Eliminar categoría'
                    : count > 0
                        ? 'No se puede eliminar: tiene productos'
                        : 'Se registra al guardar un producto',
                hoverColor: AppColors.errorStrong,
                onPressed: canDelete ? onDelete : null,
              ),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(child: stat('Productos', '$count')),
              Expanded(child: stat('Unidades', '$units')),
              Expanded(child: stat('Valor', money0(value))),
            ],
          ),
          const SizedBox(height: 10),
          AppButton(
              label: 'Ver productos',
              variant: AppButtonVariant.link,
              onPressed: onView),
        ],
      ),
    );
  }
}
