import 'dart:typed_data';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  for (final asset in [
    'assets/grab3d-cozy-character.glb',
    'assets/grab3d-cozy-character-girl.glb',
  ]) {
    test('$asset is bundled as a valid GLB', () async {
      final data = await rootBundle.load(asset);

      expect(data.lengthInBytes, greaterThanOrEqualTo(12));
      expect(data.getUint32(0, Endian.little), 0x46546c67);
      expect(data.getUint32(4, Endian.little), 2);
      expect(data.getUint32(8, Endian.little), data.lengthInBytes);
    });
  }
}
