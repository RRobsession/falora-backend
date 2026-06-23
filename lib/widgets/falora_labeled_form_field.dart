import 'package:falora/theme/falora_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Parşömen temalı, label üstte sabit fal form alanı.
class FaloraLabeledFormField extends StatelessWidget {
  const FaloraLabeledFormField({
    super.key,
    required this.label,
    required this.controller,
    this.hintText,
    this.keyboardType,
    this.textInputAction,
    this.inputFormatters,
    this.validator,
    this.maxLines = 1,
    this.enabled = true,
    this.onFieldSubmitted,
  });

  final String label;
  final TextEditingController controller;
  final String? hintText;
  final TextInputType? keyboardType;
  final TextInputAction? textInputAction;
  final List<TextInputFormatter>? inputFormatters;
  final String? Function(String?)? validator;
  final int maxLines;
  final bool enabled;
  final ValueChanged<String>? onFieldSubmitted;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          label,
          style: FaloraTypography.labelLarge.copyWith(
            color: faloraInkHeading,
            fontWeight: FontWeight.w700,
            fontSize: 13,
          ),
        ),
        const SizedBox(height: 8),
        TextFormField(
          controller: controller,
          enabled: enabled,
          keyboardType: keyboardType,
          textInputAction: textInputAction,
          inputFormatters: inputFormatters,
          maxLines: maxLines,
          validator: validator,
          onFieldSubmitted: onFieldSubmitted,
          style: const TextStyle(
            color: faloraInk,
            fontSize: 15,
            height: 1.35,
          ),
          decoration: InputDecoration(
            hintText: hintText,
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
            errorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(FaloraRadius.md),
              borderSide: const BorderSide(color: Color(0xFF8B3A3A)),
            ),
          ),
        ),
      ],
    );
  }
}

/// Label üstte sabit dropdown.
class FaloraLabeledDropdown<T> extends StatelessWidget {
  const FaloraLabeledDropdown({
    super.key,
    required this.label,
    required this.value,
    required this.items,
    required this.onChanged,
    this.enabled = true,
  });

  final String label;
  final T value;
  final List<DropdownMenuItem<T>> items;
  final ValueChanged<T?>? onChanged;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          label,
          style: FaloraTypography.labelLarge.copyWith(
            color: faloraInkHeading,
            fontWeight: FontWeight.w700,
            fontSize: 13,
          ),
        ),
        const SizedBox(height: 8),
        DropdownButtonFormField<T>(
          initialValue: value,
          items: items,
          onChanged: enabled ? onChanged : null,
          isExpanded: true,
          decoration: InputDecoration(
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
          dropdownColor: faloraParchmentCard,
          style: const TextStyle(color: faloraInk, fontSize: 15),
        ),
      ],
    );
  }
}
