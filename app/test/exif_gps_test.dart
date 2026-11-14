import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:llmap_app/capture.dart';

void main() {
  test('写真の EXIF から撮影位置を読む', () {
    final g = exifGps(File('test/fixtures/gps.jpg').readAsBytesSync());
    print('gps -> ${g?.lat}, ${g?.lng}');
    expect(g, isNotNull);
    expect(g!.lat, closeTo(35.7012, 0.0005));
    expect(g.lng, closeTo(139.7002, 0.0005));
  });
}

