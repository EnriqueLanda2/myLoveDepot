import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../inventory_store.dart';
import '../models.dart';
import '../ui/components.dart';
import '../ui/tokens.dart';

/// Registrar una entrada o salida de inventario.
Future<void> showMovementModal(
  BuildContext context,
  InventoryStore store,
  Product product, {
  MovementType type = MovementType.outgoing,
}) {
  return showAppModal<void>(
    context,
    builder: (_) => _MovementModal(
      store: store,
      product: product,
      initialType: product.isOutOfStock ? MovementType.incoming : type,
      toastContext: context,
    ),
  );
}

class _MovementModal extends StatefulWidget {
  const _MovementModal({
    required this.store,
    required this.product,
    required this.initialType,
    required this.toastContext,
  });

  final InventoryStore store;
  final Product product;
  final MovementType initialType;
  final BuildContext toastContext;

  @override
  State<_MovementModal> createState() => _MovementModalState();
}

class _MovementModalState extends State<_MovementModal> {
  late MovementType type = widget.initialType;
  final quantity = TextEditingController(text: '1');
  final note = TextEditingController();
  bool saving = false;
  String? error;

  Product get product => widget.product;
  bool get isOut => type == MovementType.outgoing;
  int get qty => int.tryParse(quantity.text) ?? 0;
  int get after => product.stock + (isOut ? -qty : qty);
  bool get valid => qty > 0 && (!isOut || qty <= product.stock);

  @override
  void dispose() {
    quantity.dispose();
    note.dispose();
    super.dispose();
  }

  void _setQty(int value) {
    final max = isOut ? product.stock : 99999;
    final clamped = value.clamp(1, max < 1 ? 1 : max);
    quantity.text = '$clamped';
    quantity.selection = TextSelection.collapsed(offset: quantity.text.length);
    setState(() => error = null);
  }

  Future<void> _save() async {
    if (!valid) {
      setState(() => error = isOut && qty > product.stock
          ? 'Solo hay ${product.stock} en existencia.'
          : 'Escribe una cantidad mayor que cero.');
      return;
    }
    setState(() => saving = true);
    final failure = await widget.store.moveStock(
      product: product,
      type: type,
      quantity: qty,
      note: note.text.trim().isEmpty
          ? (isOut ? 'Venta' : 'Reabastecimiento')
          : note.text.trim(),
    );
    if (!mounted || !widget.toastContext.mounted) return;
    if (failure != null) {
      setState(() {
        saving = false;
        error = failure;
      });
      return;
    }
    Navigator.pop(context);
    AppToast.show(
      widget.toastContext,
      '${isOut ? 'Salida' : 'Entrada'} registrada · ${product.name}',
    );
  }

  @override
  Widget build(BuildContext context) {
    final subtitle = [
      if (product.shade.isNotEmpty) product.shade,
      '${product.stock} en existencia',
    ].join(' · ');
    return ModalBody(
      title: product.name,
      subtitle: subtitle,
      body: [
        AppSegmented<MovementType>(
          expand: true,
          bordered: false,
          background: AppColors.background,
          selected: type,
          onChanged: (value) {
            setState(() {
              type = value;
              error = null;
            });
            if (value == MovementType.outgoing && qty > product.stock) {
              _setQty(product.stock);
            }
          },
          options: [
            const AppSegment(
              value: MovementType.incoming,
              label: 'Entrada',
              selectedColor: AppColors.success,
            ),
            AppSegment(
              value: MovementType.outgoing,
              label: 'Salida',
              selectedColor: AppColors.primaryText,
              enabled: !product.isOutOfStock,
              tooltip:
                  product.isOutOfStock ? 'Sin existencias para vender' : null,
            ),
          ],
        ),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            AppIconButton(
              icon: Icons.remove_rounded,
              tooltip: 'Menos',
              size: 48,
              color: AppColors.text,
              borderColor: AppColors.border,
              onPressed: qty > 1 ? () => _setQty(qty - 1) : null,
            ),
            SizedBox(
              width: 120,
              child: TextField(
                controller: quantity,
                textAlign: TextAlign.center,
                keyboardType: TextInputType.number,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                onChanged: (_) => setState(() => error = null),
                style: appText(size: 40, weight: FontWeight.w700),
                decoration: const InputDecoration(
                  border: InputBorder.none,
                  enabledBorder: InputBorder.none,
                  focusedBorder: InputBorder.none,
                  filled: false,
                  isDense: true,
                ),
              ),
            ),
            AppIconButton(
              icon: Icons.add_rounded,
              tooltip: 'Más',
              size: 48,
              color: AppColors.text,
              borderColor: AppColors.border,
              onPressed:
                  isOut && qty >= product.stock ? null : () => _setQty(qty + 1),
            ),
          ],
        ),
        _InfoRow(
          label: 'Stock resultante',
          value: '$after',
          background: after < 0 ? AppColors.errorSoft : AppColors.background,
          color: after < 0 ? AppColors.error : AppColors.text,
        ),
        if (isOut)
          _InfoRow(
            label: 'Ganancia de esta venta',
            value: money(product.unitProfit * (qty > 0 ? qty : 0)),
            background: AppColors.successSoft,
            color: AppColors.success,
            hint: product.cost <= 0
                ? 'Registra el costo del producto para una ganancia real.'
                : null,
          ),
        TextField(
          controller: note,
          onSubmitted: (_) => _save(),
          style: appText(size: 14),
          decoration: appInputDecoration(
            hint: isOut
                ? 'Nota (opcional) · ej. Venta a clienta'
                : 'Nota (opcional) · ej. Pedido proveedor',
          ),
        ),
        if (error != null)
          Text(error!, style: appText(size: 13, color: AppColors.error)),
      ],
      actions: [
        AppButton(
          label: 'Cancelar',
          variant: AppButtonVariant.secondary,
          onPressed: () => Navigator.pop(context),
        ),
        AppButton(
          label: isOut ? 'Registrar salida' : 'Registrar entrada',
          variant: isOut ? AppButtonVariant.primary : AppButtonVariant.success,
          onPressed: saving || !valid ? null : _save,
        ),
      ],
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({
    required this.label,
    required this.value,
    required this.background,
    required this.color,
    this.hint,
  });

  final String label;
  final String value;
  final Color background;
  final Color color;
  final String? hint;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  label,
                  style: appText(
                    size: 14,
                    color: color == AppColors.text
                        ? AppColors.textSecondary
                        : color,
                  ),
                ),
              ),
              Text(value,
                  style:
                      appText(size: 14, weight: FontWeight.w700, color: color)),
            ],
          ),
          if (hint != null) ...[
            const SizedBox(height: 4),
            Text(hint!,
                style: appText(size: 12, color: color.withValues(alpha: 0.8))),
          ],
        ],
      ),
    );
  }
}
