/// アプリを最初から始め直す（Web 試用版のリセット用）。端末では何もしない。
library;

export 'reload_stub.dart' if (dart.library.js_interop) 'reload_web.dart';
