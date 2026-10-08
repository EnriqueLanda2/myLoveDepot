import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../inventory_store.dart';
import '../models.dart';
import '../ui/components.dart';
import '../ui/tokens.dart';
import 'finance_modals.dart';

enum ExpensePeriod { week, month, all }

class FinanzasView extends StatefulWidget {
  const FinanzasView({required this.store, super.key});
  final InventoryStore store;

  @override
  State<FinanzasView> createState() => _FinanzasViewState();
}

class _FinanzasViewState extends State<FinanzasView> {
  ExpensePeriod period = ExpensePeriod.week;
  int visibleExpenses = 20;

  InventoryStore get store => widget.store;

  void _deleteExpense(Expense expense) {
    final undo = store.deleteExpenseWithUndo(expense);
    AppToast.show(context, 'Gasto eliminado', onUndo: undo);
  }

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final budget = store.weeklyBudget;
    final currentWeek = InventoryStore.weekStart(now);
    final spentThisWeek = store.spentInWeek(currentWeek);
    final remaining = budget - spentThisWeek;
    final daysLeft = 8 - now.weekday;
    final closed = store.closedWeeks;
    final lastWeek =
        DateTime(currentWeek.year, currentWeek.month, currentWeek.day - 7);
    final lastSave = budget - store.spentInWeek(lastWeek);
    final saved = store.totalSaved;
    final balance = store.availableBalance;

    // Colores estables por categoría: orden alfabético de todas las usadas.
    final allCategories = store.expenses.map((e) => e.category).toSet().toList()
      ..sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));
    Color colorOf(String category) =>
        CategoryPalette.color(allCategories.indexOf(category));

    final periodExpenses = store.expenses
        .where((e) => switch (period) {
              ExpensePeriod.week => !e.createdAt.isBefore(currentWeek),
              ExpensePeriod.month =>
                e.createdAt.year == now.year && e.createdAt.month == now.month,
              ExpensePeriod.all => true,
            })
        .toList();
    final periodTotal = periodExpenses.fold(0.0, (sum, e) => sum + e.amount);
    final byCategory = <String, double>{};
    for (final e in periodExpenses) {
      byCategory[e.category] = (byCategory[e.category] ?? 0) + e.amount;
    }
    final categoryTotals = byCategory.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    final weekCard = _BigCard(
      icon: Icons.shopping_bag_outlined,
      iconColor: AppColors.primary,
      title: remaining >= 0
          ? 'Puedes gastar esta semana'
          : 'Te pasaste esta semana',
      value: money(remaining.abs()),
      valueColor: remaining >= 0 ? AppColors.success : AppColors.error,
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(999),
          child: LinearProgressIndicator(
            minHeight: 10,
            value: budget <= 0 ? 1 : math.min(1, spentThisWeek / budget),
            backgroundColor: AppColors.borderSoft,
            color: remaining < 0
                ? AppColors.errorStrong
                : budget > 0 && spentThisWeek / budget > 0.8
                    ? AppColors.warningDot
                    : AppColors.primary,
          ),
        ),
        Wrap(
          alignment: WrapAlignment.spaceBetween,
          spacing: 8,
          runSpacing: 4,
          children: [
            Text('Gastado ${money(spentThisWeek)} de ${money(budget)}',
                style: appText(size: 13, color: AppColors.textSecondary)),
            Text(
              remaining > 0
                  ? '≈ ${money(remaining / daysLeft)} por día · $daysLeft ${daysLeft == 1 ? 'día' : 'días'}'
                  : '$daysLeft ${daysLeft == 1 ? 'día restante' : 'días restantes'}',
              style: appText(size: 13, color: AppColors.textSecondary),
            ),
          ],
        ),
      ],
    );

    final savedCard = _BigCard(
      icon: Icons.savings_outlined,
      iconColor: AppColors.success,
      title: 'Llevas ahorrado',
      value: money(saved),
      valueColor: saved >= 0 ? AppColors.success : AppColors.error,
      children: [
        Text(
          closed.isEmpty
              ? 'Lo que no gastes de tu presupuesto se suma aquí al cerrar cada semana (domingo).'
              : 'Lo que no gastaste de tu presupuesto en ${closed.length == 1 ? 'la última semana cerrada' : 'las últimas ${closed.length} semanas cerradas'}.',
          style:
              appText(size: 13, color: AppColors.textSecondary, height: 1.45),
        ),
        if (closed.isNotEmpty)
          Align(
            alignment: Alignment.centerLeft,
            child: Pill(
              text:
                  'Semana pasada: ${lastSave >= 0 ? '+' : '−'}${money(lastSave.abs())}',
              background:
                  lastSave >= 0 ? AppColors.successSoft : AppColors.errorSoft,
              foreground: lastSave >= 0 ? AppColors.success : AppColors.error,
            ),
          ),
      ],
    );

    Widget breakdown(String label, String value,
            [Color color = AppColors.text]) =>
        Row(
          children: [
            Expanded(
                child: Text(label,
                    style: appText(size: 13, color: AppColors.textSecondary))),
            Text(value,
                style:
                    appText(size: 13, weight: FontWeight.w600, color: color)),
          ],
        );

    final balanceCard = _BigCard(
      icon: Icons.account_balance_wallet_outlined,
      iconColor: AppColors.info,
      title: 'Saldo disponible',
      value: money(balance),
      valueColor: balance < 0 ? AppColors.error : AppColors.text,
      children: [
        breakdown('Fondo inicial', money(store.walletBaseBalance)),
        if (store.includeSalesInBalance)
          breakdown('+ Ganancias por ventas', money(store.totalSalesProfit),
              AppColors.success),
        breakdown('− Gastos totales', money(store.totalExpenses),
            AppColors.primaryText),
        Row(
          children: [
            Expanded(
              child: Text('Sumar ganancias por ventas',
                  style: appText(size: 13, color: AppColors.textSecondary)),
            ),
            Switch(
              value: store.includeSalesInBalance,
              activeThumbColor: Colors.white,
              activeTrackColor: AppColors.primary,
              onChanged: store.setIncludeSalesInBalance,
            ),
          ],
        ),
      ],
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        PageHeader(
          eyebrow: 'Presupuesto semanal, ahorro y saldo',
          title: 'Finanzas personales',
          actions: [
            AppButton(
              label: 'Presupuesto semanal',
              icon: Icons.date_range_outlined,
              variant: AppButtonVariant.secondary,
              onPressed: () => showBudgetModal(context, store),
            ),
            AppButton(
              label: 'Fondo inicial',
              icon: Icons.account_balance_outlined,
              variant: AppButtonVariant.secondary,
              onPressed: () => showFundModal(context, store),
            ),
            AppButton(
              label: 'Registrar gasto',
              icon: Icons.add_rounded,
              onPressed: () => showExpenseModal(context, store),
            ),
          ],
        ),
        const SizedBox(height: 20),
        if (store.walletBaseBalance == 0 && balance < 0) ...[
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
            decoration: BoxDecoration(
              color: AppColors.warningSoft,
              borderRadius: BorderRadius.circular(14),
            ),
            child: Wrap(
              crossAxisAlignment: WrapCrossAlignment.center,
              spacing: 14,
              runSpacing: 10,
              children: [
                const Icon(Icons.info_outline_rounded,
                    size: 20, color: AppColors.warningDark),
                ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 640),
                  child: Text(
                    'Tu saldo aparece en negativo porque aún no registras un fondo inicial. '
                    'Registra con cuánto dinero empezaste para ver tu saldo real.',
                    style: appText(
                        size: 14, color: AppColors.warningDark, height: 1.45),
                  ),
                ),
                TextButton(
                  onPressed: () => showFundModal(context, store),
                  style: TextButton.styleFrom(
                    backgroundColor: AppColors.warningDark,
                    foregroundColor: Colors.white,
                    padding:
                        const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10)),
                  ),
                  child: Text('Registrar fondo',
                      style: appText(
                          size: 13,
                          weight: FontWeight.w600,
                          color: Colors.white)),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
        ],
        LayoutBuilder(builder: (context, constraints) {
          final columns = columnsFor(constraints.maxWidth, 280, 14, max: 3);
          final width = (constraints.maxWidth - 14 * (columns - 1)) / columns;
          return Wrap(
            spacing: 14,
            runSpacing: 14,
            children: [
              for (final card in [weekCard, savedCard, balanceCard])
                SizedBox(width: width, child: card),
            ],
          );
        }),
        const SizedBox(height: 20),
        _WeeklyChart(store: store),
        const SizedBox(height: 24),
        Wrap(
          alignment: WrapAlignment.spaceBetween,
          crossAxisAlignment: WrapCrossAlignment.center,
          spacing: 12,
          runSpacing: 12,
          children: [
            Text.rich(
              TextSpan(
                children: [
                  const TextSpan(text: 'Detalle de gastos · '),
                  TextSpan(
                    text: money(periodTotal),
                    style: const TextStyle(color: AppColors.primaryText),
                  ),
                ],
              ),
              style: appText(size: 18, weight: FontWeight.w700),
            ),
            AppSegmented<ExpensePeriod>(
              expand: MediaQuery.sizeOf(context).width < 600,
              selected: period,
              onChanged: (value) => setState(() {
                period = value;
                visibleExpenses = 20;
              }),
              options: const [
                AppSegment(value: ExpensePeriod.week, label: 'Esta semana'),
                AppSegment(value: ExpensePeriod.month, label: 'Este mes'),
                AppSegment(value: ExpensePeriod.all, label: 'Todo'),
              ],
            ),
          ],
        ),
        const SizedBox(height: 16),
        LayoutBuilder(builder: (context, constraints) {
          final categoriesCard = AppCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text('Gastos por categoría',
                    style: appText(size: 16, weight: FontWeight.w700)),
                const SizedBox(height: 16),
                ClipRRect(
                  borderRadius: BorderRadius.circular(999),
                  child: SizedBox(
                    height: 14,
                    child: categoryTotals.isEmpty
                        ? const ColoredBox(color: AppColors.borderSoft)
                        : Row(
                            children: [
                              for (var i = 0;
                                  i < categoryTotals.length;
                                  i++) ...[
                                if (i > 0) const SizedBox(width: 2),
                                Expanded(
                                  flex: math.max(
                                      1,
                                      (categoryTotals[i].value /
                                              periodTotal *
                                              1000)
                                          .round()),
                                  child: Tooltip(
                                    message: categoryTotals[i].key,
                                    child: ColoredBox(
                                        color: colorOf(categoryTotals[i].key)),
                                  ),
                                ),
                              ],
                            ],
                          ),
                  ),
                ),
                const SizedBox(height: 8),
                if (categoryTotals.isEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 12),
                    child: Text('No hay gastos en este periodo.',
                        style:
                            appText(size: 14, color: AppColors.textSecondary)),
                  ),
                for (final entry in categoryTotals)
                  Container(
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    decoration: const BoxDecoration(
                      border: Border(
                          bottom: BorderSide(color: AppColors.borderSoft)),
                    ),
                    child: Row(
                      children: [
                        _Swatch(color: colorOf(entry.key)),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(entry.key,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style:
                                  appText(size: 14, weight: FontWeight.w600)),
                        ),
                        Text(money(entry.value),
                            style: appText(size: 14, weight: FontWeight.w700)),
                        SizedBox(
                          width: 56,
                          child: Text(
                            '${(entry.value / periodTotal * 100).toStringAsFixed(1)}%',
                            textAlign: TextAlign.right,
                            style: appText(
                                size: 13, color: AppColors.textSecondary),
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          );

          final shown = periodExpenses.take(visibleExpenses).toList();
          final recentCard = AppCard(
            padding: EdgeInsets.zero,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 20, 20, 12),
                  child: Text('Gastos recientes',
                      style: appText(size: 16, weight: FontWeight.w700)),
                ),
                if (shown.isEmpty)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
                    child: Text('No hay gastos en este periodo.',
                        style:
                            appText(size: 14, color: AppColors.textSecondary)),
                  ),
                for (final expense in shown)
                  Container(
                    padding: const EdgeInsets.fromLTRB(20, 10, 12, 10),
                    decoration: const BoxDecoration(
                      border:
                          Border(top: BorderSide(color: AppColors.borderSoft)),
                    ),
                    child: Row(
                      children: [
                        _Swatch(color: colorOf(expense.category)),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(expense.category,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: appText(
                                      size: 14, weight: FontWeight.w600)),
                              const SizedBox(height: 2),
                              Text(
                                [
                                  relativeDate(expense.createdAt),
                                  if (expense.note.isNotEmpty) expense.note
                                ].join(' · '),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: appText(
                                    size: 12, color: AppColors.textSecondary),
                              ),
                            ],
                          ),
                        ),
                        Text(money(expense.amount),
                            style: appText(size: 14, weight: FontWeight.w700)),
                        const SizedBox(width: 4),
                        AppIconButton(
                          icon: Icons.delete_outline_rounded,
                          tooltip: 'Eliminar gasto',
                          color: AppColors.textMuted,
                          hoverColor: AppColors.errorStrong,
                          onPressed: () => _deleteExpense(expense),
                        ),
                      ],
                    ),
                  ),
                if (periodExpenses.length > shown.length)
                  Padding(
                    padding: const EdgeInsets.all(12),
                    child: Center(
                      child: AppButton(
                        label: 'Mostrar más',
                        variant: AppButtonVariant.link,
                        onPressed: () => setState(() => visibleExpenses += 20),
                      ),
                    ),
                  ),
              ],
            ),
          );

          if (constraints.maxWidth < 700) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                categoriesCard,
                const SizedBox(height: 16),
                recentCard
              ],
            );
          }
          return Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(child: categoriesCard),
              const SizedBox(width: 16),
              Expanded(child: recentCard),
            ],
          );
        }),
      ],
    );
  }
}

class _Swatch extends StatelessWidget {
  const _Swatch({required this.color});
  final Color color;

  @override
  Widget build(BuildContext context) => Container(
        width: 10,
        height: 10,
        decoration:
            BoxDecoration(color: color, borderRadius: BorderRadius.circular(3)),
      );
}

class _BigCard extends StatelessWidget {
  const _BigCard({
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.value,
    required this.valueColor,
    required this.children,
  });

  final IconData icon;
  final Color iconColor;
  final String title;
  final String value;
  final Color valueColor;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      radius: 20,
      padding: const EdgeInsets.all(22),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Icon(icon, size: 20, color: iconColor),
              const SizedBox(width: 8),
              Expanded(
                child: Text(title,
                    style: appText(
                        size: 14,
                        weight: FontWeight.w500,
                        color: AppColors.textSecondary)),
              ),
            ],
          ),
          const SizedBox(height: 12),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(value,
                style: appText(
                    size: 40,
                    weight: FontWeight.w700,
                    color: valueColor,
                    letterSpacing: -0.6)),
          ),
          for (final child in children) ...[const SizedBox(height: 12), child],
        ],
      ),
    );
  }
}

/// Barras de gasto de las últimas 6 semanas contra la línea del presupuesto.
class _WeeklyChart extends StatelessWidget {
  const _WeeklyChart({required this.store});
  final InventoryStore store;

  @override
  Widget build(BuildContext context) {
    final budget = store.weeklyBudget;
    final current = InventoryStore.weekStart(DateTime.now());
    final weeks = [
      for (var i = 5; i >= 0; i--)
        DateTime(current.year, current.month, current.day - 7 * i),
    ];
    final spent = [for (final w in weeks) store.spentInWeek(w)];
    final maxValue = [budget, ...spent, 1.0].reduce(math.max) * 1.12;
    const chartHeight = 150.0;

    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Wrap(
            alignment: WrapAlignment.spaceBetween,
            spacing: 12,
            runSpacing: 8,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text('Semana a semana',
                      style: appText(size: 16, weight: FontWeight.w700)),
                  const SizedBox(height: 2),
                  Text(
                    'Lo que gastaste cada semana contra tu presupuesto de ${money0(budget)}',
                    style: appText(size: 13, color: AppColors.textSecondary),
                  ),
                ],
              ),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const _Swatch(color: AppColors.chartBar),
                  const SizedBox(width: 6),
                  Text('Gastado',
                      style: appText(size: 12, color: AppColors.textSecondary)),
                  const SizedBox(width: 14),
                  const SizedBox(width: 14, child: _DashedLine()),
                  const SizedBox(width: 6),
                  Text('Presupuesto',
                      style: appText(size: 12, color: AppColors.textSecondary)),
                ],
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              for (var i = 0; i < weeks.length; i++)
                Expanded(
                  child: Builder(builder: (context) {
                    final isCurrent = i == weeks.length - 1;
                    final value = spent[i];
                    final over = value > budget;
                    final save = budget - value;
                    return Column(
                      children: [
                        FittedBox(
                          fit: BoxFit.scaleDown,
                          child: Text(money0(value),
                              style:
                                  appText(size: 12, weight: FontWeight.w600)),
                        ),
                        const SizedBox(height: 8),
                        SizedBox(
                          height: chartHeight,
                          child: LayoutBuilder(builder: (context, constraints) {
                            final w = constraints.maxWidth;
                            return Stack(
                              children: [
                                Positioned(
                                  left: w * 0.25,
                                  width: w * 0.5,
                                  bottom: 0,
                                  height: math.min(chartHeight,
                                      value / maxValue * chartHeight),
                                  child: Container(
                                    decoration: BoxDecoration(
                                      color: over
                                          ? AppColors.chartOver
                                          : isCurrent
                                              ? AppColors.primary
                                              : AppColors.chartBar,
                                      borderRadius: const BorderRadius.vertical(
                                        top: Radius.circular(8),
                                        bottom: Radius.circular(3),
                                      ),
                                    ),
                                  ),
                                ),
                                Positioned(
                                  left: 0,
                                  right: 0,
                                  bottom: budget / maxValue * chartHeight,
                                  child: const _DashedLine(),
                                ),
                              ],
                            );
                          }),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          isCurrent ? 'Esta semana' : shortDate(weeks[i]),
                          textAlign: TextAlign.center,
                          style: appText(
                              size: 12,
                              weight: isCurrent
                                  ? FontWeight.w700
                                  : FontWeight.w500),
                        ),
                        const SizedBox(height: 2),
                        FittedBox(
                          fit: BoxFit.scaleDown,
                          child: Text(
                            isCurrent
                                ? (save >= 0
                                    ? 'quedan ${money0(save)}'
                                    : 'excedido')
                                : '${save >= 0 ? '+' : '−'}${money0(save.abs())}',
                            style: appText(
                              size: 12,
                              weight: FontWeight.w600,
                              color: isCurrent
                                  ? AppColors.textSecondary
                                  : save >= 0
                                      ? AppColors.success
                                      : AppColors.error,
                            ),
                          ),
                        ),
                      ],
                    );
                  }),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _DashedLine extends StatelessWidget {
  const _DashedLine();

  @override
  Widget build(BuildContext context) => const SizedBox(
      height: 2,
      child: CustomPaint(painter: _DashPainter(), size: Size.infinite));
}

class _DashPainter extends CustomPainter {
  const _DashPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = AppColors.chartLine
      ..strokeWidth = 2;
    for (double x = 0; x < size.width; x += 7) {
      canvas.drawLine(
          Offset(x, 1), Offset(math.min(x + 4, size.width), 1), paint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
