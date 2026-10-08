import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;

import 'package:desktop_drop/desktop_drop.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';

import '../inventory_store.dart';
import '../models.dart';
import '../ui/components.dart';
import '../ui/tokens.dart';

/// Nuevo producto (o edición) con análisis de la foto por IA.
/// Devuelve `true` cuando se creó un producto nuevo.
Future<bool?> showProductModal(
  BuildContext context,
  InventoryStore store, {
  Product? product,
}) {
  return showAppModal<bool>(
    context,
    maxWidth: 1060,
    builder: (_) =>
        ProductModal(store: store, product: product, toastContext: context),
  );
}

enum _AiStatus { idle, analyzing, done }

const _aiSteps = [
  'Detectando el producto',
  'Identificando marca y tono',
  'Redactando descripción y categoría',
  'Generando fotografías',
];

class ProductModal extends StatefulWidget {
  const ProductModal({
    required this.store,
    required this.toastContext,
    this.product,
    super.key,
  });

  final InventoryStore store;
  final Product? product;
  final BuildContext toastContext;

  @override
  State<ProductModal> createState() => _ProductModalState();
}

class _ProductModalState extends State<ProductModal> {
  late final Product? original = widget.product;
  late final name = TextEditingController(text: original?.name);
  late final shade = TextEditingController(text: original?.shade);
  late final sku = TextEditingController(text: original?.sku);
  late final description = TextEditingController(text: original?.description);
  late final price = TextEditingController(
      text: original == null ? '' : _plain(original!.price));
  late final cost = TextEditingController(
      text: original == null || original!.cost == 0
          ? ''
          : _plain(original!.cost));
  late final stock = TextEditingController(text: '${original?.stock ?? 1}');
  late final minimum =
      TextEditingController(text: '${original?.minimumStock ?? 1}');
  final newCategory = TextEditingController();
  final newTag = TextEditingController();

  late String? category =
      original?.category.trim().isNotEmpty == true ? original!.category : null;
  late List<String> tags = [...?original?.tags];

  /// Campos que llenó la IA; el badge desaparece al editarlos.
  final Set<String> aiFields = {};

  /// Foto base nueva (la que sube el usuario en este modal).
  Uint8List? baseImage;
  bool dragging = false;

  _AiStatus aiStatus = _AiStatus.idle;
  int aiStep = 0;
  String? aiError;
  Timer? _stepTimer;
  int _runId = 0;

  List<AiPhotoOption> photos = [];
  bool photosLoading = false;
  String? photosError;
  int photoSet = 0;
  int? selectedPhoto;

  bool addingCategory = false;
  bool saving = false;

  bool get isNew => original == null;
  double get priceValue => parseAmount(price.text) ?? 0;
  double get costValue => parseAmount(cost.text) ?? 0;
  bool get canSave => name.text.trim().isNotEmpty && priceValue > 0 && !saving;

  static String _plain(double value) => value == value.truncateToDouble()
      ? value.toStringAsFixed(0)
      : value.toStringAsFixed(2);

  @override
  void dispose() {
    _stepTimer?.cancel();
    for (final controller in [
      name,
      shade,
      sku,
      description,
      price,
      cost,
      stock,
      minimum,
      newCategory,
      newTag,
    ]) {
      controller.dispose();
    }
    super.dispose();
  }

  // ── Foto base ───────────────────────────────────────────────────────────

  bool _looksLikeImage(Uint8List bytes) {
    if (bytes.length < 12) return false;
    final jpeg = bytes[0] == 0xFF && bytes[1] == 0xD8;
    final png = bytes[0] == 0x89 &&
        bytes[1] == 0x50 &&
        bytes[2] == 0x4E &&
        bytes[3] == 0x47;
    final gif = bytes[0] == 0x47 && bytes[1] == 0x49 && bytes[2] == 0x46;
    final webp = bytes[0] == 0x52 &&
        bytes[1] == 0x49 &&
        bytes[8] == 0x57 &&
        bytes[9] == 0x45;
    return jpeg || png || gif || webp;
  }

  void _loadImage(Uint8List bytes) {
    if (!_looksLikeImage(bytes)) {
      AppToast.show(context, 'Solo se aceptan fotos (JPG, PNG o WebP).',
          warning: true);
      return;
    }
    setState(() {
      baseImage = bytes;
      photos = [];
      selectedPhoto = null;
      photoSet = 0;
      photosError = null;
    });
    // Al subir la foto, el análisis arranca solo.
    _runAi();
  }

  Future<void> _pickImage([ImageSource source = ImageSource.gallery]) async {
    try {
      final picked = await ImagePicker().pickImage(
        source: source,
        maxWidth: 2000,
        maxHeight: 2000,
        imageQuality: 92,
      );
      if (picked == null) return;
      _loadImage(await picked.readAsBytes());
    } on Object catch (error) {
      if (mounted) {
        AppToast.show(context, 'No se pudo abrir la foto: $error',
            warning: true);
      }
    }
  }

  Future<void> _chooseSource() async {
    if (kIsWeb) return _pickImage();
    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      backgroundColor: AppColors.surface,
      builder: (sheet) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.photo_camera_rounded),
              title: const Text('Tomar foto'),
              onTap: () => Navigator.pop(sheet, ImageSource.camera),
            ),
            ListTile(
              leading: const Icon(Icons.photo_library_rounded),
              title: const Text('Elegir de la galería'),
              onTap: () => Navigator.pop(sheet, ImageSource.gallery),
            ),
          ],
        ),
      ),
    );
    if (source != null) await _pickImage(source);
  }

  /// Bytes de la foto con la que trabaja la IA: la nueva o la ya guardada.
  Future<Uint8List?> _baseBytes() async {
    if (baseImage != null) return baseImage;
    final existing = original;
    if (existing == null) return null;
    final stored = decodePhoto(existing.photoBase64);
    if (stored != null) return stored;
    if (existing.imageUrl.isNotEmpty && !existing.isVideo) {
      try {
        final response = await http
            .get(Uri.parse(existing.imageUrl))
            .timeout(const Duration(seconds: 20));
        if (response.statusCode == 200) return response.bodyBytes;
      } on Object {
        return null;
      }
    }
    return null;
  }

  bool get _hasAnyImage =>
      baseImage != null ||
      (original != null &&
          (original!.photoBase64.isNotEmpty ||
              (original!.imageUrl.isNotEmpty && !original!.isVideo)));

  // ── IA ──────────────────────────────────────────────────────────────────

  Future<void> _runAi() async {
    final bytes = await _baseBytes();
    if (!mounted) return;
    if (bytes == null) {
      AppToast.show(context, 'Sube una foto del producto para analizarla.',
          warning: true);
      return;
    }
    final runId = ++_runId;
    _stepTimer?.cancel();
    setState(() {
      aiStatus = _AiStatus.analyzing;
      aiStep = 0;
      aiError = null;
    });
    _stepTimer = Timer.periodic(const Duration(milliseconds: 900), (_) {
      if (aiStep < 2 && mounted) setState(() => aiStep++);
    });

    final photosFuture = _loadPhotos(bytes, runId: runId);
    try {
      final suggestion = await widget.store.analyzeProductPhoto(bytes);
      if (!mounted || runId != _runId) return;
      _applySuggestion(suggestion);
    } on StoreFailure catch (failure) {
      if (!mounted || runId != _runId) return;
      setState(() => aiError = failure.message);
    }
    _stepTimer?.cancel();
    if (!mounted || runId != _runId) return;
    setState(() => aiStep = 3);
    await photosFuture;
    if (!mounted || runId != _runId) return;
    setState(() {
      aiStep = _aiSteps.length;
      aiStatus = _AiStatus.done;
    });
  }

  Future<void> _loadPhotos(Uint8List bytes, {required int runId}) async {
    setState(() {
      photosLoading = true;
      photosError = null;
    });
    try {
      final options =
          await widget.store.generateProductPhotos(bytes, set: photoSet);
      if (!mounted || runId != _runId) return;
      setState(() {
        photos = options;
        selectedPhoto = options.isEmpty ? null : 0;
      });
    } on StoreFailure catch (failure) {
      if (!mounted || runId != _runId) return;
      setState(() => photosError = failure.message);
    } finally {
      if (mounted && runId == _runId) setState(() => photosLoading = false);
    }
  }

  Future<void> _generateOtherPhotos() async {
    final bytes = await _baseBytes();
    if (bytes == null || !mounted) return;
    setState(() => photoSet++);
    await _loadPhotos(bytes, runId: _runId);
  }

  void _applySuggestion(AiProductSuggestion suggestion) {
    setState(() {
      void fill(String key, TextEditingController controller, String value) {
        if (value.trim().isEmpty) return;
        controller.text = value.trim();
        aiFields.add(key);
      }

      fill('name', name, suggestion.name);
      fill('shade', shade, suggestion.shade);
      fill('desc', description, suggestion.description);
      if (suggestion.category.trim().isNotEmpty) {
        category = suggestion.category.trim();
        aiFields.add('cat');
      }
      if (suggestion.tags.isNotEmpty) {
        tags = [...suggestion.tags];
        aiFields.add('tags');
      }
      if (sku.text.trim().isEmpty) {
        sku.text = _generateSku(suggestion.brand, suggestion.name);
      }
    });
  }

  static String _asciiUpper(String value) {
    const accents = {
      'Á': 'A',
      'É': 'E',
      'Í': 'I',
      'Ó': 'O',
      'Ú': 'U',
      'Ü': 'U',
      'Ñ': 'N'
    };
    final upper = value.toUpperCase();
    final buffer = StringBuffer();
    for (final char in upper.split('')) {
      buffer.write(accents[char] ?? char);
    }
    return buffer.toString().replaceAll(RegExp('[^A-Z0-9 ]'), ' ');
  }

  /// "ELF-HGB-27": marca, iniciales del nombre y dos dígitos al azar.
  static String _generateSku(String brand, String productName) {
    final words = _asciiUpper(productName)
        .split(RegExp(r'\s+'))
        .where((w) => w.isNotEmpty)
        .toList();
    final brandWord = _asciiUpper(brand).replaceAll(' ', '');
    final prefix = (brandWord.isNotEmpty
            ? brandWord
            : (words.isNotEmpty ? words.first : 'PRD'))
        .padRight(3, 'X')
        .substring(0, 3);
    final rest = words
        .where((w) => !w.startsWith(prefix))
        .take(3)
        .map((w) => w[0])
        .join();
    final digits = (math.Random().nextInt(90) + 10).toString();
    return [prefix, if (rest.isNotEmpty) rest, digits].join('-');
  }

  // ── Guardar ─────────────────────────────────────────────────────────────

  Future<void> _save() async {
    if (!canSave) return;
    setState(() => saving = true);
    final store = widget.store;
    final chosenCategory = (category ?? '').trim().isNotEmpty
        ? category!.trim()
        : (store.categoryNames.isNotEmpty
            ? store.categoryNames.first
            : 'General');
    // Una categoría sugerida por la IA que aún no existe se crea al guardar.
    if (!store.categories
        .any((c) => c.name.toLowerCase() == chosenCategory.toLowerCase())) {
      await store.saveCategory(chosenCategory);
    }

    String? photo;
    if (selectedPhoto != null && selectedPhoto! < photos.length) {
      photo = photos[selectedPhoto!].bytesBase64;
    } else if (baseImage != null) {
      photo = base64Encode(baseImage!);
    }

    final product = original?.copy() ??
        Product(
          id: DateTime.now().microsecondsSinceEpoch.toString(),
          name: '',
          sku: '',
          category: chosenCategory,
          price: 0,
          stock: 0,
          minimumStock: 0,
        );
    product
      ..name = name.text.trim()
      ..shade = shade.text.trim()
      ..sku = sku.text.trim().isEmpty
          ? _generateSku('', name.text)
          : sku.text.trim()
      ..category = chosenCategory
      ..description = description.text.trim()
      ..tags = [...tags]
      ..price = priceValue
      ..cost = costValue
      ..stock = math.max(0, int.tryParse(stock.text) ?? 0)
      ..minimumStock = math.max(0, int.tryParse(minimum.text) ?? 0);
    if (photo != null) {
      product
        ..photoBase64 = photo
        ..pendingImagesBase64 = [photo]
        ..imageUrl = ''
        ..mediaType = 'image';
    }

    final failure = await store.saveProduct(product);
    if (!mounted || !widget.toastContext.mounted) return;
    Navigator.pop(context, isNew);
    if (failure == null) {
      AppToast.show(widget.toastContext,
          isNew ? 'Producto agregado al catálogo' : 'Producto actualizado');
    } else {
      AppToast.show(
          widget.toastContext, 'Guardado en este dispositivo. $failure',
          warning: true, duration: const Duration(seconds: 6));
    }
  }

  // ── UI ──────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _header(),
        Flexible(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: LayoutBuilder(
              builder: (context, constraints) {
                final twoColumns = constraints.maxWidth >= 720;
                final left = _leftColumn();
                final right = _rightColumn(twoColumns);
                if (!twoColumns) {
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [left, const SizedBox(height: 24), right],
                  );
                }
                return Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(child: left),
                    const SizedBox(width: 28),
                    Expanded(child: right),
                  ],
                );
              },
            ),
          ),
        ),
        _footer(),
      ],
    );
  }

  Widget _header() {
    return Container(
      padding: const EdgeInsets.fromLTRB(24, 20, 16, 20),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: AppColors.border)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(isNew ? 'Nuevo producto' : 'Editar producto',
                    style: appText(size: 20, weight: FontWeight.w700)),
                const SizedBox(height: 2),
                Text(
                  'Sube una foto y la IA completa la ficha por ti. Revisa y ajusta lo que necesites.',
                  style: appText(size: 13, color: AppColors.textSecondary),
                ),
              ],
            ),
          ),
          AppIconButton(
            icon: Icons.close_rounded,
            tooltip: 'Cerrar',
            size: 36,
            background: AppColors.background,
            onPressed: () => Navigator.pop(context),
          ),
        ],
      ),
    );
  }

  Widget _footer() {
    return Container(
      padding: const EdgeInsets.fromLTRB(24, 14, 24, 14),
      decoration: const BoxDecoration(
        border: Border(top: BorderSide(color: AppColors.border)),
      ),
      child: Wrap(
        alignment: WrapAlignment.end,
        crossAxisAlignment: WrapCrossAlignment.center,
        spacing: 10,
        runSpacing: 10,
        children: [
          if (!canSave && !saving)
            Text('Completa nombre y precio para guardar',
                style: appText(size: 13, color: AppColors.textSecondary)),
          AppButton(
            label: 'Cancelar',
            variant: AppButtonVariant.secondary,
            onPressed: () => Navigator.pop(context),
          ),
          AppButton(
            label: saving
                ? 'Guardando…'
                : isNew
                    ? 'Agregar al catálogo'
                    : 'Guardar cambios',
            onPressed: canSave ? _save : null,
          ),
        ],
      ),
    );
  }

  Widget _leftColumn() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _dropzone(),
        const SizedBox(height: 16),
        if (aiStatus == _AiStatus.idle && _hasAnyImage)
          AppButton(
            label: 'Analizar con IA',
            icon: Icons.auto_awesome_rounded,
            variant: AppButtonVariant.dark,
            expand: true,
            onPressed: _runAi,
          ),
        if (aiStatus == _AiStatus.analyzing) _progress(),
        if (aiError != null) ...[
          _notice(
            icon: Icons.info_outline_rounded,
            text:
                'No se pudo completar el análisis: $aiError Puedes llenar la ficha a mano.',
            background: AppColors.warningSoft,
            color: AppColors.warningDark,
            action: aiStatus == _AiStatus.analyzing
                ? null
                : AppButton(
                    label: 'Reintentar',
                    variant: AppButtonVariant.link,
                    onPressed: _runAi,
                  ),
          ),
          const SizedBox(height: 12),
        ],
        if (photos.isNotEmpty || photosLoading || photosError != null)
          _photoPicker(),
      ],
    );
  }

  Widget _dropzone() {
    final existing = original;
    Widget? preview;
    if (baseImage != null) {
      preview = Image.memory(baseImage!, fit: BoxFit.contain);
    } else if (existing != null &&
        (existing.photoBase64.isNotEmpty || existing.imageUrl.isNotEmpty)) {
      preview = ProductImage(product: existing);
    }
    return DropTarget(
      onDragEntered: (_) => setState(() => dragging = true),
      onDragExited: (_) => setState(() => dragging = false),
      onDragDone: (detail) async {
        setState(() => dragging = false);
        if (detail.files.isEmpty) return;
        _loadImage(await detail.files.first.readAsBytes());
      },
      child: Material(
        color: dragging ? AppColors.primarySoft : const Color(0xFFFDF8FA),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(18),
          side: BorderSide(
            color: dragging ? AppColors.primary : const Color(0xFFEBCBD8),
            width: 2,
          ),
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: _chooseSource,
          child: AspectRatio(
            aspectRatio: 4 / 3,
            child: preview != null
                ? Stack(
                    fit: StackFit.expand,
                    children: [
                      ColoredBox(color: AppColors.surface, child: preview),
                      Positioned(
                        right: 10,
                        bottom: 10,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 6),
                          decoration: BoxDecoration(
                            color: AppColors.surface,
                            borderRadius: BorderRadius.circular(999),
                            boxShadow: const [
                              BoxShadow(
                                  color: Color(0x14000000),
                                  blurRadius: 8,
                                  offset: Offset(0, 2)),
                            ],
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.swap_horiz_rounded, size: 16),
                              const SizedBox(width: 6),
                              Text('Cambiar foto',
                                  style: appText(
                                      size: 12, weight: FontWeight.w600)),
                            ],
                          ),
                        ),
                      ),
                    ],
                  )
                : Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Container(
                          width: 56,
                          height: 56,
                          decoration: BoxDecoration(
                            color: AppColors.primarySoft,
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: const Icon(Icons.add_photo_alternate_rounded,
                              color: AppColors.primary, size: 28),
                        ),
                        const SizedBox(height: 10),
                        Text(
                          kIsWeb
                              ? 'Arrastra la foto del producto o haz clic'
                              : 'Toca para tomar o elegir una foto',
                          textAlign: TextAlign.center,
                          style: appText(size: 15, weight: FontWeight.w600),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          'Una foto con el empaque o la etiqueta visible da mejores resultados',
                          textAlign: TextAlign.center,
                          style:
                              appText(size: 13, color: AppColors.textSecondary),
                        ),
                      ],
                    ),
                  ),
          ),
        ),
      ),
    );
  }

  Widget _progress() {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
      decoration: BoxDecoration(
        border: Border.all(color: AppColors.border),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.auto_awesome_rounded,
                  size: 20, color: AppColors.primary),
              const SizedBox(width: 8),
              Text('Analizando imagen…',
                  style: appText(size: 14, weight: FontWeight.w600)),
            ],
          ),
          for (var i = 0; i < _aiSteps.length; i++) ...[
            const SizedBox(height: 10),
            Row(
              children: [
                SizedBox.square(
                  dimension: 18,
                  child: i < aiStep
                      ? const Icon(Icons.check_circle_rounded,
                          size: 18, color: AppColors.success)
                      : i == aiStep
                          ? const Padding(
                              padding: EdgeInsets.all(2),
                              child: CircularProgressIndicator(
                                  strokeWidth: 2, color: AppColors.text),
                            )
                          : const Icon(Icons.radio_button_unchecked_rounded,
                              size: 18, color: AppColors.textMuted),
                ),
                const SizedBox(width: 10),
                Text(
                  _aiSteps[i],
                  style: appText(
                    size: 13,
                    color: i < aiStep
                        ? AppColors.success
                        : i == aiStep
                            ? AppColors.text
                            : AppColors.textMuted,
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _photoPicker() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            const Icon(Icons.photo_library_rounded,
                size: 20, color: AppColors.primary),
            const SizedBox(width: 8),
            Expanded(
              child: Text('Elige la foto del catálogo',
                  style: appText(size: 15, weight: FontWeight.w700)),
            ),
            AppButton(
              label: 'Generar otras',
              icon: Icons.refresh_rounded,
              variant: AppButtonVariant.link,
              onPressed: photosLoading ? null : _generateOtherPhotos,
            ),
          ],
        ),
        const SizedBox(height: 10),
        if (photosError != null)
          Text(photosError!, style: appText(size: 13, color: AppColors.error))
        else
          LayoutBuilder(builder: (context, constraints) {
            final columns = constraints.maxWidth < 300 ? 2 : 4;
            final tile = (constraints.maxWidth - 8 * (columns - 1)) / columns;
            return Wrap(
              spacing: 8,
              runSpacing: 10,
              children: [
                for (var i = 0; i < (photosLoading ? 4 : photos.length); i++)
                  SizedBox(width: tile, child: _photoTile(i)),
              ],
            );
          }),
        const SizedBox(height: 8),
        Text(
          'Las opciones se generan a partir de tu foto: la IA recorta el producto y lo coloca en distintos fondos.',
          style: appText(size: 12, color: AppColors.textSecondary, height: 1.4),
        ),
        if (selectedPhoto != null && baseImage != null)
          Align(
            alignment: Alignment.centerLeft,
            child: AppButton(
              label: 'Usar mi foto original',
              variant: AppButtonVariant.link,
              onPressed: () => setState(() => selectedPhoto = null),
            ),
          ),
      ],
    );
  }

  Widget _photoTile(int index) {
    final loading = photosLoading || index >= photos.length;
    final selected = !loading && selectedPhoto == index;
    final bytes = loading ? null : decodePhoto(photos[index].bytesBase64);
    return GestureDetector(
      onTap: loading ? null : () => setState(() => selectedPhoto = index),
      child: MouseRegion(
        cursor: loading ? SystemMouseCursors.basic : SystemMouseCursors.click,
        child: Column(
          children: [
            AspectRatio(
              aspectRatio: 1,
              child: Container(
                decoration: BoxDecoration(
                  color: AppColors.background,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: selected ? AppColors.primary : AppColors.border,
                    width: selected ? 2 : 1,
                  ),
                ),
                clipBehavior: Clip.antiAlias,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    if (bytes != null)
                      Image.memory(bytes,
                          fit: BoxFit.cover, gaplessPlayback: true)
                    else
                      const Center(
                        child: SizedBox.square(
                          dimension: 18,
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: AppColors.primary),
                        ),
                      ),
                    if (selected)
                      Positioned(
                        top: 6,
                        right: 6,
                        child: Container(
                          width: 22,
                          height: 22,
                          decoration: const BoxDecoration(
                            color: AppColors.primary,
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(Icons.check_rounded,
                              size: 16, color: Colors.white),
                        ),
                      ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 6),
            Text(
              loading ? 'Generando…' : photos[index].label,
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: appText(
                size: 12,
                weight: FontWeight.w600,
                color:
                    selected ? AppColors.primaryText : AppColors.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _notice({
    required IconData icon,
    required String text,
    required Color background,
    required Color color,
    Widget? action,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
          color: background, borderRadius: BorderRadius.circular(12)),
      child: Row(
        children: [
          Icon(icon, size: 18, color: color),
          const SizedBox(width: 10),
          Expanded(
              child: Text(text,
                  style: appText(size: 13, color: color, height: 1.4))),
          if (action != null) action,
        ],
      ),
    );
  }

  Widget _rightColumn(bool twoColumns) {
    final aiDone = aiStatus == _AiStatus.done && aiFields.isNotEmpty;
    final existingNames = widget.store.categoryNames;
    final chipNames = [
      ...existingNames,
      if (category != null &&
          !existingNames.any((n) => n.toLowerCase() == category!.toLowerCase()))
        category!,
    ];
    final margin = priceValue > 0 && costValue > 0;

    Widget pair(Widget a, Widget b) =>
        twoColumns || MediaQuery.sizeOf(context).width > 420
            ? Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(child: a),
                  const SizedBox(width: 12),
                  Expanded(child: b)
                ],
              )
            : Column(children: [a, const SizedBox(height: 16), b]);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (aiDone) ...[
          _notice(
            icon: Icons.auto_awesome_rounded,
            text: 'La IA completó los campos marcados. Puedes editarlos.',
            background: AppColors.aiSoft,
            color: AppColors.ai,
          ),
          const SizedBox(height: 16),
        ],
        LabeledField(
          label: 'Nombre del producto',
          controller: name,
          hint: 'Ej. Elf Halo Glow Beauty Wand Blush',
          badge: aiFields.contains('name') ? const AiBadge() : null,
          onChanged: (_) => setState(() => aiFields.remove('name')),
        ),
        const SizedBox(height: 16),
        pair(
          LabeledField(
            label: 'Tono / variante',
            controller: shade,
            hint: 'Ej. Rosé you slay',
            badge: aiFields.contains('shade') ? const AiBadge() : null,
            onChanged: (_) => setState(() => aiFields.remove('shade')),
          ),
          LabeledField(
            label: 'SKU',
            controller: sku,
            hint: 'Se genera automático',
            onChanged: (_) => setState(() {}),
          ),
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            Text('Categoría',
                style: appText(size: 13, weight: FontWeight.w600)),
            if (aiFields.contains('cat')) ...[
              const SizedBox(width: 8),
              const AiBadge(text: 'IA · sugerida'),
            ],
          ],
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final chipName in chipNames)
              AppChip(
                label: existingNames
                        .any((n) => n.toLowerCase() == chipName.toLowerCase())
                    ? chipName
                    : '+ $chipName (nueva)',
                selected: category?.toLowerCase() == chipName.toLowerCase(),
                onTap: () => setState(() {
                  category = chipName;
                  aiFields.remove('cat');
                }),
              ),
            AppChip(
              label: 'Nueva',
              icon: Icons.add_rounded,
              selected: false,
              onTap: () => setState(() => addingCategory = !addingCategory),
            ),
          ],
        ),
        if (addingCategory) ...[
          const SizedBox(height: 8),
          TextField(
            controller: newCategory,
            autofocus: true,
            textCapitalization: TextCapitalization.sentences,
            style: appText(size: 14),
            decoration: appInputDecoration(
              hint: 'Nombre de la categoría y Enter',
              suffix: IconButton(
                tooltip: 'Usar categoría',
                icon: const Icon(Icons.check_rounded),
                onPressed: _acceptNewCategory,
              ),
            ),
            onSubmitted: (_) => _acceptNewCategory(),
          ),
        ],
        const SizedBox(height: 16),
        LabeledField(
          label: 'Descripción',
          controller: description,
          maxLines: 4,
          hint: 'La IA la redacta a partir de la foto',
          badge: aiFields.contains('desc') ? const AiBadge() : null,
          onChanged: (_) => setState(() => aiFields.remove('desc')),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 6,
          runSpacing: 6,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            for (final tag in tags)
              InputChip(
                label: Text(tag, style: appText(size: 12)),
                backgroundColor: AppColors.background,
                side: const BorderSide(color: AppColors.border),
                shape: const StadiumBorder(),
                visualDensity: VisualDensity.compact,
                deleteIcon: const Icon(Icons.close_rounded,
                    size: 14, color: AppColors.textSecondary),
                deleteButtonTooltipMessage: 'Quitar etiqueta',
                onDeleted: () => setState(() {
                  tags.remove(tag);
                  aiFields.remove('tags');
                }),
              ),
            SizedBox(
              width: 170,
              child: TextField(
                controller: newTag,
                style: appText(size: 12),
                decoration:
                    appInputDecoration(hint: '+ Etiqueta y Enter').copyWith(
                  contentPadding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                ),
                onSubmitted: (value) {
                  final tag = value.trim();
                  if (tag.isEmpty || tags.contains(tag)) return;
                  setState(() {
                    tags.add(tag);
                    newTag.clear();
                  });
                },
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        const Divider(height: 1, color: AppColors.border),
        const SizedBox(height: 16),
        pair(
          LabeledField(
            label: 'Precio de venta',
            controller: price,
            numeric: true,
            hint: '\$0',
            onChanged: (_) => setState(() {}),
          ),
          LabeledField(
            label: 'Costo',
            controller: cost,
            numeric: true,
            hint: '\$0',
            onChanged: (_) => setState(() {}),
          ),
        ),
        const SizedBox(height: 12),
        pair(
          LabeledField(
            label: isNew ? 'Stock inicial' : 'Stock',
            controller: stock,
            integer: true,
          ),
          LabeledField(
            label: 'Stock mínimo',
            controller: minimum,
            integer: true,
          ),
        ),
        if (margin) ...[
          const SizedBox(height: 12),
          Text(
            priceValue > costValue
                ? 'Ganas ${money(priceValue - costValue)} por unidad '
                    '(${((priceValue - costValue) / priceValue * 100).round()}% de margen)'
                : 'El costo es mayor o igual al precio de venta',
            style: appText(
              size: 13,
              color:
                  priceValue > costValue ? AppColors.success : AppColors.error,
            ),
          ),
        ],
      ],
    );
  }

  void _acceptNewCategory() {
    final value = newCategory.text.trim();
    if (value.isEmpty) return;
    setState(() {
      category = value;
      aiFields.remove('cat');
      addingCategory = false;
      newCategory.clear();
    });
  }
}
