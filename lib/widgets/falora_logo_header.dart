import 'package:flutter/material.dart';
import 'package:falora/theme/falora_theme.dart';

class FaloraLogoHeader extends StatelessWidget {
  const FaloraLogoHeader({
    super.key,
    this.subtitle,
    this.compact = false,
  });

  final String? subtitle;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          padding: EdgeInsets.all(compact ? 12 : 16),
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: LinearGradient(
              colors: [
                faloraGold.withValues(alpha: 0.25),
                faloraAccent.withValues(alpha: 0.2),
              ],
            ),
            boxShadow: [
              BoxShadow(
                color: faloraAccent.withValues(alpha: 0.25),
                blurRadius: 24,
                spreadRadius: 2,
              ),
            ],
          ),
          child: Icon(
            Icons.auto_awesome,
            color: faloraGoldReadable,
            size: compact ? 32 : 42,
          ),
        ),
        SizedBox(height: compact ? 12 : 18),
        Text(
          'Falora',
          style: TextStyle(
            fontSize: compact ? 28 : 36,
            fontWeight: FontWeight.bold,
            color: faloraTextPrimary,
            letterSpacing: 2,
          ),
        ),
        if (subtitle != null) ...[
          const SizedBox(height: 8),
          Text(
            subtitle!,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: faloraTextSecondary.withValues(alpha: 0.9),
              fontSize: 14,
              height: 1.4,
            ),
          ),
        ],
      ],
    );
  }
}

class AuthCard extends StatelessWidget {
  const AuthCard({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: faloraCard.withValues(alpha: 0.92),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: faloraAccent.withValues(alpha: 0.18)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.35),
            blurRadius: 28,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      child: child,
    );
  }
}
