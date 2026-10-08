import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../models.dart';
import 'tokens.dart';

// ── Button ───────────────────────────────────────────────────────────────────

enum AppButtonVariant { primary, secondary, success, dark, soft, link }

/// Botón de la app: primario rosa, secundario blanco con borde, verde de
/// entrada, oscuro (IA), suave (fondos claros) y enlace.
class AppButton extends StatelessWidget {
  const AppButton({
    required this.label,
    required this.onPressed,
    this.icon,
    this.variant = AppButtonVariant.primary,
    this.expand = false,
    this.compact = false,
    this.tooltip,
    super.key,
  });

  final String label;
  final IconData? icon;
  final VoidCallback? onPressed;
  final AppButtonVariant variant;
  final bool expand;
  final bool compact;
  final String? tooltip;

  @override
  Widget build(BuildContext context) {
    final enabled = onPressed != null;
    final (Color bg, Color hover, Color fg, Color? border) = switch (variant) {
      AppButtonVariant.primary => (
          enabled ? AppColors.primary : AppColors.primaryDisabled,
          AppColors.primaryHover,
          Colors.white,
          null,
        ),
      AppButtonVariant.secondary => (
          AppColors.surface,
          AppColors.background,
          enabled ? AppColors.text : AppColors.textMuted,
          AppColors.border,
        ),
      AppButtonVariant.success => (
          enabled ? AppColors.successStrong : AppColors.successBorder,
          AppColors.success,
          Colors.white,
          null,
        ),
      AppButtonVariant.dark => (
          AppColors.text,
          Colors.black,
          Colors.white,
          null
        ),
      AppButtonVariant.soft => (
          AppColors.successSoft,
          const Color(0xFFD4EDDF),
          AppColors.success,
          null,
        ),
      AppButtonVariant.link => (
          Colors.transparent,
          AppColors.primarySoft,
          enabled ? AppColors.primary : AppColors.textMuted,
          null,
        ),
    };
    final isLink = variant == AppButtonVariant.link;
    final padding = isLink
        ? const EdgeInsets.symmetric(horizontal: 6, vertical: 4)
        : compact
            ? const EdgeInsets.symmetric(horizontal: 12, vertical: 8)
            : const EdgeInsets.symmetric(horizontal: 16, vertical: 12);

    Widget button = TextButton(
      onPressed: onPressed,
      style: ButtonStyle(
        padding: WidgetStatePropertyAll(padding),
        minimumSize: const WidgetStatePropertyAll(Size(0, 0)),
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        foregroundColor: WidgetStatePropertyAll(fg),
        backgroundColor: WidgetStateProperty.resolveWith((states) =>
            states.contains(WidgetState.hovered) && enabled ? hover : bg),
        overlayColor: const WidgetStatePropertyAll(Colors.transparent),
        shape: WidgetStatePropertyAll(RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(isLink ? 8 : 12),
          side: border == null ? BorderSide.none : BorderSide(color: border),
        )),
        mouseCursor: WidgetStatePropertyAll(
            enabled ? SystemMouseCursors.click : SystemMouseCursors.forbidden),
      ),
      child: Row(
        mainAxisSize: expand ? MainAxisSize.max : MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          if (icon != null) ...[
            Icon(icon, size: compact || isLink ? 18 : 20, color: fg),
            const SizedBox(width: 8),
          ],
          Flexible(
            child: Text(
              label,
              overflow: TextOverflow.ellipsis,
              style: appText(
                size: compact || isLink ? 13 : 14,
                weight: FontWeight.w600,
                color: fg,
              ),
            ),
          ),
        ],
      ),
    );
    if (tooltip != null) button = Tooltip(message: tooltip!, child: button);
    return expand ? SizedBox(width: double.infinity, child: button) : button;
  }
}

/// Botón cuadrado de solo ícono (editar, eliminar, cerrar).
class AppIconButton extends StatelessWidget {
  const AppIconButton({
    required this.icon,
    required this.tooltip,
    required this.onPressed,
    this.color = AppColors.textSecondary,
    this.hoverColor = AppColors.primary,
    this.background,
    this.borderColor,
    this.size = 32,
    super.key,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback? onPressed;
  final Color color;
  final Color hoverColor;
  final Color? background;
  final Color? borderColor;
  final double size;

  @override
  Widget build(BuildContext context) {
    final enabled = onPressed != null;
    return Tooltip(
      message: tooltip,
      child: SizedBox.square(
        dimension: size,
        child: IconButton(
          onPressed: onPressed,
          padding: EdgeInsets.zero,
          iconSize: 18,
          style: ButtonStyle(
            backgroundColor: WidgetStatePropertyAll(background),
            foregroundColor: WidgetStateProperty.resolveWith((states) {
              if (!enabled) return AppColors.border;
              return states.contains(WidgetState.hovered) ? hoverColor : color;
            }),
            overlayColor: const WidgetStatePropertyAll(AppColors.borderSoft),
            shape: WidgetStatePropertyAll(RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
              side: borderColor == null
                  ? BorderSide.none
                  : BorderSide(color: borderColor!),
            )),
            mouseCursor: WidgetStatePropertyAll(enabled
                ? SystemMouseCursors.click
                : SystemMouseCursors.forbidden),
          ),
          icon: Icon(icon),
        ),
      ),
    );
  }
}

// ── Chip ─────────────────────────────────────────────────────────────────────

/// Píldora seleccionable con conteo opcional (categorías, filtros).
class AppChip extends StatelessWidget {
  const AppChip({
    required this.label,
    required this.selected,
    required this.onTap,
    this.count,
    this.icon,
    this.selectedColor = AppColors.primary,
    this.selectedForeground = Colors.white,
    this.selectedBorder,
    super.key,
  });

  final String label;
  final bool selected;
  final VoidCallback? onTap;
  final int? count;
  final IconData? icon;
  final Color selectedColor;
  final Color selectedForeground;
  final Color? selectedBorder;

  @override
  Widget build(BuildContext context) {
    final fg = selected ? selectedForeground : AppColors.text;
    return Material(
      color: selected ? selectedColor : AppColors.surface,
      shape: StadiumBorder(
        side: BorderSide(
          color:
              selected ? (selectedBorder ?? selectedColor) : AppColors.border,
        ),
      ),
      child: InkWell(
        onTap: onTap,
        customBorder: const StadiumBorder(),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (icon != null) ...[
                Icon(icon, size: 18, color: fg),
                const SizedBox(width: 6),
              ],
              Text(label,
                  style: appText(size: 13, weight: FontWeight.w600, color: fg)),
              if (count != null) ...[
                const SizedBox(width: 6),
                Text(
                  '$count',
                  style: appText(
                    size: 13,
                    weight: FontWeight.w500,
                    color: fg.withValues(alpha: 0.7),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// Selector segmentado (Cuadrícula/Lista, Entrada/Salida, periodos).
class AppSegmented<T> extends StatelessWidget {
  const AppSegmented({
    required this.options,
    required this.selected,
    required this.onChanged,
    this.background = AppColors.surface,
    this.bordered = true,
    this.expand = false,
    super.key,
  });

  final List<AppSegment<T>> options;
  final T selected;
  final ValueChanged<T> onChanged;
  final Color background;
  final bool bordered;
  final bool expand;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(12),
        border: bordered ? Border.all(color: AppColors.border) : null,
      ),
      child: Row(
        mainAxisSize: expand ? MainAxisSize.max : MainAxisSize.min,
        children: [
          for (final option in options)
            _wrap(
              Tooltip(
                message: option.tooltip ?? '',
                child: GestureDetector(
                  onTap: option.enabled ? () => onChanged(option.value) : null,
                  child: MouseRegion(
                    cursor: option.enabled
                        ? SystemMouseCursors.click
                        : SystemMouseCursors.forbidden,
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 150),
                      padding: EdgeInsets.symmetric(
                        horizontal: option.label == null ? 8 : 14,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        color: option.value == selected
                            ? AppColors.surface
                            : Colors.transparent,
                        borderRadius: BorderRadius.circular(9),
                        boxShadow: option.value == selected
                            ? const [
                                BoxShadow(
                                  color: Color(0x1A2A1F24),
                                  blurRadius: 3,
                                  offset: Offset(0, 1),
                                ),
                              ]
                            : null,
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          if (option.icon != null)
                            Icon(
                              option.icon,
                              size: 20,
                              color: _fg(option),
                            ),
                          if (option.label != null)
                            Flexible(
                              // En pantallas angostas la etiqueta se encoge
                              // en lugar de desbordar.
                              child: FittedBox(
                                fit: BoxFit.scaleDown,
                                child: Text(
                                  option.label!,
                                  style: appText(
                                    size: 13,
                                    weight: FontWeight.w600,
                                    color: _fg(option),
                                  ),
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Color _fg(AppSegment<T> option) {
    if (!option.enabled) return AppColors.textMuted;
    if (option.value != selected) return AppColors.textSecondary;
    return option.selectedColor ?? AppColors.text;
  }

  Widget _wrap(Widget child) => expand ? Expanded(child: child) : child;
}

class AppSegment<T> {
  const AppSegment({
    required this.value,
    this.label,
    this.icon,
    this.tooltip,
    this.selectedColor,
    this.enabled = true,
  });

  final T value;
  final String? label;
  final IconData? icon;
  final String? tooltip;
  final Color? selectedColor;
  final bool enabled;
}

// ── Card ─────────────────────────────────────────────────────────────────────

class AppCard extends StatelessWidget {
  const AppCard({
    required this.child,
    this.padding = const EdgeInsets.all(20),
    this.radius = 16,
    this.dashed = false,
    super.key,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final double radius;
  final bool dashed;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: padding,
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(radius),
        border: Border.all(color: AppColors.border),
      ),
      clipBehavior: Clip.antiAlias,
      child: child,
    );
  }
}

/// Tarjeta con encabezado (título, subtítulo, acción) y filas separadas.
class SectionCard extends StatelessWidget {
  const SectionCard({
    required this.title,
    required this.children,
    this.subtitle,
    this.action,
    this.empty,
    super.key,
  });

  final String title;
  final String? subtitle;
  final Widget? action;
  final List<Widget> children;
  final Widget? empty;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      padding: EdgeInsets.zero,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            padding: const EdgeInsets.fromLTRB(20, 16, 14, 16),
            decoration: const BoxDecoration(
              border: Border(bottom: BorderSide(color: AppColors.border)),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(title,
                          style: appText(size: 16, weight: FontWeight.w700)),
                      if (subtitle != null) ...[
                        const SizedBox(height: 2),
                        Text(subtitle!,
                            style: appText(
                                size: 13, color: AppColors.textSecondary)),
                      ],
                    ],
                  ),
                ),
                if (action != null) action!,
              ],
            ),
          ),
          if (children.isEmpty && empty != null)
            empty!
          else
            for (var i = 0; i < children.length; i++)
              DecoratedBox(
                decoration: BoxDecoration(
                  border: i == children.length - 1
                      ? null
                      : const Border(
                          bottom: BorderSide(color: AppColors.borderSoft)),
                ),
                child: children[i],
              ),
        ],
      ),
    );
  }
}

/// Recuadro punteado para estados vacíos.
class EmptyBox extends StatelessWidget {
  const EmptyBox({
    required this.title,
    this.message,
    this.icon,
    this.action,
    super.key,
  });

  final String title;
  final String? message;
  final IconData? icon;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: _DashedBorderPainter(),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 48),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (icon != null) ...[
              Container(
                width: 56,
                height: 56,
                decoration: const BoxDecoration(
                  color: AppColors.primarySoft,
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, color: AppColors.primary, size: 26),
              ),
              const SizedBox(height: 12),
            ],
            Text(title,
                textAlign: TextAlign.center,
                style: appText(size: 15, weight: FontWeight.w600)),
            if (message != null) ...[
              const SizedBox(height: 6),
              ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 380),
                child: Text(
                  message!,
                  textAlign: TextAlign.center,
                  style: appText(
                      size: 14, color: AppColors.textSecondary, height: 1.45),
                ),
              ),
            ],
            if (action != null) ...[const SizedBox(height: 16), action!],
          ],
        ),
      ),
    );
  }
}

class _DashedBorderPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final rrect = RRect.fromRectAndRadius(
      Offset.zero & size,
      const Radius.circular(16),
    );
    canvas.drawRRect(rrect, Paint()..color = AppColors.surface);
    final path = Path()..addRRect(rrect.deflate(0.5));
    final paint = Paint()
      ..color = AppColors.border
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;
    for (final metric in path.computeMetrics()) {
      for (double d = 0; d < metric.length; d += 9) {
        canvas.drawPath(metric.extractPath(d, d + 5), paint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

// ── Encabezado de página ─────────────────────────────────────────────────────

class PageHeader extends StatelessWidget {
  const PageHeader({
    required this.title,
    this.eyebrow,
    this.actions = const [],
    super.key,
  });

  final String title;
  final String? eyebrow;
  final List<Widget> actions;

  @override
  Widget build(BuildContext context) {
    final compact = MediaQuery.sizeOf(context).width < 600;
    return Wrap(
      alignment: WrapAlignment.spaceBetween,
      crossAxisAlignment: WrapCrossAlignment.end,
      spacing: 16,
      runSpacing: 12,
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            if (eyebrow != null) ...[
              Text(eyebrow!,
                  style: appText(size: 13, color: AppColors.textSecondary)),
              const SizedBox(height: 4),
            ],
            Text(title,
                style:
                    appText(size: compact ? 24 : 28, weight: FontWeight.w700)),
          ],
        ),
        if (actions.isNotEmpty)
          Wrap(spacing: 8, runSpacing: 8, children: actions),
      ],
    );
  }
}

// ── Stock pill y badges ──────────────────────────────────────────────────────

/// Verde normal, ámbar en el mínimo, rojo "Agotado".
class StockPill extends StatelessWidget {
  const StockPill({required this.product, super.key});
  final Product product;

  @override
  Widget build(BuildContext context) {
    final (Color bg, Color fg, String text) = product.isOutOfStock
        ? (AppColors.errorSoft, AppColors.error, 'Agotado')
        : product.hasLowStock
            ? (
                AppColors.warningSoft,
                AppColors.warning,
                '${product.stock} en stock'
              )
            : (
                AppColors.successSoft,
                AppColors.success,
                '${product.stock} en stock'
              );
    return Pill(text: text, background: bg, foreground: fg);
  }
}

class Pill extends StatelessWidget {
  const Pill({
    required this.text,
    required this.background,
    required this.foreground,
    super.key,
  });

  final String text;
  final Color background;
  final Color foreground;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(text,
          style: appText(size: 12, weight: FontWeight.w600, color: foreground)),
    );
  }
}

/// Marca morada de los campos que llenó la IA.
class AiBadge extends StatelessWidget {
  const AiBadge({this.text = 'IA', super.key});
  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
      decoration: BoxDecoration(
        color: AppColors.aiSoft,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(text,
          style:
              appText(size: 11, color: AppColors.ai, weight: FontWeight.w600)),
    );
  }
}

// ── Campos ───────────────────────────────────────────────────────────────────

InputDecoration appInputDecoration(
        {String? hint, Widget? prefix, Widget? suffix}) =>
    InputDecoration(
      hintText: hint,
      hintStyle: appText(size: 14, color: AppColors.textMuted),
      isDense: true,
      filled: true,
      fillColor: AppColors.surface,
      prefixIcon: prefix,
      suffixIcon: suffix,
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: AppColors.border),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: AppColors.border),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: AppColors.primary, width: 1.5),
      ),
    );

/// Campo con etiqueta arriba y marca opcional (p. ej. "IA").
class LabeledField extends StatelessWidget {
  const LabeledField({
    required this.label,
    required this.controller,
    this.hint,
    this.badge,
    this.maxLines = 1,
    this.numeric = false,
    this.integer = false,
    this.onChanged,
    this.onSubmitted,
    super.key,
  });

  final String label;
  final TextEditingController controller;
  final String? hint;
  final Widget? badge;
  final int maxLines;
  final bool numeric;
  final bool integer;
  final ValueChanged<String>? onChanged;
  final ValueChanged<String>? onSubmitted;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Flexible(
                child: Text(label,
                    style: appText(size: 13, weight: FontWeight.w600))),
            if (badge != null) ...[const SizedBox(width: 8), badge!],
          ],
        ),
        const SizedBox(height: 6),
        TextField(
          controller: controller,
          maxLines: maxLines,
          minLines: maxLines > 1 ? maxLines : null,
          onChanged: onChanged,
          onSubmitted: onSubmitted,
          style: appText(size: 14, height: maxLines > 1 ? 1.5 : null),
          keyboardType: integer
              ? TextInputType.number
              : numeric
                  ? const TextInputType.numberWithOptions(decimal: true)
                  : maxLines > 1
                      ? TextInputType.multiline
                      : TextInputType.text,
          inputFormatters: integer
              ? [FilteringTextInputFormatter.digitsOnly]
              : numeric
                  ? [FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]'))]
                  : null,
          textCapitalization: numeric || integer
              ? TextCapitalization.none
              : TextCapitalization.sentences,
          decoration: appInputDecoration(hint: hint),
        ),
      ],
    );
  }
}

/// Monto grande con "$" (gasto, fondo, presupuesto).
class AmountField extends StatelessWidget {
  const AmountField({
    required this.controller,
    this.onChanged,
    this.onSubmitted,
    this.autofocus = true,
    super.key,
  });

  final TextEditingController controller;
  final ValueChanged<String>? onChanged;
  final ValueChanged<String>? onSubmitted;
  final bool autofocus;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      decoration: BoxDecoration(
        border: Border.all(color: AppColors.border),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          Text('\$',
              style: appText(
                  size: 28,
                  weight: FontWeight.w700,
                  color: AppColors.textSecondary)),
          const SizedBox(width: 6),
          Expanded(
            child: TextField(
              controller: controller,
              autofocus: autofocus,
              onChanged: onChanged,
              onSubmitted: onSubmitted,
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              inputFormatters: [
                FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]'))
              ],
              style: appText(size: 32, weight: FontWeight.w700),
              decoration: InputDecoration(
                hintText: '0.00',
                hintStyle: appText(
                    size: 32,
                    weight: FontWeight.w700,
                    color: AppColors.textMuted),
                border: InputBorder.none,
                enabledBorder: InputBorder.none,
                focusedBorder: InputBorder.none,
                filled: false,
                isDense: true,
                contentPadding: const EdgeInsets.symmetric(vertical: 8),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Modal ────────────────────────────────────────────────────────────────────

/// Abre un modal centrado al estilo del rediseño. En teléfonos ocupa casi
/// todo el ancho.
Future<T?> showAppModal<T>(
  BuildContext context, {
  required WidgetBuilder builder,
  double maxWidth = 440,
}) {
  return showDialog<T>(
    context: context,
    barrierColor: AppColors.scrim,
    builder: (dialogContext) => Dialog(
      backgroundColor: AppColors.surface,
      surfaceTintColor: Colors.transparent,
      insetPadding: const EdgeInsets.all(16),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
      clipBehavior: Clip.antiAlias,
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: maxWidth),
        child: builder(dialogContext),
      ),
    ),
  );
}

/// Contenido estándar de un modal pequeño: título, cuerpo y botones.
class ModalBody extends StatelessWidget {
  const ModalBody({
    required this.title,
    required this.body,
    required this.actions,
    this.subtitle,
    super.key,
  });

  final String title;
  final String? subtitle;
  final List<Widget> body;
  final List<Widget> actions;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(title, style: appText(size: 18, weight: FontWeight.w700)),
          if (subtitle != null) ...[
            const SizedBox(height: 4),
            Text(subtitle!,
                style: appText(
                    size: 13, color: AppColors.textSecondary, height: 1.45)),
          ],
          const SizedBox(height: 18),
          for (var i = 0; i < body.length; i++) ...[
            if (i > 0) const SizedBox(height: 16),
            body[i],
          ],
          const SizedBox(height: 18),
          Row(
            children: [
              for (var i = 0; i < actions.length; i++) ...[
                if (i > 0) const SizedBox(width: 10),
                Expanded(
                    flex: i == actions.length - 1 ? 2 : 1, child: actions[i]),
              ],
            ],
          ),
        ],
      ),
    );
  }
}

// ── Toast ────────────────────────────────────────────────────────────────────

/// Aviso inferior para confirmar acciones, con "Deshacer" opcional.
abstract final class AppToast {
  static OverlayEntry? _entry;
  static Timer? _timer;

  static void show(
    BuildContext context,
    String message, {
    VoidCallback? onUndo,
    bool warning = false,
    Duration duration = const Duration(seconds: 4),
  }) {
    final overlay = Overlay.maybeOf(context, rootOverlay: true);
    if (overlay == null) return;
    hide();
    _entry = OverlayEntry(
      builder: (_) => _ToastView(
        message: message,
        warning: warning,
        onUndo: onUndo == null
            ? null
            : () {
                hide();
                onUndo();
              },
      ),
    );
    overlay.insert(_entry!);
    _timer = Timer(duration, hide);
  }

  static void hide() {
    _timer?.cancel();
    _timer = null;
    _entry?.remove();
    _entry = null;
  }
}

class _ToastView extends StatelessWidget {
  const _ToastView({required this.message, required this.warning, this.onUndo});

  final String message;
  final bool warning;
  final VoidCallback? onUndo;

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.paddingOf(context).bottom + 24;
    return Positioned(
      left: 16,
      right: 16,
      bottom: bottom,
      child: Center(
        child: Material(
          color: AppColors.text,
          elevation: 8,
          shadowColor: Colors.black38,
          borderRadius: BorderRadius.circular(14),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 520),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    warning ? Icons.info_rounded : Icons.check_circle_rounded,
                    size: 20,
                    color: warning
                        ? const Color(0xFFF5C77E)
                        : const Color(0xFF8FD5AE),
                  ),
                  const SizedBox(width: 12),
                  Flexible(
                    child: Text(message,
                        style: appText(size: 14, color: Colors.white)),
                  ),
                  if (onUndo != null) ...[
                    const SizedBox(width: 16),
                    InkWell(
                      onTap: onUndo,
                      child: Text(
                        'Deshacer',
                        style: appText(
                          size: 14,
                          weight: FontWeight.w700,
                          color: const Color(0xFFF5A9C6),
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ── Imagen del producto ──────────────────────────────────────────────────────

final Map<String, Uint8List> _decodedPhotos = {};

/// Decodifica una foto Base64 una sola vez y la reutiliza en cada redibujado.
Uint8List? decodePhoto(String base64Photo) {
  if (base64Photo.isEmpty) return null;
  final key = '${base64Photo.length}:${base64Photo.hashCode}';
  final cached = _decodedPhotos[key];
  if (cached != null) return cached;
  try {
    final bytes = base64Decode(base64Photo);
    if (_decodedPhotos.length > 200) _decodedPhotos.clear();
    return _decodedPhotos[key] = bytes;
  } on FormatException {
    return null;
  }
}

/// Foto del producto o, si no hay, el fondo rayado del prototipo.
class ProductImage extends StatelessWidget {
  const ProductImage({
    required this.product,
    this.showPlaceholderText = true,
    super.key,
  });

  final Product product;
  final bool showPlaceholderText;

  @override
  Widget build(BuildContext context) {
    final bytes = decodePhoto(product.photoBase64);
    Widget? image;
    if (bytes != null) {
      image = Image.memory(bytes, fit: BoxFit.cover, gaplessPlayback: true);
    } else if (product.imageUrl.isNotEmpty && !product.isVideo) {
      image = Image.network(
        product.imageUrl,
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) => _placeholder(),
      );
    }
    return image ?? _placeholder();
  }

  Widget _placeholder() => CustomPaint(
        painter: const StripesPainter(),
        child: Center(
          child: showPlaceholderText
              ? Text(
                  product.isVideo ? 'video del producto' : 'foto del producto',
                  style: const TextStyle(
                    fontFamily: 'monospace',
                    fontSize: 11,
                    color: Color(0xFFA8979E),
                  ),
                )
              : null,
        ),
      );
}

class StripesPainter extends CustomPainter {
  const StripesPainter();

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRect(Offset.zero & size, Paint()..color = AppColors.background);
    final paint = Paint()
      ..color = AppColors.stripe
      ..strokeWidth = 7;
    for (double x = -size.height; x < size.width; x += 20) {
      canvas.drawLine(
          Offset(x, size.height), Offset(x + size.height, 0), paint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

/// Calcula cuántas columnas caben con un ancho mínimo por tarjeta.
int columnsFor(double width, double minTile, double gap,
    {int max = 6, int min = 1}) {
  final count = ((width + gap) / (minTile + gap)).floor();
  return count.clamp(min, max);
}
