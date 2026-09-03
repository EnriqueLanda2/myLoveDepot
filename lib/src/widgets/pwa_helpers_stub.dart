import 'dart:async';

Future<String> resolveModelUrlImpl(String url) async => url;

bool isPwaInstallAvailableImpl() => false;

Future<bool> triggerPwaInstallImpl() async => false;

Stream<bool> get pwaInstallStreamImpl => const Stream.empty();
