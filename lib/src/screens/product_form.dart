import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../inventory_store.dart';
import '../models.dart';

class ProductForm extends StatefulWidget {
  const ProductForm({
    required this.store,
    this.product,
    this.initialBarcode = '',
    super.key,
  });

  final InventoryStore store;
  final Product? product;
  final String initialBarcode;

  @override
  State<ProductForm> createState() => _ProductFormState();
}

class _ProductFormState extends State<ProductForm> {
  final formKey = GlobalKey<FormState>();
  late final TextEditingController name;
  late final TextEditingController sku;
  late final TextEditingController barcode;
  late final TextEditingController price;
  late final TextEditingController stock;
  late final TextEditingController minimum;
  final photos = List<Uint8List?>.filled(5, null);
  String? category;
  int categoryEpoch = 0;
  bool saving = false;
  String? photoError;

  static const viewNames = [
    'Frente',
    'Atrás',
    'Izquierda',
    'Derecha',
    'Arriba'
  ];

  static const viewIcons = [
    Icons.camera_front_rounded,
    Icons.flip_camera_android_rounded,
    Icons.west_rounded,
    Icons.east_rounded,
    Icons.north_rounded,
  ];

  static const viewDescriptions = [
    'Foto frontal principal (Obligatoria)',
    'Vista posterior / espalda del objeto',
    'Vista lateral izquierda del objeto',
    'Vista lateral derecha del objeto',
    'Vista superior (desde arriba)',
  ];

  @override
  void initState() {
    super.initState();
    final product = widget.product;
    name = TextEditingController(text: product?.name);
    sku = TextEditingController(text: product?.sku);
    barcode = TextEditingController(
      text: product?.barcode ?? widget.initialBarcode,
    );
    category = product?.category.trim().isNotEmpty == true
        ? product!.category.trim()
        : null;
    price = TextEditingController(text: product?.price.toStringAsFixed(2));
    stock = TextEditingController(text: product?.stock.toString() ?? '0');
    minimum = TextEditingController(
      text: product?.minimumStock.toString() ?? '5',
    );
    if (product?.photoBase64.isNotEmpty == true) {
      try {
        photos[0] = base64Decode(product!.photoBase64);
      } on FormatException {
        photos[0] = null;
      }
    }
  }

  @override
  void dispose() {
    for (final controller in [name, sku, barcode, price, stock, minimum]) {
      controller.dispose();
    }
    super.dispose();
  }

  int get _capturedCount {
    int count = 0;
    for (int i = 0; i < 5; i++) {
      if (photos[i] != null || _getExistingUrl(i).isNotEmpty) count++;
    }
    return count;
  }

  String _getExistingUrl(int index) {
    if (widget.product == null) return '';
    if (index < widget.product!.imageUrls.length) {
      return widget.product!.imageUrls[index];
    }
    if (index == 0) return widget.product?.imageUrl ?? '';
    return '';
  }

  @override
  Widget build(BuildContext context) {
    const magenta = Color(0xffd94f87);
    final count = _capturedCount;

    return AlertDialog(
      title: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: magenta.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Icon(Icons.view_in_ar_rounded, color: magenta, size: 20),
          ),
          const SizedBox(width: 12),
          Text(
            widget.product == null ? 'NUEVO PRODUCTO' : 'EDITAR PRODUCTO',
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w800,
              letterSpacing: 1.2,
            ),
          ),
        ],
      ),
      content: SizedBox(
        width: 580,
        child: Form(
          key: formKey,
          child: SingleChildScrollView(
            child: Wrap(
              spacing: 12,
              runSpacing: 14,
              children: [
                // ── Sección Guía de Escaneo 3D ────────────────────────────────
                SizedBox(
                  width: 568,
                  child: Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: const Color(0xfffff6fa),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: const Color(0xffe8d0da), width: 1),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            const Icon(Icons.center_focus_strong_rounded,
                                color: magenta, size: 22),
                            const SizedBox(width: 10),
                            const Expanded(
                              child: Text(
                                'GUÍA DE ENCUADRE PARA MODELO 3D',
                                style: TextStyle(
                                  fontWeight: FontWeight.w800,
                                  fontSize: 12,
                                  letterSpacing: 1.2,
                                  color: Color(0xff49343f),
                                ),
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 10, vertical: 4),
                              decoration: BoxDecoration(
                                color: count > 0 ? Colors.green.shade50 : magenta.withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(20),
                                border: Border.all(
                                  color: count > 0 ? Colors.green.shade300 : magenta.withValues(alpha: 0.3),
                                ),
                              ),
                              child: Text(
                                count == 0
                                    ? '1 FOTO MÍNIMA'
                                    : '$count / 5 VISTAS',
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w800,
                                  color: count > 0 ? Colors.green.shade800 : magenta,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),
                        const Text(
                          'Sube al menos la foto frontal (1). Para que los 6 lados del avatar 3D se rendericen con textura perfecta y colores fieles del producto, agrega más ángulos.',
                          style: TextStyle(fontSize: 12, color: Color(0xff7a5c6b), height: 1.3),
                        ),
                        const SizedBox(height: 14),

                        // Mosaico de botones para las 5 fotos
                        Wrap(
                          spacing: 10,
                          runSpacing: 10,
                          children: List.generate(5, _photoTile),
                        ),

                        if (photoError != null) ...[
                          const SizedBox(height: 10),
                          Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: const Color(0xfffff0f0),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: const Color(0xffffccd4)),
                            ),
                            child: Row(
                              children: [
                                const Icon(Icons.error_outline, color: Color(0xffb00020), size: 16),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    photoError!,
                                    style: const TextStyle(color: Color(0xffb00020), fontSize: 12),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),

                // ── Campos de Texto ─────────────────────────────────────────
                _field(name, 'Nombre del producto', width: 568),
                _field(sku, 'SKU / Clave'),
                _field(barcode, 'Código de barras o QR'),
                _categoryField(),
                _field(price, 'Precio (\$)', numeric: true),
                _field(stock, 'Existencia inicial', integer: true),
                _field(minimum, 'Stock mínimo de alerta', integer: true),
              ],
            ),
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('CANCELAR'),
        ),
        FilledButton.icon(
          onPressed: saving ? null : _save,
          icon: saving
              ? const SizedBox.square(
                  dimension: 18,
                  child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                )
              : const Icon(Icons.view_in_ar_rounded, size: 18),
          label: Text(
            saving ? 'GENERANDO AVATAR 3D…' : 'GUARDAR Y CREAR AVATAR 3D',
            style: const TextStyle(fontWeight: FontWeight.w800, letterSpacing: 1.1),
          ),
        ),
      ],
    );
  }

  Widget _categoryField() {
    const newCategory = '__nueva__';
    final names = widget.store.categoryNames;
    final options = <String>{
      ...names,
      if (category != null && category!.isNotEmpty) category!,
    }.toList()
      ..sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));

    return SizedBox(
      width: 278,
      child: DropdownButtonFormField<String>(
        key: ValueKey('$categoryEpoch-$category'),
        initialValue: category,
        isExpanded: true,
        decoration: const InputDecoration(labelText: 'Categoría'),
        items: [
          ...options.map(
            (item) => DropdownMenuItem(
              value: item,
              child: Text(item, overflow: TextOverflow.ellipsis),
            ),
          ),
          const DropdownMenuItem(
            value: newCategory,
            child: Row(children: [
              Icon(Icons.add, size: 18),
              SizedBox(width: 8),
              Text('Registrar categoría'),
            ]),
          ),
        ],
        onChanged: (value) async {
          if (value == newCategory) {
            final created = await _registerCategory();
            if (mounted) {
              setState(() {
                category = created ?? category;
                categoryEpoch++;
              });
            }
            return;
          }
          setState(() => category = value);
        },
        validator: (value) =>
            value == null || value.isEmpty ? 'Elige una categoría' : null,
      ),
    );
  }

  Future<String?> _registerCategory() async {
    final controller = TextEditingController();
    String? error;
    try {
      return await showDialog<String>(
        context: context,
        builder: (dialogContext) => StatefulBuilder(
          builder: (dialogContext, setDialogState) => AlertDialog(
            title: const Text('NUEVA CATEGORÍA'),
            content: TextField(
              controller: controller,
              autofocus: true,
              textCapitalization: TextCapitalization.sentences,
              decoration: InputDecoration(
                labelText: 'Nombre',
                errorText: error,
              ),
              onSubmitted: (_) => Navigator.pop(dialogContext, controller.text),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogContext),
                child: const Text('CANCELAR'),
              ),
              FilledButton(
                onPressed: () async {
                  final name = controller.text.trim();
                  final failure = await widget.store.saveCategory(name);
                  if (failure != null) {
                    setDialogState(() => error = failure);
                    return;
                  }
                  if (dialogContext.mounted) {
                    Navigator.pop(dialogContext, name);
                  }
                },
                child: const Text('REGISTRAR'),
              ),
            ],
          ),
        ),
      );
    } finally {
      controller.dispose();
    }
  }

  Widget _field(
    TextEditingController controller,
    String label, {
    double width = 278,
    bool numeric = false,
    bool integer = false,
    bool required = true,
  }) {
    return SizedBox(
      width: width,
      child: TextFormField(
        controller: controller,
        decoration: InputDecoration(labelText: label),
        keyboardType: numeric
            ? const TextInputType.numberWithOptions(decimal: true)
            : integer
                ? TextInputType.number
                : TextInputType.text,
        validator: (value) {
          if (required && (value == null || value.trim().isEmpty)) {
            return 'Campo obligatorio';
          }
          if (!required && (value == null || value.trim().isEmpty)) return null;
          if (numeric && (double.tryParse(value!) ?? -1) < 0) {
            return 'Escribe un número válido';
          }
          if (integer && (int.tryParse(value!) ?? -1) < 0) {
            return 'Escribe un número entero válido';
          }
          return null;
        },
      ),
    );
  }

  Widget _photoTile(int index) {
    const magenta = Color(0xffd94f87);
    final bytes = photos[index];
    final existing = _getExistingUrl(index);
    final hasPhoto = bytes != null || existing.isNotEmpty;

    return SizedBox(
      width: 100,
      child: Column(
        children: [
          InkWell(
            borderRadius: BorderRadius.circular(12),
            onTap: () => _openCameraGuide(index),
            child: Container(
              height: 90,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                color: hasPhoto ? Colors.white : const Color(0xfffff8fa),
                border: Border.all(
                  color: hasPhoto
                      ? magenta
                      : (index == 0 ? magenta.withValues(alpha: 0.5) : const Color(0xffe8d0da)),
                  width: hasPhoto ? 2 : 1,
                ),
                image: bytes != null
                    ? DecorationImage(image: MemoryImage(bytes), fit: BoxFit.cover)
                    : existing.isNotEmpty
                        ? DecorationImage(image: NetworkImage(existing), fit: BoxFit.cover)
                        : null,
              ),
              child: Stack(
                children: [
                  if (!hasPhoto)
                    Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(viewIcons[index],
                              color: index == 0 ? magenta : const Color(0xff7a5c6b), size: 26),
                          const SizedBox(height: 4),
                          Text(
                            viewNames[index],
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                              color: index == 0 ? magenta : const Color(0xff7a5c6b),
                            ),
                          ),
                        ],
                      ),
                    ),
                  if (hasPhoto)
                    Positioned(
                      top: 4,
                      right: 4,
                      child: Container(
                        padding: const EdgeInsets.all(3),
                        decoration: const BoxDecoration(
                          color: magenta,
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.check, color: Colors.white, size: 12),
                      ),
                    ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            index == 0 ? '1. Frente (*)' : '${index + 1}. ${viewNames[index]}',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 10,
              fontWeight: index == 0 ? FontWeight.w800 : FontWeight.w600,
              color: index == 0 ? magenta : const Color(0xff7a5c6b),
            ),
          ),
        ],
      ),
    );
  }

  /// Abre la ventana de asistencia con Marco de Encuadre Interactivo
  Future<void> _openCameraGuide(int index) async {
    const magenta = Color(0xffd94f87);

    final source = await showDialog<ImageSource>(
      context: context,
      builder: (dialogContext) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        child: Container(
          width: 480,
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Header
              Row(
                children: [
                  Icon(viewIcons[index], color: magenta, size: 28),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'VISTA ${index + 1}: ${viewNames[index].toUpperCase()}',
                          style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 1.2,
                            color: Color(0xff49343f),
                          ),
                        ),
                        Text(
                          viewDescriptions[index],
                          style: const TextStyle(fontSize: 11, color: Color(0xff7a5c6b)),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.pop(dialogContext),
                    icon: const Icon(Icons.close),
                  ),
                ],
              ),

              const SizedBox(height: 16),

              // Marco de encuadre visual interactivo
              Container(
                height: 220,
                width: double.infinity,
                decoration: BoxDecoration(
                  color: const Color(0xfffaf5f7),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: magenta.withValues(alpha: 0.3), width: 1.5),
                ),
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    // Grid / retícula de referencia
                    CustomPaint(
                      size: const Size(double.infinity, 220),
                      painter: _FramingGridPainter(color: magenta),
                    ),

                    // Icono de silueta orientativa
                    Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(viewIcons[index], size: 54, color: magenta.withValues(alpha: 0.35)),
                        const SizedBox(height: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(12),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.06),
                                blurRadius: 8,
                              )
                            ],
                          ),
                          child: Text(
                            'CENTRA EL PRODUCTO AQUÍ',
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w800,
                              color: magenta.withValues(alpha: 0.9),
                              letterSpacing: 1.0,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 16),

              // Tips rápidos
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xfffff6fa),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Column(
                  children: [
                    _TipItem(icon: Icons.wb_sunny_outlined, text: 'Usa buena iluminación pareja sin sombras oscuras.'),
                    SizedBox(height: 4),
                    _TipItem(icon: Icons.crop_square_rounded, text: 'Fondo liso que contraste con el producto.'),
                    SizedBox(height: 4),
                    _TipItem(icon: Icons.fit_screen_rounded, text: 'No cortes bordes ni hagas zoom excesivo.'),
                  ],
                ),
              ),

              const SizedBox(height: 20),

              // Botones de acción
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () => Navigator.pop(dialogContext, ImageSource.gallery),
                      icon: const Icon(Icons.photo_library_outlined, size: 18),
                      label: const Text('GALERÍA'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: FilledButton.icon(
                      onPressed: () => Navigator.pop(dialogContext, ImageSource.camera),
                      icon: const Icon(Icons.camera_alt_rounded, size: 18),
                      label: const Text('TOMAR FOTO'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );

    if (source != null) {
      await _pickPhoto(source, index);
    }
  }

  Future<void> _pickPhoto(ImageSource source, int index) async {
    final image = await ImagePicker().pickImage(
      source: source,
      maxWidth: 1000,
      imageQuality: 85,
    );
    if (image == null) return;
    final bytes = await image.readAsBytes();
    if (bytes.length > 8 * 1024 * 1024 || !_looksLikeImage(bytes)) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text(
              'Selecciona una imagen JPEG, PNG o WebP válida de máximo 8 MB.'),
        ));
      }
      return;
    }
    if (mounted) {
      setState(() {
        photos[index] = bytes;
        photoError = null;
      });
    }
  }

  bool _looksLikeImage(Uint8List bytes) {
    if (bytes.length < 12) return false;
    final jpeg = bytes[0] == 0xff && bytes[1] == 0xd8 && bytes[2] == 0xff;
    final png = bytes[0] == 0x89 &&
        bytes[1] == 0x50 &&
        bytes[2] == 0x4e &&
        bytes[3] == 0x47;
    final webp = String.fromCharCodes(bytes.sublist(0, 4)) == 'RIFF' &&
        String.fromCharCodes(bytes.sublist(8, 12)) == 'WEBP';
    return jpeg || png || webp;
  }

  Future<void> _save() async {
    if (!formKey.currentState!.validate()) return;
    final current = widget.product;
    final hasFrontPhoto = photos[0] != null ||
        (current?.imageUrls.isNotEmpty == true) ||
        (current?.imageUrl.isNotEmpty == true);
    if (!hasFrontPhoto) {
      setState(() => photoError =
          'Toma primero la foto frontal siguiendo las indicaciones.');
      return;
    }
    if (widget.store.barcodeBelongsToAnotherProduct(
      barcode.text,
      current?.id,
    )) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Este código ya pertenece a otro producto.'),
        ),
      );
      return;
    }
    setState(() {
      saving = true;
      photoError = null;
    });
    final failure = await widget.store.saveProduct(
      Product(
        id: current?.id ?? DateTime.now().microsecondsSinceEpoch.toString(),
        name: name.text.trim(),
        sku: sku.text.trim(),
        category: category!.trim(),
        price: double.parse(price.text),
        stock: int.parse(stock.text),
        minimumStock: int.parse(minimum.text),
        barcode: barcode.text.trim(),
        photoBase64: photos[0] == null ? '' : base64Encode(photos[0]!),
        imageUrl: current?.imageUrl ?? '',
        modelUrl: current?.modelUrl ?? '',
        imageUrls: current?.imageUrls ?? [],
        pendingImagesBase64: photos
            .map((item) => item == null ? '' : base64Encode(item))
            .toList(),
      ),
    );
    if (!mounted) return;
    setState(() => saving = false);
    if (failure != null) {
      setState(() => photoError = failure);
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(failure)));
      return;
    }
    Navigator.pop(context);
  }
}

class _TipItem extends StatelessWidget {
  const _TipItem({required this.icon, required this.text});
  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 14, color: const Color(0xffd94f87)),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            text,
            style: const TextStyle(fontSize: 11, color: Color(0xff49343f)),
          ),
        ),
      ],
    );
  }
}

/// Pintor personalizado para el marco de encuadre con retícula y esquinas de enfoque
class _FramingGridPainter extends CustomPainter {
  const _FramingGridPainter({required this.color});
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final borderPaint = Paint()
      ..color = color.withValues(alpha: 0.4)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;

    final cornerPaint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3.0;

    // Caja central de encuadre (margen 16%)
    final marginX = size.width * 0.16;
    final marginY = size.height * 0.12;
    final rect = Rect.fromLTRB(marginX, marginY, size.width - marginX, size.height - marginY);

    // Dibujar borde rectangular suave
    canvas.drawRRect(RRect.fromRectAndRadius(rect, const Radius.circular(12)), borderPaint);

    // Esquinas reforzadas (crosshairs de cámara)
    const cornerLength = 18.0;
    // Top-left
    canvas.drawLine(Offset(rect.left, rect.top), Offset(rect.left + cornerLength, rect.top), cornerPaint);
    canvas.drawLine(Offset(rect.left, rect.top), Offset(rect.left, rect.top + cornerLength), cornerPaint);

    // Top-right
    canvas.drawLine(Offset(rect.right, rect.top), Offset(rect.right - cornerLength, rect.top), cornerPaint);
    canvas.drawLine(Offset(rect.right, rect.top), Offset(rect.right, rect.top + cornerLength), cornerPaint);

    // Bottom-left
    canvas.drawLine(Offset(rect.left, rect.bottom), Offset(rect.left + cornerLength, rect.bottom), cornerPaint);
    canvas.drawLine(Offset(rect.left, rect.bottom), Offset(rect.left, rect.bottom - cornerLength), cornerPaint);

    // Bottom-right
    canvas.drawLine(Offset(rect.right, rect.bottom), Offset(rect.right - cornerLength, rect.bottom), cornerPaint);
    canvas.drawLine(Offset(rect.right, rect.bottom), Offset(rect.right, rect.bottom - cornerLength), cornerPaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
