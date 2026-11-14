import 'dart:async';
import 'dart:js_interop';

import 'package:web/web.dart' as web;

/// navigator.geolocation を直接呼ぶ。まず高精度（GPS）で試し、だめなら
/// 低精度（Wi-Fi・基地局）でもう一度。許可されない・HTTPS でない場合は null。
Future<({double lat, double lng})?> browserGps() async {
  final first = await _once(highAccuracy: true, timeoutMs: 15000, maxAgeMs: 0);
  if (first != null) return first;
  return _once(highAccuracy: false, timeoutMs: 10000, maxAgeMs: 120000);
}

Future<({double lat, double lng})?> _once({
  required bool highAccuracy,
  required int timeoutMs,
  required int maxAgeMs,
}) {
  final done = Completer<({double lat, double lng})?>();
  try {
    web.window.navigator.geolocation.getCurrentPosition(
      ((web.GeolocationPosition p) {
        if (!done.isCompleted) {
          done.complete((lat: p.coords.latitude, lng: p.coords.longitude));
        }
      }).toJS,
      ((web.GeolocationPositionError e) {
        if (!done.isCompleted) done.complete(null);
      }).toJS,
      web.PositionOptions(
        enableHighAccuracy: highAccuracy,
        timeout: timeoutMs,
        maximumAge: maxAgeMs,
      ),
    );
  } catch (_) {
    if (!done.isCompleted) done.complete(null);
  }
  // コールバックが呼ばれない環境に備えて、こちらでも時間切れにする。
  return done.future
      .timeout(Duration(milliseconds: timeoutMs + 2000), onTimeout: () => null);
}
