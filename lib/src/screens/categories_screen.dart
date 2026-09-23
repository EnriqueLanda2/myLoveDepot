import 'package:flutter/material.dart';

import '../inventory_store.dart';
import '../models.dart';

/// Paleta LIGHT (refinada, mismos colores que el resto de la app)
class _C {
  static const magenta = Color(0xffd94f87);
  static const magentaDeep = Color(0xffb5296b);
  static const bgCard = Color(0xffffffff);
  static const stroke = Color(0xffe8d0da);
  static const strokeLight = Color(0xfff3e4ed);
  static const textPrimary = Color(0xff3a2633);
  static const textSecondary = Color(0xff7a5c6b);
  static const red = Color(0xffb00020);
}

// Colores dinámicos por nombre de categoría
Color _categoryAccent(String name) {
  final hash = name.toLowerCase().hashCode;
  final hue = (hash % 360).abs().toDouble();
  return HSLColor.fromAHSL(1, hue, 0.55, 0.45).toColor();
}

Color _categoryBg(String name) {
  final hash = name.toLowerCase().hashCode;
  final hue = (hash % 360).abs().toDouble();
  return HSLColor.fromAHSL(1, hue, 0.35, 0.95).toColor();
}

/// Catálogo de categorías
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
          // ── Header ──────────────────────────────────────────────────────
          Row(
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
                child: const Icon(Icons.label_rounded, color: _C.magenta, size: 20),
              ),
              const SizedBox(width: 12),
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
                      style: TextStyle(
                        color: _C.textSecondary.withValues(alpha: 0.8),
                        fontSize: 11,
                        letterSpacing: 0.3,
                      ),
                    ),
                  ],
                ),
              ),
              // New category button
              Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(14),
                  gradient: const LinearGradient(
                    colors: [_C.magenta, _C.magentaDeep],
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: _C.magenta.withValues(alpha: 0.25),
                      blurRadius: 8,
                      offset: const Offset(0, 3),
                    ),
                  ],
                ),
                child: FilledButton.icon(
                  onPressed: () => _edit(context),
                  icon: const Icon(Icons.add_rounded, size: 16),
                  label: const Text(
                    'NUEVA CATEGORÍA',
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
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 20),

          // ── Divider ─────────────────────────────────────────────────────
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

          // ── List ────────────────────────────────────────────────────────
          Expanded(
            child: categories.isEmpty
                ? Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          padding: const EdgeInsets.all(24),
                          decoration: BoxDecoration(
                            color: _C.magenta.withValues(alpha: 0.06),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.label_outline,
                            color: _C.textSecondary,
                            size: 52,
                          ),
                        ),
                        const SizedBox(height: 20),
                        const Text(
                          'Sin categorías registradas',
                          style: TextStyle(
                            color: _C.textPrimary,
                            fontWeight: FontWeight.w800,
                            fontSize: 16,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          'Crea la primera con el botón de arriba.',
                          style: TextStyle(
                            color: _C.textSecondary.withValues(alpha: 0.7),
                            fontSize: 13,
                          ),
                        ),
                      ],
                    ),
                  )
                : ListView.separated(
                    itemCount: categories.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 10),
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
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(24)),
            title: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: _C.magenta.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(
                    category == null ? Icons.add_rounded : Icons.edit_rounded,
                    color: _C.magenta,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 12),
                Text(
                  category == null
                      ? 'NUEVA CATEGORÍA'
                      : 'RENOMBRAR CATEGORÍA',
                  style: const TextStyle(
                      letterSpacing: 1.5, fontWeight: FontWeight.w800, fontSize: 15),
                ),
              ],
            ),
            content: TextField(
              controller: controller,
              autofocus: true,
              textCapitalization: TextCapitalization.sentences,
              style: const TextStyle(color: _C.textPrimary),
              decoration: InputDecoration(
                labelText: 'Nombre de la categoría',
                errorText: error,
                prefixIcon: const Icon(Icons.label_outline,
                    size: 18, color: _C.magenta),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: const BorderSide(color: _C.magenta, width: 1.5),
                ),
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogContext),
                child: const Text('CANCELAR'),
              ),
              Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  gradient: const LinearGradient(
                    colors: [_C.magenta, _C.magentaDeep],
                  ),
                ),
                child: FilledButton(
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
                  style: FilledButton.styleFrom(
                    backgroundColor: Colors.transparent,
                    foregroundColor: Colors.white,
                    shadowColor: Colors.transparent,
                  ),
                  child: Text(
                    category == null ? 'REGISTRAR' : 'GUARDAR',
                    style: const TextStyle(
                        fontWeight: FontWeight.w800, letterSpacing: 1.2),
                  ),
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
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(24)),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: _C.red.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(Icons.delete_forever_rounded,
                  color: _C.red, size: 20),
            ),
            const SizedBox(width: 12),
            const Text(
              'ELIMINAR CATEGORÍA',
              style:
                  TextStyle(letterSpacing: 1.5, fontWeight: FontWeight.w800, fontSize: 15),
            ),
          ],
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
class _CategoryTile extends StatefulWidget {
  const _CategoryTile({
    required this.category,
    required this.onEdit,
    required this.onDelete,
  });
  final ProductCategory category;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  @override
  State<_CategoryTile> createState() => _CategoryTileState();
}

class _CategoryTileState extends State<_CategoryTile> {
  bool _hovering = false;

  @override
  Widget build(BuildContext context) {
    final accent = _categoryAccent(widget.category.name);
    final bg = _categoryBg(widget.category.name);

    return MouseRegion(
      onEnter: (_) => setState(() => _hovering = true),
      onExit: (_) => setState(() => _hovering = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
        decoration: BoxDecoration(
          color: _C.bgCard,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: _hovering ? accent.withValues(alpha: 0.4) : _C.strokeLight,
            width: _hovering ? 1.5 : 1,
          ),
          boxShadow: [
            BoxShadow(
              color: _hovering
                  ? accent.withValues(alpha: 0.08)
                  : Colors.black.withValues(alpha: 0.02),
              blurRadius: _hovering ? 12 : 4,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          children: [
            // Dynamic color icon
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: bg,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: accent.withValues(alpha: 0.2),
                  width: 1,
                ),
              ),
              child: Icon(Icons.label_rounded, color: accent, size: 18),
            ),
            const SizedBox(width: 16),

            // Info
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    widget.category.name,
                    style: const TextStyle(
                      color: _C.textPrimary,
                      fontWeight: FontWeight.w700,
                      fontSize: 14,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: accent.withValues(alpha: 0.08),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          widget.category.productCount == 1
                              ? '1 producto'
                              : '${widget.category.productCount} productos',
                          style: TextStyle(
                            color: accent,
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            // Actions
            _TileIconBtn(
              icon: Icons.edit_outlined,
              tooltip: 'Renombrar',
              onPressed: widget.onEdit,
              color: _C.textSecondary,
            ),
            const SizedBox(width: 4),
            _TileIconBtn(
              icon: Icons.delete_outline,
              tooltip: 'Eliminar',
              onPressed: widget.onDelete,
              color: _C.red,
            ),
          ],
        ),
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
      child: Material(
        color: color.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(8),
        child: InkWell(
          onTap: onPressed,
          borderRadius: BorderRadius.circular(8),
          child: Padding(
            padding: const EdgeInsets.all(8),
            child: Icon(icon, color: color, size: 18),
          ),
        ),
      ),
    );
  }
}
