import 'package:falora/theme/falora_theme.dart';
import 'package:falora/utils/profile_age.dart';
import 'package:falora/widgets/turkish_birth_date_field.dart';
import 'package:flutter/material.dart';

/// Kompakt doğum tarihi düzenleme modalı.
Future<DateTime?> showCompactBirthDateDialog(
  BuildContext context, {
  DateTime? initialDate,
}) async {
  final fieldKey = GlobalKey<TurkishBirthDateFieldState>();
  final saved = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: const Text('Doğum Tarihi'),
      contentPadding: const EdgeInsets.fromLTRB(24, 16, 24, 8),
      actionsPadding: const EdgeInsets.fromLTRB(8, 0, 8, 8),
      content: SingleChildScrollView(
        child: TurkishBirthDateField(
          key: fieldKey,
          initialDate: initialDate,
          onChanged: (_) {},
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx, false),
          child: const Text('İptal'),
        ),
        TextButton(
          onPressed: () => Navigator.pop(ctx, true),
          child: const Text('Kaydet'),
        ),
      ],
    ),
  );

  if (saved != true) return null;
  if (!(fieldKey.currentState?.isValid ?? false)) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Geçerli bir doğum tarihi girin')),
      );
    }
    return null;
  }
  return fieldKey.currentState?.selectedDate;
}

/// Onboarding için satır içi kompakt doğum tarihi alanı.
class CompactBirthDateSection extends StatelessWidget {
  const CompactBirthDateSection({
    super.key,
    required this.fieldKey,
    this.initialDate,
    required this.onChanged,
  });

  final GlobalKey<TurkishBirthDateFieldState> fieldKey;
  final DateTime? initialDate;
  final ValueChanged<DateTime?> onChanged;

  @override
  Widget build(BuildContext context) {
    return TurkishBirthDateField(
      key: fieldKey,
      initialDate: initialDate,
      onChanged: onChanged,
    );
  }
}

String? birthDateAgeLabel(DateTime? date) {
  if (date == null) return null;
  final age = calculateAgeFromBirthDate(date);
  return 'Yaş: $age';
}
