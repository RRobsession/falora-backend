/// AI yanıtlarındaki model özel token'larını ve fazla boşlukları temizler.
String sanitizeAiResult(String text) {
  return text
      .replaceAll(RegExp(r'<\|endoftext\|>', caseSensitive: false), '')
      .replaceAll(RegExp(r'<\|end\|>', caseSensitive: false), '')
      .replaceAll(RegExp(r'<\|im_end\|>', caseSensitive: false), '')
      .trim();
}
