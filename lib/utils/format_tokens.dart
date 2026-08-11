import 'package:intl/intl.dart';

final NumberFormat _trTokenFormat = NumberFormat.decimalPattern('tr');

/// Jeton miktarını Türkçe binlik ayırıcı ile gösterir: 10000 → 10.000
String formatTokenAmount(num value) => _trTokenFormat.format(value);
