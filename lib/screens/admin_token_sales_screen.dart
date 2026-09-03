import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:falora/theme/falora_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';

class AdminTokenSalesScreen extends StatefulWidget {
  const AdminTokenSalesScreen({super.key});

  @override
  State<AdminTokenSalesScreen> createState() => _AdminTokenSalesScreenState();
}

class _AdminTokenSalesScreenState extends State<AdminTokenSalesScreen> {
  final _searchController = TextEditingController();
  String? _orderId;

  Query<Map<String, dynamic>> get _query {
    final collection = FirebaseFirestore.instance.collection('play_purchases');
    if (_orderId != null) {
      return collection.where('orderId', isEqualTo: _orderId).limit(20);
    }
    return collection.orderBy('purchaseTime', descending: true).limit(100);
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _search() {
    final value = _searchController.text.trim();
    setState(() => _orderId = value.isEmpty ? null : value);
  }

  String _money(Map<String, dynamic> data) {
    final price = (data['price'] as num?)?.toDouble();
    final currency = data['currencyCode']?.toString();
    if (price == null || currency == null || currency.isEmpty) return '—';
    try {
      return NumberFormat.simpleCurrency(name: currency).format(price);
    } catch (_) {
      return '${price.toStringAsFixed(2)} $currency';
    }
  }

  DateTime? _purchaseDate(Map<String, dynamic> data) {
    final timestamp = data['purchaseTime'];
    if (timestamp is Timestamp) return timestamp.toDate().toLocal();
    final millis = (data['purchaseTimeMillis'] as num?)?.toInt();
    return millis == null
        ? null
        : DateTime.fromMillisecondsSinceEpoch(millis).toLocal();
  }

  Future<void> _copyOrderId(String orderId) async {
    await Clipboard.setData(ClipboardData(text: orderId));
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('GPA sipariş kimliği kopyalandı.')),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Jeton Satışları')),
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
              child: TextField(
                controller: _searchController,
                textInputAction: TextInputAction.search,
                onSubmitted: (_) => _search(),
                decoration: InputDecoration(
                  labelText: 'GPA sipariş kimliği',
                  hintText: 'GPA.3319-2729-3899-48402',
                  prefixIcon: const Icon(Icons.search),
                  suffixIcon: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (_orderId != null)
                        IconButton(
                          tooltip: 'Aramayı temizle',
                          onPressed: () {
                            _searchController.clear();
                            _search();
                          },
                          icon: const Icon(Icons.close),
                        ),
                      IconButton(
                        tooltip: 'Ara',
                        onPressed: _search,
                        icon: const Icon(Icons.arrow_forward),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            Expanded(
              child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                stream: _query.snapshots(),
                builder: (context, snapshot) {
                  if (snapshot.hasError) {
                    return Center(
                      child: Text('Satışlar yüklenemedi: ${snapshot.error}'),
                    );
                  }
                  if (!snapshot.hasData) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  final docs = snapshot.data!.docs.toList()
                    ..sort((a, b) {
                      final aDate = _purchaseDate(a.data());
                      final bDate = _purchaseDate(b.data());
                      return (bDate?.millisecondsSinceEpoch ?? 0).compareTo(
                        aDate?.millisecondsSinceEpoch ?? 0,
                      );
                    });
                  if (docs.isEmpty) {
                    return const Center(child: Text('Satış kaydı bulunamadı.'));
                  }
                  return ListView.separated(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                    itemCount: docs.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 10),
                    itemBuilder: (context, index) {
                      final data = docs[index].data();
                      final date = _purchaseDate(data);
                      final orderId = data['orderId']?.toString() ?? '';
                      final user = data['userEmail']?.toString().trim();
                      return Card(
                        child: Padding(
                          padding: const EdgeInsets.all(14),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Expanded(
                                    child: Text(
                                      data['displayPackageName']?.toString() ??
                                          data['productId']?.toString() ??
                                          'Bilinmeyen paket',
                                      style: const TextStyle(
                                        fontWeight: FontWeight.w700,
                                        color: faloraInkHeading,
                                      ),
                                    ),
                                  ),
                                  Text(
                                    _money(data),
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 8),
                              Text(
                                'Tarih: ${date == null ? '—' : DateFormat('dd.MM.yyyy').format(date)}',
                              ),
                              Text(
                                'Saat: ${date == null ? '—' : DateFormat('HH:mm:ss').format(date)}',
                              ),
                              Text(
                                'Kullanıcı: ${user?.isNotEmpty == true ? user : data['userId'] ?? data['uid'] ?? '—'}',
                              ),
                              Text(
                                'Jeton miktarı: ${data['tokensGranted'] ?? 0}',
                              ),
                              const SizedBox(height: 8),
                              Row(
                                children: [
                                  Expanded(
                                    child: SelectableText(
                                      orderId.isEmpty
                                          ? 'GPA kimliği yok'
                                          : orderId,
                                      style: const TextStyle(
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ),
                                  TextButton.icon(
                                    onPressed: orderId.isEmpty
                                        ? null
                                        : () => _copyOrderId(orderId),
                                    icon: const Icon(Icons.copy, size: 18),
                                    label: const Text('Kopyala'),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
