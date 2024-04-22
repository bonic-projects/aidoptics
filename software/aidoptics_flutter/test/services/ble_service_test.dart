import 'package:flutter_test/flutter_test.dart';
import 'package:aidoptics_flutter/app/app.locator.dart';

import '../helpers/test_helpers.dart';

void main() {
  group('BleServiceTest -', () {
    setUp(() => registerServices());
    tearDown(() => locator.reset());
  });
}

