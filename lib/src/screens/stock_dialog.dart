import 'package:flutter/material.dart';

import '../inventory_store.dart';
import '../models.dart';

Future<void> showStockDialog(
  BuildContext context,
  InventoryStore store,
  Product product, {
  bool incomingOnly = false,
  int? initialQuantity,
}) async {
  await showDialog<void>(
    context: context,
    builder: (_) => _StockDialog(
      store: store,
      product: product,
      incomingOnly: incomingOnly,
      initialQuantity: initialQuantity,
    ),
  );
}

class _StockDialog extends StatefulWidget {
  const _StockDialog(
      {required this.store,
      required this.product,
      required this.incomingOnly,
      this.initialQuantity});

  final InventoryStore store;
  final Product product;
  final bool incomingOnly;
  final int? initialQuantity;

  @override
  State<_StockDialog> createState() => _StockDialogState();
}

class _StockDialogState extends State<_StockDialog> {
  MovementType type = MovementType.incoming;
  final quantity = TextEditingController();
  final note = TextEditingController();
  String? error;

  @override
  void initState() {
    super.initState();
    if (widget.initialQuantity != null) {
      quantity.text = '${widget.initialQuantity}';
    }
  }

  @override
  void dispose() {
    quantity.dispose();
    note.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.product.name),
      content: SizedBox(
        width: 430,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('Existencia actual: ${widget.product.stock}'),
            const SizedBox(height: 16),
            if (!widget.incomingOnly)
              SegmentedButton<MovementType>(
                segments: const [
                  ButtonSegment(
                    value: MovementType.incoming,
                    icon: Icon(Icons.add),
                    label: Text('Entrada'),
                  ),
                  ButtonSegment(
                    value: MovementType.outgoing,
                    icon: Icon(Icons.remove),
                    label: Text('Salida'),
                  ),
                ],
                selected: {type},
                onSelectionChanged: (value) =>
                    setState(() => type = value.first),
              ),
            const SizedBox(height: 16),
            TextField(
              controller: quantity,
              autofocus: true,
              keyboardType: TextInputType.number,
              decoration: InputDecoration(
                labelText: 'Cantidad',
                errorText: error,
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: note,
              decoration: const InputDecoration(
                labelText: 'Nota (opcional)',
                hintText: 'Compra, venta, ajuste…',
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancelar'),
        ),
        FilledButton(onPressed: _save, child: const Text('Registrar')),
      ],
    );
  }

  Future<void> _save() async {
    final parsed = int.tryParse(quantity.text);
    if (parsed == null) {
      setState(() => error = 'Escribe una cantidad válida');
      return;
    }
    final result = await widget.store.moveStock(
      product: widget.product,
      type: type,
      quantity: parsed,
      note: note.text.trim(),
    );
    if (result != null) {
      setState(() => error = result);
    } else if (mounted) {
      Navigator.pop(context);
    }
  }
}
