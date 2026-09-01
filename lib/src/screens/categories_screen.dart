import 'package:flutter/material.dart';

import '../inventory_store.dart';
import '../models.dart';

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
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Categorías',
                      style: Theme.of(context).textTheme.headlineSmall,
                    ),
                    const SizedBox(height: 4),
                    const Text(
                      'Organiza tus productos para encontrarlos más rápido.',
                    ),
                  ],
                ),
              ),
              FilledButton.icon(
                onPressed: () => _edit(context),
                icon: const Icon(Icons.add),
                label: const Text('Nueva categoría'),
              ),
            ],
          ),
          const SizedBox(height: 20),
          Expanded(
            child: categories.isEmpty
                ? const Center(
                    child: Text(
                        'Aún no hay categorías. Crea la primera con el botón de arriba.'),
                  )
                : ListView.separated(
                    itemCount: categories.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 10),
                    itemBuilder: (context, index) {
                      final category = categories[index];
                      return Card(
                        child: ListTile(
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 18,
                            vertical: 6,
                          ),
                          leading: const CircleAvatar(
                            child: Icon(Icons.label_outline),
                          ),
                          title: Text(
                            category.name,
                            style: const TextStyle(fontWeight: FontWeight.w700),
                          ),
                          subtitle: Text(
                            category.productCount == 1
                                ? '1 producto'
                                : '${category.productCount} productos',
                          ),
                          trailing: Wrap(
                            spacing: 4,
                            children: [
                              IconButton(
                                tooltip: 'Renombrar',
                                onPressed: () => _edit(context, category),
                                icon: const Icon(Icons.edit_outlined),
                              ),
                              IconButton(
                                tooltip: 'Eliminar',
                                onPressed: () =>
                                    _confirmDelete(context, category),
                                icon: const Icon(Icons.delete_outline),
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

  Future<void> _edit(BuildContext context, [ProductCategory? category]) async {
    final controller = TextEditingController(text: category?.name);
    String? error;
    try {
      await showDialog<void>(
        context: context,
        builder: (dialogContext) => StatefulBuilder(
          builder: (dialogContext, setDialogState) => AlertDialog(
            title: Text(
              category == null ? 'Nueva categoría' : 'Renombrar categoría',
            ),
            content: TextField(
              controller: controller,
              autofocus: true,
              textCapitalization: TextCapitalization.sentences,
              decoration:
                  InputDecoration(labelText: 'Nombre', errorText: error),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogContext),
                child: const Text('Cancelar'),
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
                child: Text(category == null ? 'Registrar' : 'Guardar'),
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
        title: const Text('Eliminar categoría'),
        content: Text('¿Deseas eliminar “${category.name}”?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Eliminar'),
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
