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

// Paleta
class _C {
  static const magenta = Color(0xffd94f87);
  static const magentaDeep = Color(0xffb5296b);
  static const green = Color(0xff16a34a);
  static const textPrimary = Color(0xff3a2633);
  static const textSecondary = Color(0xff7a5c6b);
  static const stroke = Color(0xffe8d0da);
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

  int get _parsedQty => int.tryParse(quantity.text) ?? 0;
  bool get _isIncoming => type == MovementType.incoming;

  int get _projectedStock {
    final qty = _parsedQty;
    if (_isIncoming) return widget.product.stock + qty;
    return widget.product.stock - qty;
  }

  @override
  Widget build(BuildContext context) {
    final color = _isIncoming ? _C.green : _C.magenta;

    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      title: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              _isIncoming ? Icons.south_west_rounded : Icons.north_east_rounded,
              color: color,
              size: 22,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.product.name,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                    color: _C.textPrimary,
                  ),
                ),
                const SizedBox(height: 2),
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: color.withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        'Stock actual: ${widget.product.stock}',
                        style: TextStyle(
                          color: color,
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
        ],
      ),
      content: SizedBox(
        width: 440,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const SizedBox(height: 8),

            // Type selector
            if (!widget.incomingOnly)
              Container(
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  color: const Color(0xfffff6fa),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: _C.stroke.withValues(alpha: 0.5)),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: _TypeButton(
                        label: 'ENTRADA',
                        icon: Icons.add_rounded,
                        color: _C.green,
                        selected: _isIncoming,
                        onTap: () => setState(() => type = MovementType.incoming),
                      ),
                    ),
                    const SizedBox(width: 4),
                    Expanded(
                      child: _TypeButton(
                        label: 'SALIDA',
                        icon: Icons.remove_rounded,
                        color: _C.magenta,
                        selected: !_isIncoming,
                        onTap: () => setState(() => type = MovementType.outgoing),
                      ),
                    ),
                  ],
                ),
              ),

            const SizedBox(height: 20),

            // Quantity field with +/- buttons
            Row(
              children: [
                // Minus button
                _QtyBtn(
                  icon: Icons.remove_rounded,
                  onTap: () {
                    final current = _parsedQty;
                    if (current > 1) {
                      setState(() => quantity.text = '${current - 1}');
                    }
                  },
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextField(
                    controller: quantity,
                    autofocus: true,
                    keyboardType: TextInputType.number,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w900,
                      color: _C.textPrimary,
                    ),
                    onChanged: (_) => setState(() {}),
                    decoration: InputDecoration(
                      labelText: 'Cantidad',
                      errorText: error,
                      labelStyle: const TextStyle(fontSize: 13),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                        borderSide: BorderSide(color: _C.stroke),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                        borderSide: BorderSide(color: color, width: 1.5),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                // Plus button
                _QtyBtn(
                  icon: Icons.add_rounded,
                  onTap: () {
                    final current = _parsedQty;
                    setState(() => quantity.text = '${current + 1}');
                  },
                ),
              ],
            ),

            const SizedBox(height: 14),

            // Projected stock preview
            if (_parsedQty > 0)
              AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.06),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: color.withValues(alpha: 0.15)),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      '${widget.product.stock}',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                        color: _C.textSecondary,
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 10),
                      child: Icon(
                        Icons.arrow_forward_rounded,
                        size: 18,
                        color: color,
                      ),
                    ),
                    Text(
                      '$_projectedStock',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w900,
                        color: color,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      '(${_isIncoming ? '+' : '-'}$_parsedQty)',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: color.withValues(alpha: 0.7),
                      ),
                    ),
                  ],
                ),
              ),

            const SizedBox(height: 14),

            TextField(
              controller: note,
              decoration: InputDecoration(
                labelText: 'Nota (opcional)',
                hintText: 'Compra, venta, ajuste…',
                prefixIcon: Icon(Icons.note_alt_outlined, size: 18, color: _C.textSecondary),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('CANCELAR'),
        ),
        Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            gradient: LinearGradient(
              colors: _isIncoming
                  ? [_C.green, const Color(0xff15803d)]
                  : [_C.magenta, _C.magentaDeep],
            ),
            boxShadow: [
              BoxShadow(
                color: color.withValues(alpha: 0.3),
                blurRadius: 8,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: FilledButton.icon(
            onPressed: _save,
            icon: Icon(
              _isIncoming ? Icons.south_west_rounded : Icons.north_east_rounded,
              size: 16,
            ),
            label: Text(
              'REGISTRAR ${_isIncoming ? 'ENTRADA' : 'SALIDA'}',
              style: const TextStyle(
                fontWeight: FontWeight.w800,
                letterSpacing: 0.8,
                fontSize: 12,
              ),
            ),
            style: FilledButton.styleFrom(
              backgroundColor: Colors.transparent,
              foregroundColor: Colors.white,
              shadowColor: Colors.transparent,
            ),
          ),
        ),
      ],
    );
  }

  Future<void> _save() async {
    final parsed = int.tryParse(quantity.text);
    if (parsed == null || parsed <= 0) {
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

// ── Type Button ────────────────────────────────────────────────────────────────
class _TypeButton extends StatelessWidget {
  const _TypeButton({
    required this.label,
    required this.icon,
    required this.color,
    required this.selected,
    required this.onTap,
  });
  final String label;
  final IconData icon;
  final Color color;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: selected ? color.withValues(alpha: 0.12) : Colors.transparent,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: selected ? color : Colors.transparent,
            width: 1.5,
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 16, color: selected ? color : _C.textSecondary),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                fontWeight: FontWeight.w800,
                fontSize: 12,
                letterSpacing: 1,
                color: selected ? color : _C.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Qty +/- Button ─────────────────────────────────────────────────────────────
class _QtyBtn extends StatelessWidget {
  const _QtyBtn({required this.icon, required this.onTap});
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: const Color(0xfffff6fa),
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: _C.stroke),
          ),
          child: Icon(icon, color: _C.magenta, size: 22),
        ),
      ),
    );
  }
}
