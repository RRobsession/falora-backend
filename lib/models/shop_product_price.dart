class ShopProductPrice {
  const ShopProductPrice({
    required this.price,
    this.compareAtPrice,
    this.offerToken,
  });

  final String price;
  final String? compareAtPrice;
  final String? offerToken;
}
