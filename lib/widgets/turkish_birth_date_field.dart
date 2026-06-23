import 'package:falora/config/category_fortune_config.dart';
import 'package:falora/theme/falora_theme.dart';
import 'package:falora/utils/profile_age.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';

/// Türkçe doğum tarihi alanı — GG.AA.YYYY yazımı veya date picker.
class TurkishBirthDateField extends StatefulWidget {
  const TurkishBirthDateField({
    super.key,
    this.initialDate,
    required this.onChanged,
    this.enabled = true,
    this.showAgeHint = true,
  });

  final DateTime? initialDate;
  final ValueChanged<DateTime?> onChanged;
  final bool enabled;
  final bool showAgeHint;

  @override
  State<TurkishBirthDateField> createState() => TurkishBirthDateFieldState();
}

class TurkishBirthDateFieldState extends State<TurkishBirthDateField> {
  late final TextEditingController _controller;
  DateTime? _selectedDate;

  static final _displayFormat = DateFormat('dd.MM.yyyy', 'tr_TR');
  static final _inputFormatters = [
    FilteringTextInputFormatter.allow(RegExp(r'[0-9.]')),
    LengthLimitingTextInputFormatter(10),
    _BirthDateMaskFormatter(),
  ];

  @override
  void initState() {
    super.initState();
    _selectedDate = widget.initialDate;
    _controller = TextEditingController(
      text: _selectedDate == null ? '' : _displayFormat.format(_selectedDate!),
    );
  }

  @override
  void didUpdateWidget(covariant TurkishBirthDateField oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.initialDate != oldWidget.initialDate &&
        widget.initialDate != _selectedDate) {
      _selectedDate = widget.initialDate;
      _controller.text = _selectedDate == null
          ? ''
          : _displayFormat.format(_selectedDate!);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  DateTime? get selectedDate => _selectedDate;

  Future<void> _pickDate() async {
    if (!widget.enabled) return;
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      locale: const Locale('tr', 'TR'),
      initialDate: _selectedDate ?? DateTime(now.year - 25, now.month, now.day),
      firstDate: DateTime(1920, 1, 1),
      lastDate: now,
      helpText: 'Doğum tarihi seçin',
      cancelText: 'İptal',
      confirmText: 'Tamam',
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(
              primary: faloraBronze,
              onPrimary: faloraParchmentRaised,
              surface: faloraParchmentCard,
              onSurface: faloraInk,
            ),
          ),
          child: child!,
        );
      },
    );
    if (picked == null) return;
    _applyDate(picked);
  }

  void _applyDate(DateTime date) {
    final normalized = DateTime(date.year, date.month, date.day);
    setState(() {
      _selectedDate = normalized;
      _controller.text = _displayFormat.format(normalized);
    });
    widget.onChanged(normalized);
  }

  void _onTextChanged(String raw) {
    final parsed = parseTurkishBirthDate(raw);
    if (parsed == null) {
      setState(() => _selectedDate = null);
      widget.onChanged(null);
      return;
    }
    if (parsed != _selectedDate) {
      setState(() => _selectedDate = parsed);
      widget.onChanged(parsed);
    }
  }

  String? validate(String? _) {
    if (_selectedDate == null) {
      return 'Geçerli bir doğum tarihi girin';
    }
    return null;
  }

  bool get isValid => validate(null) == null;

  @override
  Widget build(BuildContext context) {
    final age = _selectedDate == null
        ? null
        : calculateAgeFromBirthDate(_selectedDate!);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'Doğum tarihi',
          style: FaloraTypography.labelLarge.copyWith(
            color: faloraInkHeading,
            fontWeight: FontWeight.w700,
            fontSize: 13,
          ),
        ),
        const SizedBox(height: 8),
        TextFormField(
          controller: _controller,
          enabled: widget.enabled,
          keyboardType: TextInputType.datetime,
          inputFormatters: _inputFormatters,
          onChanged: _onTextChanged,
          validator: validate,
          style: const TextStyle(color: faloraInk, fontSize: 15),
          decoration: InputDecoration(
            hintText: 'Doğum tarihinizi seçin',
            suffixIcon: IconButton(
              onPressed: widget.enabled ? _pickDate : null,
              icon: const Icon(Icons.calendar_month_outlined),
              color: faloraBronzeDark,
              tooltip: 'Takvimden seç',
            ),
            filled: true,
            fillColor: faloraParchmentRaised,
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 14,
            ),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(FaloraRadius.md),
              borderSide: BorderSide(
                color: faloraBronze.withValues(alpha: 0.35),
              ),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(FaloraRadius.md),
              borderSide: BorderSide(
                color: faloraBronze.withValues(alpha: 0.35),
              ),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(FaloraRadius.md),
              borderSide: const BorderSide(color: faloraGoldDark, width: 1.5),
            ),
          ),
        ),
        if (widget.showAgeHint && age != null) ...[
          const SizedBox(height: 6),
          Text(
            'Yaş: $age',
            style: FaloraTypography.bodyMedium.copyWith(
              color: faloraInkSoft,
              fontSize: 12,
            ),
          ),
        ],
      ],
    );
  }
}

DateTime? parseTurkishBirthDate(String raw) {
  final trimmed = raw.trim();
  if (trimmed.isEmpty) return null;

  final match = RegExp(r'^(\d{2})\.(\d{2})\.(\d{4})$').firstMatch(trimmed);
  if (match == null) return null;

  final day = int.tryParse(match.group(1)!);
  final month = int.tryParse(match.group(2)!);
  final year = int.tryParse(match.group(3)!);
  if (day == null || month == null || year == null) return null;
  if (year < 1920) return null;

  final now = DateTime.now();
  if (year > now.year) return null;
  if (month < 1 || month > 12) return null;
  if (day < 1 || day > 31) return null;

  late final DateTime date;
  try {
    date = DateTime(year, month, day);
  } catch (_) {
    return null;
  }
  if (date.year != year || date.month != month || date.day != day) {
    return null;
  }
  final today = DateTime(now.year, now.month, now.day);
  if (date.isAfter(today)) return null;
  return date;
}

class _BirthDateMaskFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    final digits = newValue.text.replaceAll(RegExp(r'[^0-9]'), '');
    final buf = StringBuffer();
    for (var i = 0; i < digits.length && i < 8; i++) {
      if (i == 2 || i == 4) buf.write('.');
      buf.write(digits[i]);
    }
    final text = buf.toString();
    return TextEditingValue(
      text: text,
      selection: TextSelection.collapsed(offset: text.length),
    );
  }
}

String formatTurkishBirthDate(DateTime date) => formatBirthDate(date);
