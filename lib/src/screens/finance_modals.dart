import 'package:flutter/material.dart';

import '../inventory_store.dart';
import '../ui/components.dart';
import '../ui/tokens.dart';

/// Registrar un gasto: monto grande, categoría (existente o nueva) y nota.
Future<void> showExpenseModal(BuildContext context, InventoryStore store) {
  return showAppModal<void>(
    context,
    maxWidth: 460,
    builder: (_) => _ExpenseModal(store: store, toastContext: context),
  );
}

class _ExpenseModal extends StatefulWidget {
  const _ExpenseModal({required this.store, required this.toastContext});
  final InventoryStore store;
  final BuildContext toastContext;

  @override
  State<_ExpenseModal> createState() => _ExpenseModalState();
}

class _ExpenseModalState extends State<_ExpenseModal> {
  final amount = TextEditingController();
  final category = TextEditingController();
  final note = TextEditingController();
  bool saving = false;

  bool get valid =>
      (parseAmount(amount.text) ?? 0) > 0 && category.text.trim().isNotEmpty;

  @override
  void dispose() {
    amount.dispose();
    category.dispose();
    note.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!valid || saving) return;
    setState(() => saving = true);
    final failure = await widget.store.addExpense(
      amount: parseAmount(amount.text)!,
      category: category.text,
      note: note.text,
    );
    if (!mounted || !widget.toastContext.mounted) return;
    if (failure != null) {
      setState(() => saving = false);
      AppToast.show(widget.toastContext, failure, warning: true);
      return;
    }
    Navigator.pop(context);
    AppToast.show(widget.toastContext, 'Gasto registrado');
  }

  @override
  Widget build(BuildContext context) {
    final existing = widget.store.expenseCategories;
    final typed = category.text.trim().toLowerCase();
    return ModalBody(
      title: 'Registrar gasto',
      body: [
        AmountField(controller: amount, onChanged: (_) => setState(() {})),
        Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('Categoría',
                style: appText(size: 13, weight: FontWeight.w600)),
            const SizedBox(height: 8),
            if (existing.isNotEmpty) ...[
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final name in existing)
                    AppChip(
                      label: name,
                      selected: name.toLowerCase() == typed,
                      onTap: () => setState(() => category.text = name),
                    ),
                ],
              ),
              const SizedBox(height: 8),
            ],
            TextField(
              controller: category,
              onChanged: (_) => setState(() {}),
              textCapitalization: TextCapitalization.sentences,
              style: appText(size: 14),
              decoration: appInputDecoration(
                hint: existing.isEmpty
                    ? 'Ej. Comida, Farmacia, Transporte'
                    : 'O escribe una categoría nueva',
              ),
            ),
          ],
        ),
        TextField(
          controller: note,
          onSubmitted: (_) => _save(),
          style: appText(size: 14),
          decoration: appInputDecoration(hint: 'Nota (opcional)'),
        ),
      ],
      actions: [
        AppButton(
          label: 'Cancelar',
          variant: AppButtonVariant.secondary,
          onPressed: () => Navigator.pop(context),
        ),
        AppButton(
            label: 'Guardar gasto', onPressed: valid && !saving ? _save : null),
      ],
    );
  }
}

/// Modal de un solo monto (fondo inicial o presupuesto semanal).
Future<void> showAmountModal(
  BuildContext context, {
  required String title,
  required String subtitle,
  required String saveLabel,
  required double initial,
  required Future<void> Function(double value) onSave,
  required String doneMessage,
}) {
  return showAppModal<void>(
    context,
    maxWidth: 420,
    builder: (_) => _AmountModal(
      title: title,
      subtitle: subtitle,
      saveLabel: saveLabel,
      initial: initial,
      onSave: onSave,
      doneMessage: doneMessage,
      toastContext: context,
    ),
  );
}

class _AmountModal extends StatefulWidget {
  const _AmountModal({
    required this.title,
    required this.subtitle,
    required this.saveLabel,
    required this.initial,
    required this.onSave,
    required this.doneMessage,
    required this.toastContext,
  });

  final String title;
  final String subtitle;
  final String saveLabel;
  final double initial;
  final Future<void> Function(double value) onSave;
  final String doneMessage;
  final BuildContext toastContext;

  @override
  State<_AmountModal> createState() => _AmountModalState();
}

class _AmountModalState extends State<_AmountModal> {
  late final amount = TextEditingController(
    text: widget.initial > 0 ? widget.initial.toStringAsFixed(2) : '',
  );

  @override
  void dispose() {
    amount.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    await widget.onSave(parseAmount(amount.text) ?? 0);
    if (!mounted || !widget.toastContext.mounted) return;
    Navigator.pop(context);
    AppToast.show(widget.toastContext, widget.doneMessage);
  }

  @override
  Widget build(BuildContext context) {
    return ModalBody(
      title: widget.title,
      subtitle: widget.subtitle,
      body: [AmountField(controller: amount, onSubmitted: (_) => _save())],
      actions: [
        AppButton(
          label: 'Cancelar',
          variant: AppButtonVariant.secondary,
          onPressed: () => Navigator.pop(context),
        ),
        AppButton(label: widget.saveLabel, onPressed: _save),
      ],
    );
  }
}

Future<void> showFundModal(BuildContext context, InventoryStore store) =>
    showAmountModal(
      context,
      title: 'Fondo inicial',
      subtitle:
          'El dinero con el que empezaste. Tu saldo se calcula restando los gastos a este monto.',
      saveLabel: 'Guardar fondo',
      initial: store.walletBaseBalance,
      onSave: store.setWalletBaseBalance,
      doneMessage: 'Fondo inicial actualizado',
    );

Future<void> showBudgetModal(BuildContext context, InventoryStore store) =>
    showAmountModal(
      context,
      title: 'Presupuesto semanal',
      subtitle:
          'Lo máximo que quieres gastar cada semana (lunes a domingo). Lo que no gastes se suma a tu ahorro.',
      saveLabel: 'Guardar presupuesto',
      initial: store.weeklyBudget,
      onSave: store.setWeeklyBudget,
      doneMessage: 'Presupuesto semanal actualizado',
    );
