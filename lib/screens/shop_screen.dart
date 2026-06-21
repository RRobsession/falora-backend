import 'package:falora/config/manual_fortune_config.dart';
import 'package:falora/config/play_product_catalog.dart';
import 'package:falora/services/billing_backend_service.dart';
import 'package:falora/services/play_billing_service.dart';
import 'package:falora/theme/falora_theme.dart';
import 'package:falora/token_config.dart';
import 'package:falora/widgets/live_token_builder.dart';
import 'package:falora/widgets/premium_ui.dart';
import 'package:flutter/material.dart';
import 'package:in_app_purchase/in_app_purchase.dart';

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
  final Map<String, ProductDetails> _productsById = {};
  bool _loadingProducts = true;
  bool _restoring = false;
  String? _loadError;
  String? _activeProductId;

  @override
  void initState() {
    super.initState();
    _loadProducts();
  }

  Future<void> _loadProducts() async {
    setState(() {
      _loadingProducts = true;
      _loadError = null;
    });

    try {
      final products = await PlayBillingService.instance.queryProducts(tokenProductIds);
      if (!mounted) return;
      setState(() {
        _productsById
          ..clear()
          ..addEntries(products.map((item) => MapEntry(item.id, item)));
        _loadingProducts = false;
      });
    } on PlayBillingException catch (e) {
      if (!mounted) return;
      setState(() {
        _loadError = e.message;
        _loadingProducts = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loadError = 'Ürünler yüklenemedi: $e';
        _loadingProducts = false;
      });
    }
  }

  Future<void> _buy(TokenProductDefinition product) async {
    if (_activeProductId != null || _restoring) return;
    setState(() => _activeProductId = product.productId);
    try {
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
    } on PlayBillingException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.message)),
      );
    } on BillingBackendException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.message)),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Satın alma başarısız: $e')),
      );
    } finally {
      if (mounted) {
        setState(() => _activeProductId = null);
      }
    }
  }

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
          ? 'Restore tamamlandı. İşlenen satın alma: $totalProcessed'
          : 'Restore edilecek yeni satın alma bulunamadı.';
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
    } on PlayBillingException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.message)),
      );
    } on BillingBackendException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.message)),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Restore başarısız: $e')),
      );
    } finally {
      if (mounted) {
        setState(() => _restoring = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Jeton Mağazası')),
      body: FaloraBackground(
        child: LiveTokenBuilder(
          builder: (context, tokens) {
            return ListView(
              padding: const EdgeInsets.fromLTRB(22, 12, 22, 32),
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(24),
                  child: Container(
                    padding: const EdgeInsets.all(22),
                    decoration: faloraGlassDecoration(radius: 24, opacity: 0.16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Premium Jeton Mağazası',
                          style: TextStyle(
                            color: faloraGold.withValues(alpha: 0.95),
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 1.2,
                          ),
                        ),
                        const SizedBox(height: 16),
                        PremiumTokenBalanceCard(tokens: tokens, compact: true),
                        const SizedBox(height: 14),
                        Text(
                          '50, 100, 150 ve 1500 jeton paketleri mevcut. '
                          'Özel yorumlar (Serdar/Hatice) $manualFortuneTokenCost jeton; '
                          'AI fallar falcıya göre 50–150 jeton; çift uyumu $coupleTokenCost jeton harcar.',
                          style: TextStyle(
                            color: faloraTextSecondary.withValues(alpha: 0.92),
                            fontSize: 13,
                            height: 1.45,
                          ),
                        ),
                        const SizedBox(height: 10),
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                'Google Play Billing aktif. Test alımları için internal testing hesabı kullanın.',
                                style: TextStyle(
                                  color: faloraTextSecondary.withValues(alpha: 0.82),
                                  fontSize: 12,
                                  height: 1.4,
                                ),
                              ),
                            ),
                            TextButton(
                              onPressed: _restoring ? null : _restore,
                              child: _restoring
                                  ? const SizedBox(
                                      height: 16,
                                      width: 16,
                                      child: CircularProgressIndicator(strokeWidth: 2),
                                    )
                                  : const Text('Restore'),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 28),
                if (_loadingProducts)
                  const Center(child: CircularProgressIndicator())
                else if (_loadError != null) ...[
                  Text(
                    _loadError!,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: faloraTextSecondary.withValues(alpha: 0.8),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Center(
                    child: OutlinedButton(
                      onPressed: _loadProducts,
                      child: const Text('Tekrar Dene'),
                    ),
                  ),
                ] else
                  ...shopPackageCatalog.map(
                    (pkg) => Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: ShopPackageCard(
                        tokens: pkg.tokens,
                        priceLabel:
                            _productsById[pkg.productId]?.price ?? 'Google Play fiyatı',
                        badge: pkg.badge,
                        highlight: pkg.highlight,
                        onBuy: _activeProductId == pkg.productId
                            ? () {}
                            : () => _buy(pkg),
                      ),
                    ),
                  ),
              ],
            );
          },
        ),
      ),
    );
  }
}


