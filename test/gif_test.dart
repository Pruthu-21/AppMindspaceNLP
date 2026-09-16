import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('inspect gif', () async {
    final bytes = await File('assets/download.gif').readAsBytes();
    final codec = await ui.instantiateImageCodec(bytes);
    print('Frame count: ${codec.frameCount}');
    int totalDuration = 0;
    for (int i = 0; i < codec.frameCount; i++) {
      final frame = await codec.getNextFrame();
      print('Frame $i duration: ${frame.duration.inMilliseconds}ms');
      totalDuration += frame.duration.inMilliseconds;
    }
    print('Total duration: ${totalDuration}ms');
  });
}
