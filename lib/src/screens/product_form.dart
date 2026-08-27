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
  late final TextEditingController category;
  late final TextEditingController price;
  late final TextEditingController stock;
  late final TextEditingController minimum;
  final photos = List<Uint8List?>.filled(5, null);
  static const viewNames = [
    'Frente',
    'Atrás',
    'Izquierda',
    'Derecha',
    'Arriba'
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
    category = TextEditingController(text: product?.category);
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
    for (final controller in [
      name,
      sku,
      barcode,
      category,
      price,
      stock,
      minimum,
    ]) {
      controller.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(
        widget.product == null ? 'Nuevo producto' : 'Editar producto',
      ),
      content: SizedBox(
        width: 560,
        child: Form(
          key: formKey,
          child: SingleChildScrollView(
            child: Wrap(
              spacing: 12,
              runSpacing: 14,
              children: [
                SizedBox(
                  width: 548,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Vistas del producto',
                          style: Theme.of(context).textTheme.titleMedium),
                      const SizedBox(height: 4),
                      const Text(
                          'Una foto es suficiente; cinco vistas mejoran la presentación 3D.'),
                      const SizedBox(height: 10),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: List.generate(5, _photoTile),
                      ),
                    ],
                  ),
                ),
                _field(name, 'Nombre', width: 548),
                _field(sku, 'SKU'),
                _field(barcode, 'Código de barras o QR'),
                _field(category, 'Categoría'),
                _field(price, 'Precio', numeric: true),
                _field(stock, 'Existencia inicial', integer: true),
                _field(minimum, 'Stock mínimo', integer: true),
              ],
            ),
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancelar'),
        ),
        FilledButton.icon(
          onPressed: _save,
          icon: const Icon(Icons.save_outlined),
          label: const Text('Guardar'),
        ),
      ],
    );
  }

  Widget _field(
    TextEditingController controller,
    String label, {
    double width = 268,
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

  Future<void> _save() async {
    if (!formKey.currentState!.validate()) return;
    final current = widget.product;
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
    await widget.store.saveProduct(
      Product(
        id: current?.id ?? DateTime.now().microsecondsSinceEpoch.toString(),
        name: name.text.trim(),
        sku: sku.text.trim(),
        category: category.text.trim(),
        price: double.parse(price.text),
        stock: int.parse(stock.text),
        minimumStock: int.parse(minimum.text),
        barcode: barcode.text.trim(),
        photoBase64: photos[0] == null ? '' : base64Encode(photos[0]!),
        imageUrl: current?.imageUrl ?? '',
        imageUrls: current?.imageUrls ?? [],
        pendingImagesBase64: photos
            .map((item) => item == null ? '' : base64Encode(item))
            .toList(),
      ),
    );
    if (mounted) Navigator.pop(context);
  }

  Widget _photoTile(int index) {
    final bytes = photos[index];
    final existing = index < (widget.product?.imageUrls.length ?? 0)
        ? widget.product!.imageUrls[index]
        : index == 0
            ? widget.product?.imageUrl ?? ''
            : '';
    return SizedBox(
      width: 100,
      child: Column(
        children: [
          InkWell(
            borderRadius: BorderRadius.circular(14),
            onTap: () => _chooseSource(index),
            child: Ink(
              height: 86,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(14),
                color: Theme.of(context).colorScheme.surfaceContainerHighest,
                image: bytes != null
                    ? DecorationImage(
                        image: MemoryImage(bytes), fit: BoxFit.cover)
                    : existing.isNotEmpty
                        ? DecorationImage(
                            image: NetworkImage(existing), fit: BoxFit.cover)
                        : null,
              ),
              child: bytes == null && existing.isEmpty
                  ? const Center(child: Icon(Icons.add_a_photo_outlined))
                  : null,
            ),
          ),
          const SizedBox(height: 4),
          Text(viewNames[index], style: Theme.of(context).textTheme.labelSmall),
        ],
      ),
    );
  }

  Future<void> _chooseSource(int index) async {
    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      builder: (context) => SafeArea(
        child: Wrap(children: [
          ListTile(
            leading: const Icon(Icons.camera_alt_outlined),
            title: const Text('Tomar foto'),
            onTap: () => Navigator.pop(context, ImageSource.camera),
          ),
          ListTile(
            leading: const Icon(Icons.photo_library_outlined),
            title: const Text('Elegir de galería'),
            onTap: () => Navigator.pop(context, ImageSource.gallery),
          ),
        ]),
      ),
    );
    if (source != null) await _pickPhoto(source, index);
  }

  Future<void> _pickPhoto(ImageSource source, int index) async {
    final image = await ImagePicker().pickImage(
      source: source,
      maxWidth: 1000,
      imageQuality: 78,
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
    if (mounted) setState(() => photos[index] = bytes);
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
}
