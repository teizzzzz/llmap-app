/// ブラウザの位置情報を直接読む（Web 試用版）。端末アプリでは使わない（null を返す）。
library;

export 'geo_stub.dart' if (dart.library.js_interop) 'geo_web.dart';
