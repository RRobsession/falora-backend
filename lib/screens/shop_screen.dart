import 'package:falora/config/play_product_catalog.dart';
import 'package:falora/services/billing_backend_service.dart';
import 'package:falora/services/play_billing_service.dart';
import 'package:falora/services/token_service.dart';
import 'package:falora/theme/falora_theme.dart';
import 'package:falora/token_config.dart';
import 'package:falora/widgets/live_token_builder.dart';
import 'package:falora/widgets/premium_ui.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

class ShopScreen extends StatefulWidget {
  const ShopScreen({
    super.key,
    required this.userId,
  });

  final String userId;

  @override
  State<ShopScreen> createState() => _ShopScreenState();
}

class _ShopScreenState extends State<ShopScreen> {
  final Map<String, String> _priceByProductId = {};
  bool _loadingProducts = true;
  bool _productsReady = false;
  bool _restoring = false;
  String? _activeProductId;

  @override
  void initState() {
    super.initState();
    if (kIsWeb) {
      _loadWebMockPrices();
    } else {
      _loadProducts();
    }
  }

  /// Web'de Play Billing yok — mock fiyatları anında uygula (skeleton yok).
  void _loadWebMockPrices() {
    debugPrint('SHOP_LOAD_START (web mock)');
    final prices = <String, String>{};
    for (final id in tokenProductIds) {
      final mock = mockPriceForProductId(id);
      if (mock != null) {
        prices[id] = mock;
      }
    }
    _logProductResults(prices);
    setState(() {
      _priceByProductId
        ..clear()
        ..addAll(prices);
      _loadingProducts = false;
      _productsReady = prices.isNotEmpty;
    });
    debugPrint('SHOP_LOAD_COMPLETE (web mock)');
  }

  void _showLoadErrorSnackBar() {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Ürünler şu anda yüklenemiyor.'),
      ),
    );
  }

  void _logProductResults(Map<String, String> prices) {
    final foundIds = prices.keys.toList()..sort();
    debugPrint('SHOP_PRODUCTS_FOUND: ${foundIds.join(', ')}');
    debugPrint('SHOP_PRODUCTS_COUNT: ${prices.length}');
    for (final id in tokenProductIds) {
      final price = prices[id];
      if (price == null || price.isEmpty) {
        debugPrint('SHOP_PRODUCT: $id MISSING');
      } else {
        debugPrint('SHOP_PRODUCT: $id FOUND price=$price');
      }
    }
  }

  Future<void> _loadProducts() async {
    debugPrint('SHOP_LOAD_START');
    setState(() {
      _loadingProducts = true;
      _productsReady = false;
      _priceByProductId.clear();
    });

    try {
      final prices = await PlayBillingService.instance
          .queryProductPrices(tokenProductIds);
      if (!mounted) return;

      _logProductResults(prices);

      if (prices.isEmpty) {
        debugPrint('SHOP_LOAD_ERROR: no prices returned');
        setState(() => _loadingProducts = false);
        if (!kIsWeb) {
          _showLoadErrorSnackBar();
        }
        debugPrint('SHOP_LOAD_COMPLETE (empty)');
        return;
      }

      setState(() {
        _priceByProductId
          ..clear()
          ..addAll(prices);
        _loadingProducts = false;
        _productsReady = true;
      });
      debugPrint('SHOP_LOAD_COMPLETE');
    } on PlayBillingException catch (e) {
      debugPrint('SHOP_LOAD_ERROR: $e');
      if (!mounted) return;
      setState(() => _loadingProducts = false);
      if (!kIsWeb) {
        _showLoadErrorSnackBar();
      }
      debugPrint('SHOP_LOAD_COMPLETE (error)');
    } catch (e) {
      debugPrint('SHOP_LOAD_ERROR: $e');
      if (!mounted) return;
      setState(() => _loadingProducts = false);
      if (!kIsWeb) {
        _showLoadErrorSnackBar();
      }
      debugPrint('SHOP_LOAD_COMPLETE (error)');
    }
  }

  Future<void> _buy(TokenProductDefinition product) async {
    if (_activeProductId != null || _restoring) return;
    setState(() => _activeProductId = product.productId);

    try {
      if (kIsWeb) {
        if (kDebugMode) {
          await TokenService.instance.mockPurchase(
            widget.userId,
            product.tokens,
          );
          if (!mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                '${product.tokens} jeton hesabına eklendi (önizleme).',
              ),
            ),
          );
        } else {
          if (!mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                'Satın alma yalnızca Android uygulamasında kullanılabilir.',
              ),
            ),
          );
        }
        return;
      }

      final purchase = await PlayBillingService.instance.buyConsumable(
        product.productId,
      );
      final result = await BillingBackendService.instance.completeTokenPurchase(
        purchase: purchase,
        userId: widget.userId,
      );
      if (!mounted) return;
      final message = result.alreadyProcessed
          ? 'Bu satın alma daha önce işlenmiş.'
          : '${result.tokensGranted} jeton hesabına eklendi.';
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
    } on PlayBillingException catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Satın alma tamamlanamadı. Lütfen tekrar deneyin.'),
        ),
      );
    } on BillingBackendException catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Satın alma doğrulanamadı. Lütfen tekrar deneyin.'),
        ),
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Satın alma tamamlanamadı. Lütfen tekrar deneyin.'),
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _activeProductId = null);
      }
    }
  }

  // UI gizli; ileride Play restore akışı için saklanıyor.
  // ignore: unused_element
  Future<void> _restore() async {
    if (_activeProductId != null || _restoring) return;
    setState(() => _restoring = true);
    try {
      final purchases = await PlayBillingService.instance.restorePurchases();
      var processed = 0;
      for (final purchase in purchases) {
        if (!tokenProductIds.contains(purchase.productId)) continue;
        final result = await BillingBackendService.instance.completeTokenPurchase(
          purchase: purchase,
          userId: widget.userId,
        );
        if (result.alreadyProcessed || result.tokensGranted > 0) {
          processed++;
        }
      }
      final summary = await BillingBackendService.instance.restoreHistory();
      if (!mounted) return;
      final totalProcessed = processed > 0 ? processed : summary.processedCount;
      final message = totalProcessed > 0
          ? 'Satın almalarınız geri yüklendi.'
          : 'Geri yüklenecek yeni satın alma bulunamadı.';
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
    } on PlayBillingException catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Satın almalar geri yüklenemedi. Lütfen tekrar deneyin.'),
        ),
      );
    } on BillingBackendException catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Satın almalar geri yüklenemedi. Lütfen tekrar deneyin.'),
        ),
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Satın almalar geri yüklenemedi. Lütfen tekrar deneyin.'),
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _restoring = false);
      }
    }
  }

  Widget _buildHeader(int tokens) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(24),
      child: Container(
        padding: const EdgeInsets.all(22),
        decoration: faloraGlassDecoration(radius: 24, opacity: 0.16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Premium Jeton Mağazası',
              style: FaloraTypography.sectionHeading.copyWith(
                fontSize: 13,
                letterSpacing: 1.2,
              ),
            ),
            const SizedBox(height: 16),
            PremiumTokenBalanceCard(tokens: tokens, compact: true),
            const SizedBox(height: 14),
            Text(
              kIsWeb
                  ? 'Web önizlemesinde örnek fiyatlar gösterilir. '
                      'Gerçek satın alma Android uygulamasındadır.'
                  : 'Jetonlarınızı özel yorumlar ve uygulama içi '
                      'deneyimler için kullanabilirsiniz.',
              style: TextStyle(
                color: faloraTextSecondary.withValues(alpha: 0.92),
                fontSize: 13,
                height: 1.45,
              ),
            ),
          ],
        ),
      ),
    );
  }

  List<Widget> _buildProductCards() {
    return shopPackageCatalog
        .where((pkg) {
          final price = _priceByProductId[pkg.productId];
          return price != null && price.isNotEmpty;
        })
        .map((pkg) {
          final price = _priceByProductId[pkg.productId]!;
          final isPurchasing = _activeProductId == pkg.productId;

          return Padding(
            padding: const EdgeInsets.only(bottom: 14),
            child: ShopPackageCard(
              tokens: pkg.tokens,
              subtitle: pkg.subtitle,
              badge: pkg.badge,
              highlight: pkg.highlight,
              price: price,
              isPurchasing: isPurchasing,
              onBuy: () => _buy(pkg),
            ),
          );
        })
        .toList();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Jeton Mağazası'),
        actions: [
          IconButton(
            tooltip: 'Yenile',
            onPressed: _loadingProducts ? null : _loadProducts,
            icon: const Icon(Icons.refresh_rounded),
          ),
        ],
      ),
      body: FaloraBackground(
        child: LiveTokenBuilder(
          builder: (context, tokens) {
            if (_loadingProducts) {
              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(22, 12, 22, 0),
                    child: _buildHeader(tokens),
                  ),
                  const SizedBox(height: 24),
                  const Expanded(
                    child: Padding(
                      padding: EdgeInsets.symmetric(horizontal: 22),
                      child: ShopProductsSkeleton(),
                    ),
                  ),
                ],
              );
            }

            return ListView(
              padding: const EdgeInsets.fromLTRB(22, 12, 22, 32),
              children: [
                _buildHeader(tokens),
                if (_productsReady) ...[
                  const SizedBox(height: 24),
                  ..._buildProductCards(),
                ],
              ],
            );
          },
        ),
      ),
    );
  }
}
