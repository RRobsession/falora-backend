import 'package:falora/widgets/google_logo.dart';
import 'package:flutter/material.dart';

/// Google Sign-In marka yönergelerine yakın düğme.
class GoogleSignInButton extends StatelessWidget {
  const GoogleSignInButton({
    super.key,
    required this.onPressed,
    required this.loading,
  });

  final VoidCallback? onPressed;
  final bool loading;

  static const _borderColor = Color(0xFFDADCE0);
  static const _textColor = Color(0xFF3C4043);

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      elevation: 0,
      shape: StadiumBorder(
        side: BorderSide(
          color: onPressed == null ? _borderColor.withValues(alpha: 0.6) : _borderColor,
        ),
      ),
      child: InkWell(
        onTap: loading ? null : onPressed,
        customBorder: const StadiumBorder(),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 13, horizontal: 16),
          child: loading
              ? const Center(
                  child: SizedBox(
                    height: 20,
                    width: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                )
              : Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  mainAxisSize: MainAxisSize.min,
                  children: const [
                    GoogleLogo(size: 20),
                    SizedBox(width: 12),
                    Text(
                      'Google ile devam et',
                      style: TextStyle(
                        color: _textColor,
                        fontWeight: FontWeight.w500,
                        fontSize: 15,
                        letterSpacing: 0.1,
                      ),
                    ),
                  ],
                ),
        ),
      ),
    );
  }
}
