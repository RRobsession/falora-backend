import 'package:flutter/material.dart';

// ─── Parşömen arka plan ─────────────────────────────────────────────────────

const faloraParchmentLight = Color(0xFFE2D0A8);
const faloraParchmentMid = Color(0xFFD8C39A);
const faloraParchmentDeep = Color(0xFFCDB387);

// ─── Bronz / ahşap ikincil ──────────────────────────────────────────────────

const faloraBronze = Color(0xFF8B6A3E);
const faloraBronzeDark = Color(0xFF6B4F2A);

// ─── Altın vurgu ────────────────────────────────────────────────────────────

const faloraGold = Color(0xFFD4AF37);
const faloraGoldDark = Color(0xFFB8860B);
const faloraGoldMuted = Color(0xFFC9A227);

// ─── Mürekkep metin ─────────────────────────────────────────────────────────

const faloraInk = Color(0xFF2E2115);
const faloraInkSoft = Color(0xFF4A3422);
const faloraInkMuted = Color(0xFF6B5340);

/// Parşömen üzerinde okunabilir metin — açık altın (#D4AF37) yerine bunları kullan.
const faloraInkHeading = Color(0xFF5A3A18);
const faloraInkBodyDark = Color(0xFF3A2A1A);
const faloraGoldReadable = Color(0xFF6B4F0A);

/// Progress / uyum göstergeleri — parşömen üzerinde.
const faloraProgressFill = Color(0xFF8B5E24);
const faloraProgressTrack = Color(0xFFD8C39A);

// ─── Yüzeyler (parşömen katmanları) ─────────────────────────────────────────

const faloraParchmentCard = Color(0xFFEBDDB8);
const faloraParchmentRaised = Color(0xFFF0E4C4);
const faloraParchmentInset = Color(0xFFD9C89E);

// ─── Geriye dönük uyumluluk (eski API adları) ───────────────────────────────

const faloraBg = faloraParchmentMid;
const faloraSurface = faloraParchmentCard;
const faloraCard = faloraParchmentRaised;
const faloraAccent = faloraBronze;
const faloraNightBlue = faloraBronzeDark;
const faloraTextPrimary = faloraInk;
const faloraTextSecondary = faloraInkSoft;

// ─── Spacing & radius ───────────────────────────────────────────────────────

abstract final class FaloraSpacing {
  static const double xs = 6;
  static const double sm = 10;
  static const double md = 16;
  static const double lg = 22;
  static const double xl = 28;
  static const double xxl = 36;
}

abstract final class FaloraRadius {
  static const double sm = 10;
  static const double md = 14;
  static const double lg = 18;
  static const double xl = 22;
  static const double sheet = 26;
}

// ─── Tipografi ──────────────────────────────────────────────────────────────

abstract final class FaloraTypography {
  /// Başlıklar — antik kitap hissi (platform serif).
  static const String displayFamily = 'Georgia';
  static const String bodyFamily = 'Georgia';

  static const TextStyle displayLarge = TextStyle(
    fontFamily: displayFamily,
    fontSize: 28,
    fontWeight: FontWeight.w700,
    height: 1.2,
    letterSpacing: 0.4,
    color: faloraInk,
  );

  static const TextStyle displayMedium = TextStyle(
    fontFamily: displayFamily,
    fontSize: 22,
    fontWeight: FontWeight.w700,
    height: 1.25,
    letterSpacing: 0.3,
    color: faloraInk,
  );

  static const TextStyle titleLarge = TextStyle(
    fontFamily: displayFamily,
    fontSize: 18,
    fontWeight: FontWeight.w600,
    height: 1.3,
    letterSpacing: 0.25,
    color: faloraInk,
  );

  static const TextStyle titleMedium = TextStyle(
    fontFamily: displayFamily,
    fontSize: 15,
    fontWeight: FontWeight.w600,
    height: 1.35,
    letterSpacing: 0.2,
    color: faloraInk,
  );

  static const TextStyle bodyLarge = TextStyle(
    fontFamily: bodyFamily,
    fontSize: 16,
    fontWeight: FontWeight.w400,
    height: 1.55,
    color: faloraInkSoft,
  );

  static const TextStyle bodyMedium = TextStyle(
    fontFamily: bodyFamily,
    fontSize: 14,
    fontWeight: FontWeight.w400,
    height: 1.5,
    color: faloraInkSoft,
  );

  static const TextStyle labelLarge = TextStyle(
    fontFamily: bodyFamily,
    fontSize: 13,
    fontWeight: FontWeight.w600,
    height: 1.3,
    letterSpacing: 0.6,
    color: faloraBronzeDark,
  );

  static const TextStyle labelSmall = TextStyle(
    fontFamily: bodyFamily,
    fontSize: 11,
    fontWeight: FontWeight.w600,
    height: 1.2,
    letterSpacing: 0.8,
    color: faloraInkMuted,
  );

  static const TextStyle goldAccent = TextStyle(
    fontFamily: displayFamily,
    fontSize: 14,
    fontWeight: FontWeight.w700,
    letterSpacing: 0.5,
    color: faloraGoldReadable,
  );

  /// Bölüm başlıkları — parşömen üzerinde yüksek kontrast.
  static const TextStyle sectionHeading = TextStyle(
    fontFamily: displayFamily,
    fontSize: 15,
    fontWeight: FontWeight.w700,
    height: 1.3,
    letterSpacing: 0.2,
    color: faloraInkHeading,
  );

  /// Gövde metni — parşömen üzerinde.
  static const TextStyle bodyOnParchment = TextStyle(
    fontFamily: bodyFamily,
    fontSize: 14,
    fontWeight: FontWeight.w400,
    height: 1.55,
    color: faloraInkBodyDark,
  );

  /// Davet kodu, vurgulu rakamlar — koyu altın.
  static const TextStyle goldReadable = TextStyle(
    fontFamily: displayFamily,
    fontWeight: FontWeight.w800,
    color: faloraGoldReadable,
    letterSpacing: 0.5,
  );
}

// ─── Durum mühürleri (soluk, dikkat dağıtmayan) ─────────────────────────────

const faloraSealReadyBg = Color(0xFFD4D0B0);
const faloraSealReadyInk = Color(0xFF4A5C38);
const faloraSealPreparingBg = Color(0xFFDDD0B0);
const faloraSealPreparingInk = Color(0xFF75624A);
const faloraSealPendingBg = Color(0xFFD6C8A8);
const faloraSealPendingInk = Color(0xFF6B5340);
const faloraSealErrorBg = Color(0xFFE8C8C0);
const faloraSealErrorInk = Color(0xFF8B4A40);

// ─── Tarot masası (sıcak ahşap — mor ton yok) ───────────────────────────────

const faloraTarotTable = Color(0xFF5C4228);
const faloraTarotTableLight = Color(0xFF6B4F2A);
const faloraTarotFelt = Color(0xFF4A3520);


Color faloraCategoryAccent(String categoryLabel) {
  switch (categoryLabel) {
    case 'Tarot':
      return faloraBronzeDark;
    case 'Rüya Tabiri':
      return const Color(0xFF5C4A6E);
    case 'Numeroloji':
      return faloraGoldDark;
    case 'Burç Yorumu':
      return const Color(0xFF7A5C3E);
    case 'Çift Uyumu':
      return const Color(0xFF8B4A5C);
    default:
      return faloraBronze;
  }
}
