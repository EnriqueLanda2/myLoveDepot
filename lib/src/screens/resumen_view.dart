import 'package:flutter/material.dart';

import '../inventory_store.dart';
import '../models.dart';
import '../ui/components.dart';
import '../ui/tokens.dart';
import 'movement_modal.dart';

class ResumenView extends StatelessWidget {
  const ResumenView({
    required this.store,
    required this.onShowLowStock,
    required this.onShowMovements,
    super.key,
  });

  final InventoryStore store;
  final VoidCallback onShowLowStock;
  final VoidCallback onShowMovements;

  @override
  Widget build(BuildContext context) {
    final products = store.products;
    final low = products.where((p) => p.hasLowStock).toList()
      ..sort((a, b) => a.stock.compareTo(b.stock));
    final out = low.where((p) => p.isOutOfStock).length;
    final recent = [...store.movements]
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));

    final kpis = [
      _Kpi(Icons.inventory_2_outlined, 'Unidades en stock',
          '${store.totalUnits}', '${products.length} productos'),
      _Kpi(Icons.payments_outlined, 'Valor del almacén',
          money0(store.inventoryValue), 'A precio de venta'),
      _Kpi(Icons.today_outlined, 'Ganancias hoy', money0(store.todayEarnings),
          '${store.todaySalesUnits} unidades vendidas'),
      _Kpi(
          Icons.calendar_month_outlined,
          'Ganancias del mes',
          money0(store.monthEarnings),
          '${store.monthSalesUnits} unidades vendidas'),
    ];

    final attention = SectionCard(
      title: 'Requiere atención',
      subtitle: low.isEmpty
          ? 'Sin alertas'
          : '$out agotados · ${low.length - out} en el mínimo',
      action: AppButton(
        label: 'Ver en catálogo',
        variant: AppButtonVariant.link,
        onPressed: onShowLowStock,
      ),
      empty: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 32),
        child: Text(
          'Todo el inventario está por encima del mínimo.',
          textAlign: TextAlign.center,
          style: appText(size: 14, color: AppColors.textSecondary),
        ),
      ),
      children: [
        for (final product in low.take(8))
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            child: Row(
              children: [
                Container(
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(
                    color: product.isOutOfStock
                        ? AppColors.errorStrong
                        : AppColors.warningDot,
                    shape: BoxShape.circle,
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
                      Text(
                        [
                          if (product.shade.isNotEmpty) product.shade,
                          product.isOutOfStock
                              ? 'Agotado'
                              : '${product.stock} disponible · mínimo ${product.minimumStock}',
                        ].join(' · '),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style:
                            appText(size: 13, color: AppColors.textSecondary),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 10),
                AppButton(
                  label: 'Reabastecer',
                  icon: Icons.add_rounded,
                  variant: AppButtonVariant.soft,
                  compact: true,
                  onPressed: () => showMovementModal(context, store, product,
                      type: MovementType.incoming),
                ),
              ],
            ),
          ),
      ],
    );

    final movements = SectionCard(
      title: 'Últimos movimientos',
      action: AppButton(
        label: 'Ver historial',
        variant: AppButtonVariant.link,
        onPressed: onShowMovements,
      ),
      empty: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 32),
        child: Text(
          'Aún no hay entradas ni salidas registradas.',
          textAlign: TextAlign.center,
          style: appText(size: 14, color: AppColors.textSecondary),
        ),
      ),
      children: [
        for (final movement in recent.take(5))
          MovementRow(movement: movement, compact: true),
      ],
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        PageHeader(
            eyebrow: longDate(DateTime.now()), title: 'Resumen del almacén'),
        const SizedBox(height: 24),
        LayoutBuilder(builder: (context, constraints) {
          final columns =
              columnsFor(constraints.maxWidth, 220, 12, max: 4, min: 2);
          final width = (constraints.maxWidth - 12 * (columns - 1)) / columns;
          return Wrap(
            spacing: 12,
            runSpacing: 12,
            children: [
              for (final kpi in kpis)
                SizedBox(width: width, child: _KpiCard(kpi: kpi)),
            ],
          );
        }),
        const SizedBox(height: 24),
        LayoutBuilder(builder: (context, constraints) {
          if (constraints.maxWidth < 700) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [attention, const SizedBox(height: 16), movements],
            );
          }
          return Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(child: attention),
              const SizedBox(width: 16),
              Expanded(child: movements),
            ],
          );
        }),
      ],
    );
  }
}

class _Kpi {
  const _Kpi(this.icon, this.label, this.value, this.sub);
  final IconData icon;
  final String label;
  final String value;
  final String sub;
}

class _KpiCard extends StatelessWidget {
  const _KpiCard({required this.kpi});
  final _Kpi kpi;

  @override
  Widget build(BuildContext context) {
    final compact = MediaQuery.sizeOf(context).width < 600;
    return AppCard(
      padding:
          EdgeInsets.symmetric(horizontal: compact ? 14 : 20, vertical: 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(kpi.icon, size: 18, color: AppColors.textSecondary),
              const SizedBox(width: 8),
              Expanded(
                child: Text(kpi.label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: appText(
                        size: 13,
                        weight: FontWeight.w500,
                        color: AppColors.textSecondary)),
              ),
            ],
          ),
          const SizedBox(height: 10),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(kpi.value,
                style: appText(
                    size: compact ? 24 : 28,
                    weight: FontWeight.w700,
                    letterSpacing: -0.3)),
          ),
          const SizedBox(height: 10),
          Text(kpi.sub,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: appText(size: 13, color: AppColors.textSecondary)),
        ],
      ),
    );
  }
}

/// Fila de un movimiento (Resumen y Movimientos).
class MovementRow extends StatelessWidget {
  const MovementRow({required this.movement, this.compact = false, super.key});
  final StockMovement movement;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final out = movement.isOutgoing;
    final bg = out ? AppColors.primarySoft : AppColors.successSoft;
    final fg = out ? AppColors.primaryText : AppColors.success;
    final dateColumn = !compact && MediaQuery.sizeOf(context).width >= 600;
    final details = [
      if (movement.productShade.isNotEmpty) movement.productShade,
      if (!compact && movement.note.isNotEmpty) movement.note,
      // Sin columna de fecha (teléfono), la fecha va en el subtítulo.
      if (!compact && !dateColumn) relativeDate(movement.createdAt),
    ].join(' · ');
    return Padding(
      padding:
          EdgeInsets.symmetric(horizontal: compact ? 20 : 18, vertical: 12),
      child: Row(
        children: [
          Container(
            width: compact ? 32 : 36,
            height: compact ? 32 : 36,
            decoration: BoxDecoration(
                color: bg, borderRadius: BorderRadius.circular(10)),
            child: Icon(
                out ? Icons.north_east_rounded : Icons.south_west_rounded,
                size: compact ? 18 : 20,
                color: fg),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                    movement.productName.isEmpty
                        ? 'Producto eliminado'
                        : movement.productName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: appText(size: 14, weight: FontWeight.w600)),
                const SizedBox(height: 2),
                Text(
                  compact
                      ? relativeDate(movement.createdAt)
                      : (details.isEmpty
                          ? relativeDate(movement.createdAt)
                          : details),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: appText(size: 12, color: AppColors.textSecondary),
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text('${out ? '−' : '+'}${movement.quantity} u',
                  style: appText(size: 14, weight: FontWeight.w700, color: fg)),
              if (!compact) ...[
                const SizedBox(height: 2),
                Text(
                  out ? '+${money(movement.profit)} ganancia' : 'Inventario',
                  style: appText(size: 12, color: AppColors.textSecondary),
                ),
              ],
            ],
          ),
          if (dateColumn) ...[
            const SizedBox(width: 14),
            SizedBox(
              width: 84,
              child: Text(
                relativeDate(movement.createdAt),
                textAlign: TextAlign.right,
                style: appText(size: 12, color: AppColors.textSecondary),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
