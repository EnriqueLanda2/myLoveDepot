import 'dart:async';
import 'dart:js_interop';
import 'dart:js_interop_unsafe';

final _streamController = StreamController<bool>.broadcast();
bool _initialized = false;

void _ensureInitialized() {
  if (_initialized) return;
  _initialized = true;

  try {
    final onAvailable = ((JSAny? _) {
      _streamController.add(true);
    }).toJS;

    final onFinished = ((JSAny? _) {
      _streamController.add(false);
    }).toJS;

    globalContext.callMethod('addEventListener'.toJS, 'pwaInstallAvailable'.toJS, onAvailable);
    globalContext.callMethod('addEventListener'.toJS, 'pwaInstallFinished'.toJS, onFinished);
  } catch (_) {}
}

Future<String> resolveModelUrlImpl(String url) async {
  if (url.isEmpty || !url.startsWith('http')) return url;
  try {
    if (globalContext.has('getModelBlobUrl')) {
      final promise = globalContext.callMethod<JSPromise<JSString>>(
        'getModelBlobUrl'.toJS,
        url.toJS,
      );
      final result = await promise.toDart;
      return result.toDart;
    }
  } catch (_) {}
  return url;
}

bool isPwaInstallAvailableImpl() {
  _ensureInitialized();
  try {
    if (globalContext.has('pwaCanInstall')) {
      final val = globalContext.getProperty<JSBoolean?>('pwaCanInstall'.toJS);
      return val?.toDart == true;
    }
  } catch (_) {}
  return false;
}

Future<bool> triggerPwaInstallImpl() async {
  try {
    if (globalContext.has('triggerPwaInstall')) {
      final promise = globalContext.callMethod<JSPromise<JSBoolean>>(
        'triggerPwaInstall'.toJS,
      );
      final result = await promise.toDart;
      return result.toDart;
    }
  } catch (_) {}
  return false;
}

Stream<bool> get pwaInstallStreamImpl {
  _ensureInitialized();
  return _streamController.stream;
}
