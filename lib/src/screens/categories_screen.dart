import 'package:flutter/material.dart';

import '../inventory_store.dart';
import '../models.dart';

/// Paleta LIGHT (mismos colores que el resto de la app)
class _C {
  static const magenta = Color(0xffd94f87);
  static const bgCard = Color(0xffffffff);
  static const stroke = Color(0xffe8d0da);
  static const textPrimary = Color(0xff49343f);
  static const textSecondary = Color(0xff7a5c6b);
  static const red = Color(0xffb00020);
}

/// Catálogo de categorías: se registran aquí y el formulario de productos las
/// ofrece en su desplegable.
class CategoriesPage extends StatelessWidget {
  const CategoriesPage({required this.store, super.key});

  final InventoryStore store;

  @override
  Widget build(BuildContext context) {
    final categories = store.categories.toList()
      ..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));

    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // ── Header ────────────────────────────────────────────────────────
          Row(
            children: [
              // Accent bar
              Container(
                width: 3,
                height: 36,
                decoration: BoxDecoration(
                  color: _C.magenta,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'CATÁLOGO DE CATEGORÍAS',
                      style: TextStyle(
                        color: _C.textPrimary,
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 2,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${categories.length} categorías registradas  ·  organiza tu inventario',
                      style: const TextStyle(
                        color: _C.textSecondary,
                        fontSize: 11,
                        letterSpacing: 0.3,
                      ),
                    ),
                  ],
                ),
              ),
              // "Nueva categoría" button belongs here (it's a page-level action)
              FilledButton.icon(
                onPressed: () => _edit(context),
                icon: const Icon(Icons.add, size: 16),
                label: const Text(
                  'NUEVA CATEGORÍA',
                  style: TextStyle(
                    fontWeight: FontWeight.w800,
                    letterSpacing: 1.2,
                    fontSize: 12,
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 20),

          // ── Divider ────────────────────────────────────────────────────────
          Container(height: 1, color: _C.stroke),
          const SizedBox(height: 20),

          // ── List ───────────────────────────────────────────────────────────
          Expanded(
            child: categories.isEmpty
                ? Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          padding: const EdgeInsets.all(20),
                          decoration: BoxDecoration(
                            color: _C.bgCard,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: _C.stroke, width: 1),
                          ),
                          child: const Icon(
                            Icons.label_outline,
                            color: _C.textSecondary,
                            size: 48,
                          ),
                        ),
                        const SizedBox(height: 16),
                        const Text(
                          'Sin categorías registradas',
                          style: TextStyle(
                            color: _C.textPrimary,
                            fontWeight: FontWeight.w700,
                            fontSize: 14,
                          ),
                        ),
                        const SizedBox(height: 6),
                        const Text(
                          'Crea la primera con el botón de arriba.',
                          style: TextStyle(
                              color: _C.textSecondary, fontSize: 12),
                        ),
                      ],
                    ),
                  )
                : ListView.separated(
                    itemCount: categories.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 8),
                    itemBuilder: (context, index) {
                      final category = categories[index];
                      return _CategoryTile(
                        category: category,
                        onEdit: () => _edit(context, category),
                        onDelete: () => _confirmDelete(context, category),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Future<void> _edit(BuildContext context,
      [ProductCategory? category]) async {
    final controller = TextEditingController(text: category?.name);
    String? error;
    try {
      await showDialog<void>(
        context: context,
        builder: (dialogContext) => StatefulBuilder(
          builder: (dialogContext, setDialogState) => AlertDialog(
            title: Text(
              category == null
                  ? 'NUEVA CATEGORÍA'
                  : 'RENOMBRAR CATEGORÍA',
              style: const TextStyle(
                  letterSpacing: 1.5, fontWeight: FontWeight.w800),
            ),
            content: TextField(
              controller: controller,
              autofocus: true,
              textCapitalization: TextCapitalization.sentences,
              style: const TextStyle(color: _C.textPrimary),
              decoration: InputDecoration(
                labelText: 'Nombre de la categoría',
                errorText: error,
                prefixIcon: const Icon(Icons.label_outline, size: 18),
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogContext),
                child: const Text('CANCELAR'),
              ),
              FilledButton(
                onPressed: () async {
                  final name = controller.text.trim();
                  final failure = category == null
                      ? await store.saveCategory(name)
                      : await store.renameCategory(category, name);
                  if (failure != null) {
                    setDialogState(() => error = failure);
                    return;
                  }
                  if (dialogContext.mounted) Navigator.pop(dialogContext);
                },
                child: Text(
                  category == null ? 'REGISTRAR' : 'GUARDAR',
                  style: const TextStyle(
                      fontWeight: FontWeight.w800, letterSpacing: 1.2),
                ),
              ),
            ],
          ),
        ),
      );
    } finally {
      controller.dispose();
    }
  }

  Future<void> _confirmDelete(
    BuildContext context,
    ProductCategory category,
  ) async {
    final messenger = ScaffoldMessenger.of(context);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text(
          'ELIMINAR CATEGORÍA',
          style:
              TextStyle(letterSpacing: 1.5, fontWeight: FontWeight.w800),
        ),
        content: Text(
          '¿Deseas eliminar "${category.name}"?\n'
          'Los productos con esta categoría quedarán sin asignar.',
          style: const TextStyle(color: _C.textSecondary, height: 1.5),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('CANCELAR'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            style: FilledButton.styleFrom(
              backgroundColor: _C.red,
              foregroundColor: Colors.white,
            ),
            child: const Text(
              'ELIMINAR',
              style: TextStyle(
                  fontWeight: FontWeight.w800, letterSpacing: 1.2),
            ),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    final failure = await store.deleteCategory(category);
    if (failure != null) {
      messenger.showSnackBar(SnackBar(content: Text(failure)));
    }
  }
}

// ── Category tile ─────────────────────────────────────────────────────────────
class _CategoryTile extends StatelessWidget {
  const _CategoryTile({
    required this.category,
    required this.onEdit,
    required this.onDelete,
  });
  final ProductCategory category;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: _C.bgCard,
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: _C.stroke, width: 1),
      ),
      child: Row(
        children: [
          // Icon
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: _C.magenta.withOpacity(0.1),
              borderRadius: BorderRadius.circular(4),
              border:
                  Border.all(color: _C.magenta.withOpacity(0.2), width: 1),
            ),
            child: const Icon(Icons.label_outline,
                color: _C.magenta, size: 16),
          ),
          const SizedBox(width: 14),

          // Info
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  category.name,
                  style: const TextStyle(
                    color: _C.textPrimary,
                    fontWeight: FontWeight.w700,
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  category.productCount == 1
                      ? '1 producto'
                      : '${category.productCount} productos',
                  style: const TextStyle(
                      color: _C.textSecondary, fontSize: 12),
                ),
              ],
            ),
          ),

          // Actions — belong on the tile itself
          _TileIconBtn(
            icon: Icons.edit_outlined,
            tooltip: 'Renombrar',
            onPressed: onEdit,
          ),
          const SizedBox(width: 4),
          _TileIconBtn(
            icon: Icons.delete_outline,
            tooltip: 'Eliminar',
            onPressed: onDelete,
            color: _C.red,
          ),
        ],
      ),
    );
  }
}

class _TileIconBtn extends StatelessWidget {
  const _TileIconBtn({
    required this.icon,
    required this.tooltip,
    required this.onPressed,
    this.color = _C.textSecondary,
  });
  final IconData icon;
  final String tooltip;
  final VoidCallback onPressed;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(4),
        child: Padding(
          padding: const EdgeInsets.all(6),
          child: Icon(icon, color: color, size: 18),
        ),
      ),
    );
  }
}
