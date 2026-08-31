import 'package:falora/token_config.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('new users start without complimentary tokens', () {
    expect(initialUserTokens, 0);
  });
}
