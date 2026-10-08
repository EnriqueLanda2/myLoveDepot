import 'package:flutter/material.dart';

import '../ui/components.dart';
import '../ui/tokens.dart';
import '../widgets/pwa_helpers.dart';

/// Guía rápida de cada sección.
Future<void> showHelpDialog(BuildContext context) {
  const sections = [
    (
      Icons.dashboard_outlined,
      'Resumen',
      'Unidades en stock, valor del almacén y ganancias de hoy y del mes. "Requiere atención" muestra lo que se está acabando; toca "Reabastecer" para registrar una entrada.'
    ),
    (
      Icons.add_a_photo_outlined,
      'Nuevo producto con IA',
      'Sube una foto y la IA identifica el producto, redacta la descripción, sugiere la categoría y te ofrece fotografías de catálogo. Todo se puede editar antes de guardar.'
    ),
    (
      Icons.inventory_2_outlined,
      'Productos',
      '"Entrada" suma unidades y "Salida" registra una venta con su ganancia (precio − costo). Una salida nunca puede superar el stock.'
    ),
    (
      Icons.sell_outlined,
      'Categorías',
      'Agrupan el catálogo. Solo se pueden eliminar cuando ya no tienen productos.'
    ),
    (
      Icons.swap_horiz_rounded,
      'Movimientos',
      'Historial de entradas y salidas con la ganancia de cada venta.'
    ),
    (
      Icons.account_balance_wallet_outlined,
      'Finanzas',
      'Define un presupuesto semanal (lunes a domingo): verás cuánto puedes gastar, cuánto llevas ahorrado y tu saldo (fondo inicial − gastos).'
    ),
    (
      Icons.undo_rounded,
      'Deshacer',
      'Al eliminar un producto o un gasto aparece "Deshacer" durante unos segundos.'
    ),
  ];
  return showAppModal<void>(
    context,
    maxWidth: 560,
    builder: (dialogContext) => ModalBody(
      title: '¿Cómo usar My Love Depot?',
      body: [
        for (final (icon, title, body) in sections)
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: AppColors.primarySoft,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, size: 18, color: AppColors.primary),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title,
                        style: appText(size: 14, weight: FontWeight.w700)),
                    const SizedBox(height: 2),
                    Text(body,
                        style: appText(
                            size: 13,
                            color: AppColors.textSecondary,
                            height: 1.45)),
                  ],
                ),
              ),
            ],
          ),
      ],
      actions: [
        AppButton(
            label: 'Entendido', onPressed: () => Navigator.pop(dialogContext)),
      ],
    ),
  );
}

/// Cómo instalar la app en iPhone, Android o computadora.
Future<void> showInstallDialog(BuildContext context) {
  Widget steps(IconData icon, String title, List<String> items) => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Icon(icon, size: 20, color: AppColors.text),
              const SizedBox(width: 8),
              Text(title, style: appText(size: 14, weight: FontWeight.w700)),
            ],
          ),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: AppColors.background,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                for (var i = 0; i < items.length; i++) ...[
                  if (i > 0) const SizedBox(height: 8),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('${i + 1}.',
                          style: appText(
                              size: 13,
                              weight: FontWeight.w700,
                              color: AppColors.primary)),
                      const SizedBox(width: 8),
                      Expanded(
                          child: Text(items[i],
                              style: appText(size: 13, height: 1.4))),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ],
      );

  return showAppModal<void>(
    context,
    maxWidth: 500,
    builder: (dialogContext) => ModalBody(
      title: 'Descargar app',
      subtitle:
          'Instala My Love Depot en tu teléfono o computadora; se abre como una app normal.',
      body: [
        steps(Icons.phone_iphone_rounded, 'iPhone / iPad (Safari)', const [
          'Toca el botón Compartir (cuadro con flecha).',
          'Elige "Agregar a inicio".',
          'Toca "Agregar".',
        ]),
        steps(Icons.android_rounded, 'Android / Chrome / Edge', const [
          'Toca el menú ⋮ del navegador.',
          'Elige "Instalar aplicación" o "Agregar a la pantalla principal".',
        ]),
      ],
      actions: [
        if (PwaHelpers.isPwaInstallAvailable())
          AppButton(
            label: 'Instalar ahora',
            icon: Icons.download_rounded,
            onPressed: () async {
              Navigator.pop(dialogContext);
              await PwaHelpers.triggerPwaInstall();
            },
          )
        else
          AppButton(
              label: 'Entendido',
              onPressed: () => Navigator.pop(dialogContext)),
      ],
    ),
  );
}
