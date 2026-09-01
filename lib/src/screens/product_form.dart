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
                      Text('Escanea el producto para crear su avatar 3D',
                          style: Theme.of(context).textTheme.titleMedium),
                      const SizedBox(height: 8),
                      Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color:
                              Theme.of(context).colorScheme.secondaryContainer,
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: const Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Icon(Icons.center_focus_strong_rounded),
                            SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                'La foto frontal es obligatoria. Pon el producto completo y centrado sobre un fondo liso que contraste, usa buena luz y mantén la cámara firme. No uses zoom ni cortes los bordes.',
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        'Con una foto se crea una aproximación giratoria. Agrega más vistas para que la forma sea más fiel.',
                      ),
                      const SizedBox(height: 10),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: List.generate(5, _photoTile),
                      ),
                      if (photoError != null) ...[
                        const SizedBox(height: 8),
                        Text(photoError!,
                            style: TextStyle(
                                color: Theme.of(context).colorScheme.error)),
                      ],
                    ],
                  ),
                ),
                _field(name, 'Nombre', width: 548),
                _field(sku, 'SKU'),
                _field(barcode, 'Código de barras o QR'),
                _categoryField(),
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
          onPressed: saving ? null : _save,
          icon: saving
              ? const SizedBox.square(
                  dimension: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.view_in_ar_outlined),
          label:
              Text(saving ? 'Creando avatar 3D…' : 'Guardar y crear avatar 3D'),
        ),
      ],
    );
  }

  /// Desplegable con las categorías registradas más un atajo para dar de alta
  /// una nueva sin salir del formulario.
  Widget _categoryField() {
    const newCategory = '__nueva__';
    final names = widget.store.categoryNames;
    final options = <String>{
      ...names,
      if (category != null && category!.isNotEmpty) category!,
    }.toList()
      ..sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));

    return SizedBox(
      width: 268,
      child: DropdownButtonFormField<String>(
        // El FormField guarda su propio valor, así que se recrea en cada cambio
        // para que nunca se quede mostrando el atajo "Registrar categoría".
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
            title: const Text('Nueva categoría'),
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
                child: const Text('Cancelar'),
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
                child: const Text('Registrar'),
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
          Text(
              index == 0
                  ? '${viewNames[index]} · obligatoria'
                  : viewNames[index],
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.labelSmall),
        ],
      ),
    );
  }

  Future<void> _chooseSource(int index) async {
    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      builder: (context) => SafeArea(
        child: Wrap(children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 18, 20, 8),
            child: Text(
              index == 0
                  ? 'Escaneo frontal obligatorio'
                  : 'Vista ${viewNames[index]}',
              style: Theme.of(context).textTheme.titleMedium,
            ),
          ),
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 20, vertical: 6),
            child: Text(
                'Fondo liso y contrastante · producto completo · buena luz · cámara firme'),
          ),
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
