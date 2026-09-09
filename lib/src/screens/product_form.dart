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
  late final TextEditingController originalPrice;
  late final TextEditingController wholesalePrice;
  late final TextEditingController stock;
  late final TextEditingController minimum;

  // Media
  Uint8List? mediaBytes;
  bool isVideo = false;
  String existingUrl = '';
  String? category;
  int categoryEpoch = 0;
  bool saving = false;
  String? mediaError;

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
    price = TextEditingController(
        text: product != null ? product.price.toStringAsFixed(2) : '');
    originalPrice = TextEditingController(
        text: product?.originalPrice != null
            ? product!.originalPrice!.toStringAsFixed(2)
            : '');
    wholesalePrice = TextEditingController(
        text: product?.wholesalePrice != null
            ? product!.wholesalePrice!.toStringAsFixed(2)
            : '');
    stock = TextEditingController(text: product?.stock.toString() ?? '1');
    minimum = TextEditingController(
      text: product?.minimumStock.toString() ?? '2',
    );

    if (product != null) {
      existingUrl = product.imageUrl;
      isVideo = product.isVideo;
      if (product.photoBase64.isNotEmpty) {
        try {
          mediaBytes = base64Decode(product.photoBase64);
        } on FormatException {
          mediaBytes = null;
        }
      }
    }
  }

  @override
  void dispose() {
    for (final controller in [
      name,
      sku,
      barcode,
      price,
      originalPrice,
      wholesalePrice,
      stock,
      minimum
    ]) {
      controller.dispose();
    }
    super.dispose();
  }

  /// Validación minuciosa de seguridad de archivos en el cliente
  String? _validateMediaBytes(Uint8List bytes, bool videoExpected) {
    if (bytes.length < 16) {
      return 'El archivo seleccionado está vacío o dañado.';
    }

    // Límite de tamaño: 8 MB para foto, 25 MB para video
    final maxSize = videoExpected ? 25 * 1024 * 1024 : 8 * 1024 * 1024;
    if (bytes.length > maxSize) {
      return videoExpected
          ? 'El video excede el límite máximo permitido de 25 MB.'
          : 'La imagen excede el límite máximo permitido de 8 MB.';
    }

    // 1. Detección de binarios ejecutables o cabeceras peligrosas
    // Cabecera DOS PE 'MZ'
    if (bytes[0] == 0x4d && bytes[1] == 0x5a) {
      return 'Archivo no permitido: contiene firma de ejecutable DOS/Windows.';
    }
    // Cabecera Linux ELF
    if (bytes.length >= 4 &&
        bytes[0] == 0x7f &&
        bytes[1] == 0x45 &&
        bytes[2] == 0x4c &&
        bytes[3] == 0x46) {
      return 'Archivo no permitido: contiene firma de ejecutable Linux ELF.';
    }

    // 2. Escaneo de scripts inyectados / código malicioso en texto
    final inspectLength = bytes.length > 32768 ? 32768 : bytes.length;
    final snippet = String.fromCharCodes(bytes.sublist(0, inspectLength)).toLowerCase();
    const forbidden = [
      '<script',
      '</script>',
      '<?php',
      '<?=',
      '<%',
      '<svg',
      '<iframe',
      '<object',
      'eval(',
      'base64_decode(',
      '#!/bin/',
      'powershell',
      'cmd.exe',
    ];
    for (final bad in forbidden) {
      if (snippet.contains(bad)) {
        return 'Archivo bloqueado por seguridad: contiene código o script no permitido.';
      }
    }

    // 3. Verificación de Magic Bytes
    if (videoExpected) {
      // MP4 / MOV: 'ftyp', 'moov', 'mdat' at offset 4
      bool isMp4 = false;
      if (bytes.length >= 12) {
        final box = String.fromCharCodes(bytes.sublist(4, 8));
        isMp4 = box == 'ftyp' || box == 'moov' || box == 'mdat' || box == 'wide';
      }
      // WebM: 1A 45 DF A3
      final isWebm = bytes[0] == 0x1a &&
          bytes[1] == 0x45 &&
          bytes[2] == 0xdf &&
          bytes[3] == 0xa3;

      if (!isMp4 && !isWebm) {
        return 'El archivo no es un video MP4, MOV o WebM válido.';
      }
    } else {
      // Imagen: JPEG, PNG, WebP, GIF
      final isJpeg = bytes[0] == 0xff && bytes[1] == 0xd8 && bytes[2] == 0xff;
      final isPng = bytes.length >= 8 &&
          bytes[0] == 0x89 &&
          bytes[1] == 0x50 &&
          bytes[2] == 0x4e &&
          bytes[3] == 0x47;
      final isWebp = bytes.length >= 12 &&
          String.fromCharCodes(bytes.sublist(0, 4)) == 'RIFF' &&
          String.fromCharCodes(bytes.sublist(8, 12)) == 'WEBP';
      final isGif = bytes.length >= 6 &&
          (String.fromCharCodes(bytes.sublist(0, 6)) == 'GIF87a' ||
              String.fromCharCodes(bytes.sublist(0, 6)) == 'GIF89a');

      if (!isJpeg && !isPng && !isWebp && !isGif) {
        return 'El archivo no es una imagen JPEG, PNG, WebP o GIF válida.';
      }
    }

    return null;
  }

  Future<void> _pickImage(ImageSource source) async {
    try {
      final picker = ImagePicker();
      final picked = await picker.pickImage(
        source: source,
        maxWidth: 1800,
        maxHeight: 1800,
        imageQuality: 90,
      );
      if (picked == null) return;

      final bytes = await picked.readAsBytes();
      final error = _validateMediaBytes(bytes, false);
      if (error != null) {
        setState(() => mediaError = error);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(error), backgroundColor: const Color(0xffb00020)),
          );
        }
        return;
      }

      setState(() {
        mediaBytes = bytes;
        isVideo = false;
        existingUrl = '';
        mediaError = null;
      });
    } catch (e) {
      setState(() => mediaError = 'Error al leer la imagen: $e');
    }
  }

  Future<void> _pickVideo(ImageSource source) async {
    try {
      final picker = ImagePicker();
      final picked = await picker.pickVideo(
        source: source,
        maxDuration: const Duration(minutes: 2),
      );
      if (picked == null) return;

      final bytes = await picked.readAsBytes();
      final error = _validateMediaBytes(bytes, true);
      if (error != null) {
        setState(() => mediaError = error);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(error), backgroundColor: const Color(0xffb00020)),
          );
        }
        return;
      }

      setState(() {
        mediaBytes = bytes;
        isVideo = true;
        existingUrl = '';
        mediaError = null;
      });
    } catch (e) {
      setState(() => mediaError = 'Error al leer el video: $e');
    }
  }

  void _showMediaSourceDialog({required bool forVideo}) {
    showModalBottomSheet<void>(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (sheetContext) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                forVideo ? 'SELECCIONAR VIDEO' : 'SELECCIONAR FOTO',
                style: const TextStyle(
                  fontWeight: FontWeight.w800,
                  fontSize: 14,
                  letterSpacing: 1.2,
                  color: Color(0xff49343f),
                ),
              ),
              const SizedBox(height: 12),
              ListTile(
                leading: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: const Color(0xffd94f87).withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(
                    forVideo ? Icons.videocam_rounded : Icons.camera_alt_rounded,
                    color: const Color(0xffd94f87),
                  ),
                ),
                title: Text(forVideo ? 'Grabar con la Cámara' : 'Tomar Foto'),
                subtitle: const Text('Captura el producto en tiempo real'),
                onTap: () {
                  Navigator.pop(sheetContext);
                  if (forVideo) {
                    _pickVideo(ImageSource.camera);
                  } else {
                    _pickImage(ImageSource.camera);
                  }
                },
              ),
              ListTile(
                leading: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.blue.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(Icons.photo_library_rounded, color: Colors.blue),
                ),
                title: const Text('Elegir de la Galería'),
                subtitle: Text(
                  forVideo ? 'Archivos MP4, WebM o MOV' : 'Archivos JPG, PNG o WebP',
                ),
                onTap: () {
                  Navigator.pop(sheetContext);
                  if (forVideo) {
                    _pickVideo(ImageSource.gallery);
                  } else {
                    _pickImage(ImageSource.gallery);
                  }
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    const magenta = Color(0xffd94f87);
    final hasMedia = mediaBytes != null || existingUrl.isNotEmpty;

    return AlertDialog(
      title: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: magenta.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Icon(Icons.inventory_2_rounded, color: magenta, size: 20),
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
                // ── Sección Multimedia (Foto o Video) ────────────────────────
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
                            const Icon(Icons.perm_media_rounded, color: magenta, size: 20),
                            const SizedBox(width: 10),
                            const Expanded(
                              child: Text(
                                'FOTOGRAFÍA O VIDEO DEL PRODUCTO',
                                style: TextStyle(
                                  fontWeight: FontWeight.w800,
                                  fontSize: 12,
                                  letterSpacing: 1.2,
                                  color: Color(0xff49343f),
                                ),
                              ),
                            ),
                            if (hasMedia)
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                decoration: BoxDecoration(
                                  color: Colors.green.shade50,
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(color: Colors.green.shade400),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(
                                      isVideo ? Icons.videocam : Icons.photo,
                                      size: 13,
                                      color: Colors.green.shade800,
                                    ),
                                    const SizedBox(width: 4),
                                    Text(
                                      isVideo ? 'VIDEO ADJUNTO' : 'FOTO ADJUNTA',
                                      style: TextStyle(
                                        fontSize: 10,
                                        fontWeight: FontWeight.w800,
                                        color: Colors.green.shade800,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        const Text(
                          'Sube una fotografía de alta calidad o un video del producto. Solo se admiten archivos verificados libres de código corrupto o malicioso.',
                          style: TextStyle(fontSize: 12, color: Color(0xff7a5c6b), height: 1.3),
                        ),
                        const SizedBox(height: 14),

                        // Previsualización multimedia
                        if (hasMedia) ...[
                          Container(
                            height: 180,
                            width: double.infinity,
                            decoration: BoxDecoration(
                              color: const Color(0xff18181b),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: magenta.withValues(alpha: 0.4)),
                            ),
                            clipBehavior: Clip.antiAlias,
                            child: Stack(
                              alignment: Alignment.center,
                              children: [
                                if (mediaBytes != null && !isVideo)
                                  Image.memory(
                                    mediaBytes!,
                                    fit: BoxFit.contain,
                                    width: double.infinity,
                                    height: 180,
                                  )
                                else if (existingUrl.isNotEmpty && !isVideo)
                                  Image.network(
                                    existingUrl,
                                    fit: BoxFit.contain,
                                    width: double.infinity,
                                    height: 180,
                                    errorBuilder: (_, __, ___) => const Center(
                                      child: Icon(Icons.broken_image_rounded,
                                          color: Colors.white54, size: 40),
                                    ),
                                  )
                                else
                                  Column(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Container(
                                        padding: const EdgeInsets.all(14),
                                        decoration: BoxDecoration(
                                          color: Colors.white.withValues(alpha: 0.15),
                                          shape: BoxShape.circle,
                                        ),
                                        child: const Icon(Icons.play_arrow_rounded,
                                            color: Colors.white, size: 36),
                                      ),
                                      const SizedBox(height: 8),
                                      Text(
                                        isVideo ? 'Video cargado con éxito' : 'Medio cargado',
                                        style: const TextStyle(
                                          color: Colors.white70,
                                          fontSize: 12,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ],
                                  ),

                                // Botón eliminar medio
                                Positioned(
                                  top: 8,
                                  right: 8,
                                  child: Container(
                                    decoration: BoxDecoration(
                                      color: Colors.black.withValues(alpha: 0.7),
                                      shape: BoxShape.circle,
                                    ),
                                    child: IconButton(
                                      tooltip: 'Quitar archivo',
                                      icon: const Icon(Icons.close, color: Colors.white, size: 18),
                                      onPressed: () {
                                        setState(() {
                                          mediaBytes = null;
                                          existingUrl = '';
                                          isVideo = false;
                                        });
                                      },
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 12),
                        ],

                        // Botones para subir Foto o Video
                        Row(
                          children: [
                            Expanded(
                              child: OutlinedButton.icon(
                                onPressed: () => _showMediaSourceDialog(forVideo: false),
                                icon: const Icon(Icons.add_a_photo_rounded, size: 18),
                                label: Text(hasMedia ? 'CAMBIAR FOTO' : 'SUBIR FOTO'),
                                style: OutlinedButton.styleFrom(
                                  foregroundColor: magenta,
                                  side: const BorderSide(color: magenta),
                                  padding: const EdgeInsets.symmetric(vertical: 12),
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: OutlinedButton.icon(
                                onPressed: () => _showMediaSourceDialog(forVideo: true),
                                icon: const Icon(Icons.video_library_rounded, size: 18),
                                label: Text(hasMedia ? 'CAMBIAR VIDEO' : 'SUBIR VIDEO'),
                                style: OutlinedButton.styleFrom(
                                  foregroundColor: const Color(0xff0284c7),
                                  side: const BorderSide(color: Color(0xff0284c7)),
                                  padding: const EdgeInsets.symmetric(vertical: 12),
                                ),
                              ),
                            ),
                          ],
                        ),

                        if (mediaError != null) ...[
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
                                    mediaError!,
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
                _field(originalPrice, 'Precio Original / Anterior (\$) (Opcional)',
                    numeric: true, required: false),
                _field(wholesalePrice, 'Precio Mayoreo (\$) (Opcional)',
                    numeric: true, required: false),
                _field(stock, 'Existencia (Stock)', integer: true),
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
              : const Icon(Icons.check_circle_rounded, size: 18),
          label: Text(
            saving ? 'GUARDANDO…' : 'GUARDAR PRODUCTO',
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

    setState(() {
      saving = true;
      mediaError = null;
    });

    final orig = double.tryParse(originalPrice.text);
    final whol = double.tryParse(wholesalePrice.text);

    final failure = await widget.store.saveProduct(
      Product(
        id: current?.id ?? DateTime.now().microsecondsSinceEpoch.toString(),
        name: name.text.trim(),
        sku: sku.text.trim(),
        category: category!.trim(),
        price: double.parse(price.text),
        originalPrice: orig,
        wholesalePrice: whol,
        stock: int.parse(stock.text),
        minimumStock: int.parse(minimum.text),
        barcode: barcode.text.trim(),
        photoBase64: mediaBytes == null ? (current?.photoBase64 ?? '') : base64Encode(mediaBytes!),
        imageUrl: existingUrl.isNotEmpty ? existingUrl : (current?.imageUrl ?? ''),
        mediaType: isVideo ? 'video' : 'image',
        modelUrl: '',
        imageUrls: current?.imageUrls ?? [],
        pendingImagesBase64: mediaBytes != null ? [base64Encode(mediaBytes!)] : [],
      ),
    );

    if (!mounted) return;
    setState(() => saving = false);
    if (failure != null) {
      setState(() => mediaError = failure);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(failure)));
      return;
    }
    Navigator.pop(context);
  }
}
