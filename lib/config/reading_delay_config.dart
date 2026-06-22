/// Yorum sonucunun kullanıcıya açılması için minimum bekleme süresi.
const fortuneReadyDelay = Duration(minutes: 3);

DateTime computeReadyAt(DateTime createdAt) => createdAt.add(fortuneReadyDelay);

String formatReadingCountdown(Duration remaining) {
  final totalSeconds = remaining.inSeconds.clamp(0, 99 * 60 + 59);
  final minutes = (totalSeconds ~/ 60).toString().padLeft(2, '0');
  final seconds = (totalSeconds % 60).toString().padLeft(2, '0');
  return '$minutes:$seconds';
}
