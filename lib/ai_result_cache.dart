/// AI yorumlarını oturum belleğinde önbelleğe alır.
/// Kalıcı sonuçlar Firestore'da saklanır.
class AiResultCache {
  AiResultCache._();

  static final Map<String, String> _memory = {};

  static String _key(String userId, String readingId) =>
      'ai_result_${userId}_$readingId';

  static Future<String?> get(String userId, String readingId) async {
    final memKey = _key(userId, readingId);
    final mem = _memory[memKey];
    if (mem != null && mem.isNotEmpty) return mem;
    return null;
  }

  static Future<void> put(
    String userId,
    String readingId,
    String result,
  ) async {
    if (result.isEmpty) return;
    _memory[_key(userId, readingId)] = result;
  }

  static void clearMemory() => _memory.clear();
}
