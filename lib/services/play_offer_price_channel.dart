import 'package:falora/models/shop_product_price.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// Google Play indirim tekliflerini okur (offerToken + tam/indirimli fiyat).
class PlayOfferPriceChannel {
  PlayOfferPriceChannel._();

  static const _channel = MethodChannel('com.rrlime.falora/play_offers');

  static Future<Map<String, ShopProductPrice>> queryOfferPrices(
    Set<String> productIds,
  ) async {
    if (kIsWeb || productIds.isEmpty) return const {};

    try {
      final raw = await _channel.invokeMethod<Object?>(
        'queryOfferPrices',
        <String, Object>{'productIds': productIds.toList()},
      );
      if (raw is! Map) return const {};

      final prices = <String, ShopProductPrice>{};
      raw.forEach((key, value) {
        if (key is! String || value is! Map) return;
        final price = value['price']?.toString().trim();
        if (price == null || price.isEmpty) return;

        final compareAt = value['compareAtPrice']?.toString().trim();
        final offerToken = value['offerToken']?.toString().trim();

        prices[key] = ShopProductPrice(
          price: price,
          compareAtPrice:
              compareAt != null && compareAt.isNotEmpty ? compareAt : null,
          offerToken:
              offerToken != null && offerToken.isNotEmpty ? offerToken : null,
        );
      });
      return prices;
    } on PlatformException catch (e) {
      debugPrint('PLAY OFFERS channel error: ${e.code} ${e.message}');
      return const {};
    } catch (e) {
      debugPrint('PLAY OFFERS channel error: $e');
      return const {};
    }
  }
}
