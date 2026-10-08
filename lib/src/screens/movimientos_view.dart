import 'package:flutter/material.dart';

import '../inventory_store.dart';
import '../models.dart';
import '../ui/components.dart';
import 'resumen_view.dart';

enum MovementFilter { all, incoming, outgoing }

class MovimientosView extends StatefulWidget {
  const MovimientosView(
      {required this.store, required this.onGoToProducts, super.key});

  final InventoryStore store;
  final VoidCallback onGoToProducts;

  @override
  State<MovimientosView> createState() => _MovimientosViewState();
}

class _MovimientosViewState extends State<MovimientosView> {
  static const _page = 50;
  MovementFilter filter = MovementFilter.all;
  int visible = _page;

  @override
  Widget build(BuildContext context) {
    final all = [...widget.store.movements]
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
    final incoming = all.where((m) => m.type == MovementType.incoming).length;
    final outgoing = all.where((m) => m.type == MovementType.outgoing).length;
    final filtered = switch (filter) {
      MovementFilter.all => all,
      MovementFilter.incoming =>
        all.where((m) => m.type == MovementType.incoming).toList(),
      MovementFilter.outgoing =>
        all.where((m) => m.type == MovementType.outgoing).toList(),
    };
    final shown = filtered.take(visible).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        PageHeader(
          eyebrow:
              '${all.length} movimientos · $incoming entradas · $outgoing salidas',
          title: 'Historial de movimientos',
        ),
        const SizedBox(height: 20),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final (value, label, count) in [
              (MovementFilter.all, 'Todos', all.length),
              (MovementFilter.incoming, 'Entradas', incoming),
              (MovementFilter.outgoing, 'Salidas', outgoing),
            ])
              AppChip(
                label: label,
                count: count,
                selected: filter == value,
                onTap: () => setState(() {
                  filter = value;
                  visible = _page;
                }),
              ),
          ],
        ),
        const SizedBox(height: 20),
        if (filtered.isEmpty)
          EmptyBox(
            icon: Icons.swap_horiz_rounded,
            title: 'Sin movimientos en este filtro',
            message:
                'Las entradas y salidas se registran desde el catálogo de productos.',
            action: AppButton(
                label: 'Ir a productos', onPressed: widget.onGoToProducts),
          )
        else
          AppCard(
            padding: EdgeInsets.zero,
            child: Column(
              children: [
                for (var i = 0; i < shown.length; i++)
                  DecoratedBox(
                    decoration: BoxDecoration(
                      border: i == shown.length - 1
                          ? null
                          : const Border(
                              bottom: BorderSide(color: Color(0xFFF5EEF1))),
                    ),
                    child: MovementRow(movement: shown[i]),
                  ),
              ],
            ),
          ),
        if (filtered.length > shown.length) ...[
          const SizedBox(height: 16),
          Center(
            child: AppButton(
              label: 'Mostrar más',
              variant: AppButtonVariant.secondary,
              onPressed: () => setState(() => visible += _page),
            ),
          ),
        ],
      ],
    );
  }
}
