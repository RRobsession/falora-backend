import 'package:falora/config/play_product_catalog.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('Android legacy product IDs grant the advertised token amounts', () {
    final products = {
      for (final product in androidTokenProductCatalog)
        product.productId: product,
    };

    expect(products['tokens_150']?.tokens, 500);
    expect(products['tokens_200']?.tokens, 1000);
  });

  test('iOS product amounts are unchanged', () {
    final products = {
      for (final product in iosTokenProductCatalog)
        product.productId: product,
    };

    expect(products['tokens_150']?.tokens, 150);
    expect(products['tokens_500']?.tokens, 500);
    expect(products['tokens_1000']?.tokens, 1000);
  });
}
