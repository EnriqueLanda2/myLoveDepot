import 'package:flutter/material.dart';

import '../inventory_store.dart';
import '../models.dart';
import '../ui/components.dart';
import '../ui/tokens.dart';
import '../widgets/love_mascot.dart';
import '../widgets/pwa_install_banner.dart';
import 'app_dialogs.dart';
import 'categorias_view.dart';
import 'finanzas_view.dart';
import 'movimientos_view.dart';
import 'product_modal.dart';
import 'productos_view.dart';
import 'resumen_view.dart';

enum AppView { resumen, productos, categorias, movimientos, finanzas }

const _nav = [
  (
    AppView.resumen,
    'Resumen',
    Icons.dashboard_outlined,
    Icons.dashboard_rounded
  ),
  (
    AppView.productos,
    'Productos',
    Icons.inventory_2_outlined,
    Icons.inventory_2_rounded
  ),
  (AppView.categorias, 'Categorías', Icons.sell_outlined, Icons.sell_rounded),
  (
    AppView.movimientos,
    'Movimientos',
    Icons.swap_horiz_rounded,
    Icons.swap_horiz_rounded
  ),
  (
    AppView.finanzas,
    'Finanzas',
    Icons.account_balance_wallet_outlined,
    Icons.account_balance_wallet_rounded
  ),
];

/// Shell: sidebar fijo en pantallas anchas, barra inferior en teléfonos.
class HomeScreen extends StatefulWidget {
  const HomeScreen({required this.store, super.key});
  final InventoryStore store;

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  AppView view = AppView.resumen;
  final productFilter = ProductFilter();
  final scroll = ScrollController();

  InventoryStore get store => widget.store;

  @override
  void dispose() {
    scroll.dispose();
    super.dispose();
  }

  void _go(AppView next) {
    setState(() => view = next);
    if (scroll.hasClients) scroll.jumpTo(0);
  }

  void _showProducts(
      {String category = ProductFilter.allCategories, bool lowOnly = false}) {
    productFilter.reset(category: category, lowOnly: lowOnly);
    _go(AppView.productos);
  }

  Future<void> _newProduct() async {
    final created = await showProductModal(context, store);
    if (created == true && mounted) _showProducts();
  }

  Future<void> _editProduct(Product product) =>
      showProductModal(context, store, product: product);

  Future<void> _confirmLogout() async {
    final confirmed = await showAppModal<bool>(
      context,
      maxWidth: 400,
      builder: (dialogContext) => ModalBody(
        title: '¿Cerrar sesión?',
        subtitle:
            'Tus datos quedan guardados. Necesitarás tu usuario y contraseña para volver a entrar.',
        body: const [],
        actions: [
          AppButton(
            label: 'Cancelar',
            variant: AppButtonVariant.secondary,
            onPressed: () => Navigator.pop(dialogContext, false),
          ),
          AppButton(
              label: 'Cerrar sesión',
              onPressed: () => Navigator.pop(dialogContext, true)),
        ],
      ),
    );
    if (confirmed == true) await store.logout();
  }

  Widget _page() => switch (view) {
        AppView.resumen => ResumenView(
            store: store,
            onShowLowStock: () => _showProducts(lowOnly: true),
            onShowMovements: () => _go(AppView.movimientos),
          ),
        AppView.productos => ProductosView(
            store: store,
            filter: productFilter,
            onFilterChanged: () => setState(() {}),
            onNewProduct: _newProduct,
            onEditProduct: _editProduct,
          ),
        AppView.categorias => CategoriasView(
            store: store,
            onViewProducts: (category) => _showProducts(category: category),
          ),
        AppView.movimientos => MovimientosView(
            store: store,
            onGoToProducts: () => _showProducts(),
          ),
        AppView.finanzas => FinanzasView(store: store),
      };

  String _displayName() {
    final name = store.username.isNotEmpty ? store.username : store.role;
    if (name.isEmpty) return 'Mi cuenta';
    return name[0].toUpperCase() + name.substring(1);
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: store,
      builder: (context, _) {
        if (store.isLoading) {
          return Scaffold(
            backgroundColor: AppColors.background,
            body: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const LoveMascot(size: 80, animate: true),
                  const SizedBox(height: 16),
                  Text('Cargando tu inventario…',
                      style: appText(size: 14, color: AppColors.textSecondary)),
                ],
              ),
            ),
          );
        }
        return LayoutBuilder(builder: (context, constraints) {
          final wide = constraints.maxWidth >= 900;
          final horizontal =
              wide ? (constraints.maxWidth * 0.04).clamp(16.0, 48.0) : 16.0;
          final content = Column(
            children: [
              const PwaInstallBanner(),
              Expanded(
                child: SingleChildScrollView(
                  controller: scroll,
                  padding: EdgeInsets.fromLTRB(
                      horizontal, wide ? 32 : 20, horizontal, 64),
                  child: Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 1200),
                      child: KeyedSubtree(key: ValueKey(view), child: _page()),
                    ),
                  ),
                ),
              ),
            ],
          );

          if (wide) {
            return Scaffold(
              backgroundColor: AppColors.background,
              body: Row(
                children: [
                  _Sidebar(
                    view: view,
                    lowStock: store.lowStockCount,
                    userName: _displayName(),
                    onSelect: _go,
                    onNewProduct: _newProduct,
                    onInstall: () => showInstallDialog(context),
                    onHelp: () => showHelpDialog(context),
                    onLogout: _confirmLogout,
                  ),
                  Expanded(child: content),
                ],
              ),
            );
          }

          return Scaffold(
            backgroundColor: AppColors.background,
            appBar: AppBar(
              backgroundColor: AppColors.surface,
              surfaceTintColor: Colors.transparent,
              elevation: 0,
              scrolledUnderElevation: 0,
              titleSpacing: 16,
              shape: const Border(bottom: BorderSide(color: AppColors.border)),
              title: Row(
                children: [
                  const LoveMascot(size: 30),
                  const SizedBox(width: 10),
                  Flexible(
                    child: Text('My Love Depot',
                        overflow: TextOverflow.ellipsis,
                        style: appText(size: 16, weight: FontWeight.w700)),
                  ),
                ],
              ),
              actions: [
                AppIconButton(
                  icon: Icons.add_a_photo_outlined,
                  tooltip: 'Nuevo producto',
                  size: 40,
                  color: AppColors.primary,
                  onPressed: _newProduct,
                ),
                PopupMenuButton<String>(
                  tooltip: 'Menú',
                  icon: const Icon(Icons.more_vert_rounded,
                      color: AppColors.textSecondary),
                  onSelected: (value) {
                    switch (value) {
                      case 'help':
                        showHelpDialog(context);
                      case 'install':
                        showInstallDialog(context);
                      case 'logout':
                        _confirmLogout();
                    }
                  },
                  itemBuilder: (_) => [
                    PopupMenuItem(
                      enabled: false,
                      child: Text(_displayName(),
                          style: appText(weight: FontWeight.w600)),
                    ),
                    const PopupMenuItem(value: 'help', child: Text('Ayuda')),
                    const PopupMenuItem(
                        value: 'install', child: Text('Descargar app')),
                    const PopupMenuItem(
                        value: 'logout', child: Text('Cerrar sesión')),
                  ],
                ),
                const SizedBox(width: 4),
              ],
            ),
            body: content,
            bottomNavigationBar: NavigationBar(
              selectedIndex: _nav.indexWhere((item) => item.$1 == view),
              onDestinationSelected: (index) => _go(_nav[index].$1),
              backgroundColor: AppColors.surface,
              indicatorColor: AppColors.primarySoft,
              surfaceTintColor: Colors.transparent,
              height: 66,
              labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
              destinations: [
                for (final (value, label, icon, selected) in _nav)
                  NavigationDestination(
                    icon: Badge(
                      isLabelVisible:
                          value == AppView.resumen && store.lowStockCount > 0,
                      backgroundColor: AppColors.warning,
                      label: Text('${store.lowStockCount}'),
                      child: Icon(icon),
                    ),
                    selectedIcon: Icon(selected, color: AppColors.primaryText),
                    label: label,
                  ),
              ],
            ),
          );
        });
      },
    );
  }
}

class _Sidebar extends StatelessWidget {
  const _Sidebar({
    required this.view,
    required this.lowStock,
    required this.userName,
    required this.onSelect,
    required this.onNewProduct,
    required this.onInstall,
    required this.onHelp,
    required this.onLogout,
  });

  final AppView view;
  final int lowStock;
  final String userName;
  final ValueChanged<AppView> onSelect;
  final VoidCallback onNewProduct;
  final VoidCallback onInstall;
  final VoidCallback onHelp;
  final VoidCallback onLogout;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 232,
      padding: const EdgeInsets.fromLTRB(14, 20, 14, 20),
      decoration: const BoxDecoration(
        color: AppColors.surface,
        border: Border(right: BorderSide(color: AppColors.border)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 6),
            child: Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: AppColors.primarySoft,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  alignment: Alignment.center,
                  child: const LoveMascot(size: 30),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('My Love Depot',
                          style: appText(size: 15, weight: FontWeight.w700)),
                      Text('Gestión de almacén',
                          style: appText(
                              size: 12, color: AppColors.textSecondary)),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          AppButton(
            label: 'Nuevo producto',
            icon: Icons.add_a_photo_outlined,
            expand: true,
            onPressed: onNewProduct,
          ),
          const SizedBox(height: 24),
          for (final (value, label, icon, selectedIcon) in _nav)
            Padding(
              padding: const EdgeInsets.only(bottom: 2),
              child: _NavItem(
                label: label,
                icon: value == view ? selectedIcon : icon,
                selected: value == view,
                badge:
                    value == AppView.resumen && lowStock > 0 ? lowStock : null,
                onTap: () => onSelect(value),
              ),
            ),
          const Spacer(),
          _NavItem(
            label: 'Ayuda',
            icon: Icons.help_outline_rounded,
            selected: false,
            muted: true,
            onTap: onHelp,
          ),
          _NavItem(
            label: 'Descargar app',
            icon: Icons.install_mobile_outlined,
            selected: false,
            muted: true,
            onTap: onInstall,
          ),
          const SizedBox(height: 6),
          Container(
            padding: const EdgeInsets.fromLTRB(12, 6, 6, 6),
            decoration: BoxDecoration(
              border: Border.all(color: AppColors.border),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                const Icon(Icons.verified_user_outlined,
                    size: 20, color: AppColors.primary),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(userName,
                      overflow: TextOverflow.ellipsis,
                      style: appText(size: 14, weight: FontWeight.w600)),
                ),
                AppIconButton(
                    icon: Icons.logout_rounded,
                    tooltip: 'Cerrar sesión',
                    onPressed: onLogout),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  const _NavItem({
    required this.label,
    required this.icon,
    required this.selected,
    required this.onTap,
    this.badge,
    this.muted = false,
  });

  final String label;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;
  final int? badge;
  final bool muted;

  @override
  Widget build(BuildContext context) {
    final color = selected
        ? AppColors.primaryText
        : muted
            ? AppColors.textSecondary
            : AppColors.navText;
    return Material(
      color: selected ? AppColors.primarySoft : Colors.transparent,
      borderRadius: BorderRadius.circular(10),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        hoverColor: AppColors.background,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          child: Row(
            children: [
              Icon(icon, size: muted ? 20 : 22, color: color),
              const SizedBox(width: 12),
              Expanded(
                child: Text(label,
                    style: appText(
                      size: 14,
                      weight: selected ? FontWeight.w600 : FontWeight.w500,
                      color: color,
                    )),
              ),
              if (badge != null)
                Tooltip(
                  message: '$badge con stock bajo',
                  child: Pill(
                    text: '$badge',
                    background: AppColors.warningSoft,
                    foreground: AppColors.warning,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
