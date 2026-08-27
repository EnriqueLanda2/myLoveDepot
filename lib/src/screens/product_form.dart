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
  late final TextEditingController modelUrl;
  Uint8List? photoBytes;

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
    modelUrl = TextEditingController(text: product?.modelUrl);
    if (product?.photoBase64.isNotEmpty == true) {
      try {
        photoBytes = base64Decode(product!.photoBase64);
      } on FormatException {
        photoBytes = null;
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
      modelUrl,
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
                  child: Row(
                    children: [
                      CircleAvatar(
                        radius: 42,
                        backgroundImage: photoBytes != null
                            ? MemoryImage(photoBytes!)
                            : widget.product?.imageUrl.isNotEmpty == true
                                ? NetworkImage(widget.product!.imageUrl)
                                : null,
                        child: photoBytes == null &&
                                widget.product?.imageUrl.isNotEmpty != true
                            ? const Icon(Icons.photo_camera_outlined, size: 34)
                            : null,
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: [
                            FilledButton.tonalIcon(
                              onPressed: () => _pickPhoto(ImageSource.camera),
                              icon: const Icon(Icons.camera_alt_outlined),
                              label: const Text('Tomar foto'),
                            ),
                            OutlinedButton.icon(
                              onPressed: () => _pickPhoto(ImageSource.gallery),
                              icon: const Icon(Icons.photo_library_outlined),
                              label: const Text('Galería'),
                            ),
                          ],
                        ),
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
                _field(
                  modelUrl,
                  'URL del modelo 3D (.glb/.gltf)',
                  width: 548,
                  required: false,
                ),
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
        photoBase64: photoBytes == null ? '' : base64Encode(photoBytes!),
        imageUrl: current?.imageUrl ?? '',
        modelUrl: modelUrl.text.trim(),
      ),
    );
    if (mounted) Navigator.pop(context);
  }

  Future<void> _pickPhoto(ImageSource source) async {
    final image = await ImagePicker().pickImage(
      source: source,
      maxWidth: 1000,
      imageQuality: 78,
    );
    if (image == null) return;
    final bytes = await image.readAsBytes();
    if (mounted) setState(() => photoBytes = bytes);
  }
}
