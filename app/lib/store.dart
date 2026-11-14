/// ローカル永続化層の入口。端末（iOS / Android / デスクトップ）はファイル、
/// Web 試用版はブラウザ内（IndexedDB）に保存する。呼び出し側は同じ API を使う。
library;

export 'store_common.dart';
export 'store_io.dart' if (dart.library.js_interop) 'store_web.dart';
