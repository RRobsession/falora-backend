import 'package:falora/theme/falora_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Parşömen temalı, label üstte sabit fal form alanı.
class FaloraLabeledFormField extends StatefulWidget {
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
  State<FaloraLabeledFormField> createState() =>
      _FaloraLabeledFormFieldState();
}

class _FaloraLabeledFormFieldState extends State<FaloraLabeledFormField>
    with AutomaticKeepAliveClientMixin {
  final FocusNode _focusNode = FocusNode();

  @override
  void initState() {
    super.initState();
    _focusNode.addListener(_handleFocusChange);
  }

  void _handleFocusChange() => updateKeepAlive();

  @override
  void dispose() {
    _focusNode.removeListener(_handleFocusChange);
    _focusNode.dispose();
    super.dispose();
  }

  @override
  bool get wantKeepAlive => _focusNode.hasFocus;

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          widget.label,
          style: FaloraTypography.labelLarge.copyWith(
            color: faloraInkHeading,
            fontWeight: FontWeight.w700,
            fontSize: 13,
          ),
        ),
        const SizedBox(height: 8),
        TextFormField(
          controller: widget.controller,
          focusNode: _focusNode,
          enabled: widget.enabled,
          keyboardType: widget.keyboardType ??
              (widget.maxLines > 1 ? TextInputType.multiline : null),
          textInputAction: widget.textInputAction ??
              (widget.maxLines > 1 ? TextInputAction.newline : null),
          inputFormatters: widget.inputFormatters,
          maxLines: widget.maxLines,
          validator: widget.validator,
          onFieldSubmitted: widget.onFieldSubmitted,
          style: const TextStyle(
            color: faloraInk,
            fontSize: 15,
            height: 1.35,
          ),
          decoration: InputDecoration(
            hintText: widget.hintText,
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
