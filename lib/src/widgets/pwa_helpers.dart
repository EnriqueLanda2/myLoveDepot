import 'pwa_helpers_stub.dart' if (dart.library.html) 'pwa_helpers_web.dart';

/// Fachada unificada para soporte de almacenamiento IndexedDB y PWA en Flutter.
class PwaHelpers {
  /// Obtiene la URL de objeto blob desde IndexedDB si ya está almacenada,
  /// o la descarga, almacena en IndexedDB y retorna la URL local instantánea.
  static Future<String> resolveModelUrl(String url) => resolveModelUrlImpl(url);

  /// Comprueba si la PWA puede ser instalada en el navegador actual.
  static bool isPwaInstallAvailable() => isPwaInstallAvailableImpl();

  /// Despliega el diálogo nativo de instalación de la PWA.
  static Future<bool> triggerPwaInstall() => triggerPwaInstallImpl();

  /// Flujo de eventos reactivos que notifica cambios en la disponibilidad de instalación.
  static Stream<bool> get pwaInstallStream => pwaInstallStreamImpl;
}
