import 'dart:async';
import 'dart:convert';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:falora/ai_config.dart';
import 'package:falora/config/app_branding.dart';
import 'package:falora/ai_result_cache.dart';
import 'package:falora/ai_service.dart';
import 'package:falora/app/auth_gate.dart';
import 'package:falora/category_icon.dart';
import 'package:falora/config/category_fortune_config.dart';
import 'package:falora/config/manual_fortune_config.dart';
import 'package:falora/config/reading_delay_config.dart';
import 'package:falora/firebase_messaging_background.dart';
import 'package:falora/firebase_options.dart';
import 'package:falora/image_upload_card.dart';
import 'package:falora/models/app_user.dart';
import 'package:falora/models/fortune_models.dart';
import 'package:falora/models/fortune_teller_models.dart';
import 'package:falora/models/manual_fortune_request.dart';
import 'package:falora/models/manual_fortune_reader.dart';
import 'package:falora/models/tarot_card.dart';
import 'package:falora/screens/auto_category_form_screens.dart';
import 'package:falora/screens/fortune_teller_selection_screen.dart';
import 'package:falora/screens/manual_fortune_form_screen.dart';
import 'package:falora/services/manual_fortune_storage_service.dart';
import 'package:falora/openai_backend_service.dart';
import 'package:falora/picked_image.dart';
import 'package:falora/screens/profile_screen.dart';
import 'package:falora/services/ads/ad_service_bootstrap.dart';
import 'package:falora/services/fortune_submit_support.dart';
import 'package:falora/services/fortune_backend_service.dart';
import 'package:falora/services/fortune_form_prefill.dart';
import 'package:falora/services/fortune_storage_service.dart';
import 'package:falora/services/fortune_submit_logger.dart';
import 'package:falora/services/interstitial_ad_service.dart';
import 'package:falora/services/notification_backend_service.dart';
import 'package:falora/services/notification_service.dart';
import 'package:falora/services/play_billing_service.dart';
import 'package:falora/services/reading_ready_logger.dart';
import 'package:falora/services/tarot_deck_service.dart';
import 'package:falora/services/token_service.dart';
import 'package:falora/theme/falora_theme.dart';
import 'package:falora/screens/shop_screen.dart';
import 'package:falora/token_config.dart';
import 'package:falora/widgets/falora_labeled_form_field.dart';
import 'package:falora/widgets/fortune_teller_avatar.dart';
import 'package:falora/widgets/live_token_builder.dart';
import 'package:falora/widgets/premium_ui.dart';
import 'package:falora/widgets/reading_record_card.dart';
import 'package:falora/widgets/reward_ad_helper.dart';
import 'package:falora/widgets/tarot_card_picker_sheet.dart';
import 'package:falora/widgets/tarot_card_widgets.dart';

bool get _isMobilePlatform => !kIsWeb;

Future<void> _configureMobileSystemUi() async {
  if (!_isMobilePlatform) return;
  await SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
}

double _mobileBottomInset(BuildContext context) {
  if (kIsWeb) return 0;
  return MediaQuery.viewPaddingOf(context).bottom;
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await _configureMobileSystemUi();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  if (!kIsWeb) {
    FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);
  }
  try {
    await NotificationService.instance.init();
  } catch (e) {
    debugPrint('FCM INIT ERROR: $e');
  }
  await initApiConfig();
  await AdServiceBootstrap.init();
  runApp(const FaloraApp());
}

const _card = faloraCard;
const _accent = faloraAccent;
const _textPrimary = faloraTextPrimary;
const _textSecondary = faloraTextSecondary;

// ─── Uygulama ───────────────────────────────────────────────────────────────

class FaloraApp extends StatefulWidget {
  const FaloraApp({super.key});

  @override
  State<FaloraApp> createState() => _FaloraAppState();
}

class _FaloraAppState extends State<FaloraApp> with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    if (_isMobilePlatform) {
      WidgetsBinding.instance.addObserver(this);
    }
  }

  @override
  void dispose() {
    if (_isMobilePlatform) {
      WidgetsBinding.instance.removeObserver(this);
    }
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _configureMobileSystemUi();
    }
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: appDisplayName,
      debugShowCheckedModeBanner: false,
      theme: faloraTheme(),
      locale: const Locale('tr', 'TR'),
      supportedLocales: const [Locale('tr', 'TR')],
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      home: const AuthGate(),
    );
  }
}

class FaloraShell extends StatefulWidget {
  const FaloraShell({
    super.key,
    required this.user,
    required this.onLogout,
    this.initialSnackBarMessage,
  });

  final AppUser user;
  final VoidCallback onLogout;
  final String? initialSnackBarMessage;

  @override
  State<FaloraShell> createState() => _FaloraShellState();
}

class _FaloraShellState extends State<FaloraShell> with WidgetsBindingObserver {
  int _tabIndex = 0;
  late AppUser _user;
  final List<FortuneReading> _fortuneRequests = [];
  final List<FortuneReading> _coupleCompatibilityRequests = [];
  final Map<String, ValueNotifier<FortuneReading>> _readingNotifiers = {};
  final Map<String, Timer> _readyTimers = {};
  final Map<String, Timer> _pollTimers = {};
  final Set<String> _resolvingReadingIds = {};
  final Map<String, DateTime> _lastResolutionAttempt = {};
  final AiService _aiService =
      useRealAi ? OpenAiBackendService() : createAiService();

  String get _userId => _user.userId;

  AppUser _mergeProfile(AppUser source) =>
      source.copyWith(name: widget.user.name, email: widget.user.email);

  AppUser get _liveUser =>
      _mergeProfile(TokenService.instance.liveUser.value ?? _user);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _user = widget.user;
    TokenService.instance.bindLiveUser(_userId);
    final referralNotice = widget.initialSnackBarMessage;
    if (referralNotice != null && referralNotice.isNotEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(referralNotice)),
        );
      });
    }
    unawaited(
      TokenService.instance.ensureUserDocument(
        uid: _userId,
        name: widget.user.name,
        email: widget.user.email,
      ),
    );
    unawaited(PlayBillingService.instance.init());
    unawaited(TarotDeckService.instance.loadDeck());
    _loadUserFortunes();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    for (final timer in _readyTimers.values) {
      timer.cancel();
    }
    _readyTimers.clear();
    for (final timer in _pollTimers.values) {
      timer.cancel();
    }
    _pollTimers.clear();
    PlayBillingService.instance.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      unawaited(_refreshPendingReadings());
    }
  }

  Future<void> _refreshPendingReadings() async {
    for (final list in [_fortuneRequests, _coupleCompatibilityRequests]) {
      for (final reading in List<FortuneReading>.from(list)) {
        if (reading.isReadyDisplay || reading.isFailedDisplay) continue;
        await _syncReadingFromFirestore(reading.id, list);
        final idx = list.indexWhere((r) => r.id == reading.id);
        if (idx == -1) continue;
        final current = list[idx];
        if (!current.isReadyDisplay &&
            !current.isFailedDisplay &&
            current.isReadyAtElapsed) {
          unawaited(_syncAndEnsureReadingResolved(current, list));
        }
      }
    }
  }

  Future<void> _loadUserFortunes() async {
    final storage = FortuneStorageService.instance;
    await storage.migrateLegacyRecords(_userId);
    final fortunes = await storage.loadFortunes(_userId);
    final manual = await ManualFortuneStorageService.instance
        .loadUserReadings(_userId);
    final couples = await storage.loadCoupleFortunes(_userId);
    if (!mounted) return;
    final merged = [...fortunes, ...manual]
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
    setState(() {
      _fortuneRequests
        ..clear()
        ..addAll(merged);
      _coupleCompatibilityRequests
        ..clear()
        ..addAll(couples);
      for (final r in [...merged, ...couples]) {
        _readingNotifiers[r.id] = ValueNotifier(r);
      }
    });
    _armReadyAtTimersForLoadedReadings();
  }

  FortuneReading _newPendingReading({
    required String id,
    required FortuneCategory category,
    required DateTime createdAt,
    required String summary,
    bool isManualPremium = false,
    String? manualReaderName,
    List<TarotCardSelection> selectedTarotCards = const [],
  }) {
    final readyAt = computeReadyAt(createdAt);
    ReadingReadyLogger.submitCreated(id);
    ReadingReadyLogger.readyAtSet(id, readyAt);
    return FortuneReading(
      id: id,
      category: category,
      status: FortuneStatus.hazirlaniyor,
      createdAt: createdAt,
      summary: summary,
      result: '',
      readyAt: readyAt,
      firestoreStatus: 'pending',
      usesDelayGate: true,
      isManualPremium: isManualPremium,
      manualReaderName: manualReaderName,
      selectedTarotCards: selectedTarotCards,
    );
  }

  void _armReadyAtTimersForLoadedReadings() {
    for (final list in [_fortuneRequests, _coupleCompatibilityRequests]) {
      for (final reading in list) {
        if (reading.readyAt == null) continue;
        if (reading.isReadyDisplay) continue;
        if (reading.hasResult && !isFortuneResultError(reading.result)) {
          if (reading.isReadyAtElapsed) {
            _onReadyAtElapsed(reading, list);
          } else {
            ReadingReadyLogger.resultReadyLockedUntilReadyAt(reading.id);
            _scheduleReadyAtUnlock(reading, list);
          }
        } else if (!reading.isReadyAtElapsed) {
          _scheduleReadyAtUnlock(reading, list);
        } else {
          unawaited(_syncAndEnsureReadingResolved(reading, list));
        }
      }
    }
  }

  Future<bool> _tryRecoverReadingFromFirestore(
    String requestId,
    List<FortuneReading> list,
  ) async {
    await _syncReadingFromFirestore(requestId, list);
    final idx = list.indexWhere((r) => r.id == requestId);
    if (idx == -1) return false;
    final current = list[idx];
    if (!current.hasResult || isFortuneResultError(current.result)) {
      return false;
    }
    if (current.isReadyDisplay) {
      _applyReadyUnlock(current, list);
    }
    return true;
  }

  void _stopPollingReading(String id) {
    _pollTimers.remove(id)?.cancel();
  }

  void _startPollingReading(FortuneReading reading, List<FortuneReading> list) {
    if (_pollTimers.containsKey(reading.id)) return;
    final startedAt = DateTime.now();
    _pollTimers[reading.id] = Timer.periodic(const Duration(seconds: 20), (_) {
      if (!mounted) return;
      if (DateTime.now().difference(startedAt) > const Duration(minutes: 30)) {
        _stopPollingReading(reading.id);
        return;
      }
      final idx = list.indexWhere((r) => r.id == reading.id);
      if (idx == -1) {
        _stopPollingReading(reading.id);
        return;
      }
      final current = list[idx];
      if (current.isReadyDisplay) {
        _stopPollingReading(reading.id);
        return;
      }
      if (current.isFailedDisplay && current.hasResult) {
        _stopPollingReading(reading.id);
        return;
      }
      unawaited(_syncAndEnsureReadingResolved(current, list));
    });
  }

  Future<void> _syncReadingFromFirestore(
    String id,
    List<FortuneReading> list,
  ) async {
    final storage = FortuneStorageService.instance;
    final isCouple = identical(list, _coupleCompatibilityRequests);
    final fresh = isCouple
        ? await storage.fetchCoupleById(_userId, id)
        : await storage.fetchFortuneById(_userId, id);
    if (fresh == null) return;

    final idx = list.indexWhere((r) => r.id == id);
    if (idx == -1) return;

    list[idx] = fresh;
    _readingNotifiers[id]?.value = fresh;
    if (mounted) setState(() {});

    if (fresh.isReadyDisplay) {
      _stopPollingReading(id);
      if (!fresh.isManualPremium && fresh.firestoreStatus != 'ready') {
        unawaited(_markReadingReady(fresh, list));
      }
    } else if (fresh.isFailedDisplay) {
      _stopPollingReading(id);
      unawaited(
        _refundFailedReading(
          requestId: id,
          isCouple: isCouple,
          markError: false,
        ),
      );
    }
  }

  Future<void> _syncAndEnsureReadingResolved(
    FortuneReading reading,
    List<FortuneReading> list,
  ) async {
    await _syncReadingFromFirestore(reading.id, list);
    final idx = list.indexWhere((r) => r.id == reading.id);
    if (idx == -1) return;
    final current = list[idx];
    if (current.isReadyDisplay) {
      _applyReadyUnlock(current, list);
      return;
    }
    if (current.isFailedDisplay) {
      final isCouple = identical(list, _coupleCompatibilityRequests);
      unawaited(
        _refundFailedReading(
          requestId: reading.id,
          isCouple: isCouple,
          markError: false,
        ),
      );
      return;
    }

    await _retryReadingResolution(current, list);
    _startPollingReading(current, list);
  }

  Future<void> _retryReadingResolution(
    FortuneReading reading,
    List<FortuneReading> list,
  ) async {
    if (_resolvingReadingIds.contains(reading.id)) return;

    final last = _lastResolutionAttempt[reading.id];
    if (last != null &&
        DateTime.now().difference(last) < const Duration(seconds: 60)) {
      return;
    }
    _lastResolutionAttempt[reading.id] = DateTime.now();

    final isCouple = identical(list, _coupleCompatibilityRequests);
    if (isCouple) return;

    _resolvingReadingIds.add(reading.id);
    try {
      final storage = FortuneStorageService.instance;
      final data = await storage.fetchFortuneRawData(_userId, reading.id);
      if (data == null) return;

      final existing = (data['result'] as String?)?.trim() ?? '';
      if (existing.isNotEmpty) {
        await _syncReadingFromFirestore(reading.id, list);
        return;
      }

      final inputData = data['inputData'];
      if (inputData is Map) {
        final categoryName = data['category'] as String? ?? 'tarot';
        final category = FortuneCategory.values.firstWhere(
          (c) => c.name == categoryName,
          orElse: () => FortuneCategory.tarot,
        );
        await _resolveAutoCategoryInBackground(
          requestId: reading.id,
          category: category,
          backendType: backendCategoryType(category),
          inputData: Map<String, dynamic>.from(inputData),
          logPrefix: 'FORTUNE_RETRY',
        );
        return;
      }

      final categoryName = data['category'] as String? ?? 'tarot';
      final category = FortuneCategory.values.firstWhere(
        (c) => c.name == categoryName,
        orElse: () => FortuneCategory.tarot,
      );
      final imageNames = (data['imageNames'] as List?)
              ?.map((e) => e.toString())
              .toList() ??
          const <String>[];
      final selectedCards = storage.parseSelectedCardsFromData(data);

      await _resolveFortuneInBackground(
        requestId: reading.id,
        cat: category,
        tellerId: data['tellerId'] as String? ?? 'gizem_ana',
        name: data['name'] as String? ?? '',
        age: (data['age'] as num?)?.toInt() ?? 0,
        burc: data['zodiac'] as String? ?? '',
        niyet: data['intention'] as String? ?? '',
        photoNames: imageNames,
        selectedTarotCards: selectedCards,
      );
    } finally {
      _resolvingReadingIds.remove(reading.id);
    }
  }

  void _applyReadyUnlock(FortuneReading reading, List<FortuneReading> list) {
    final idx = list.indexWhere((r) => r.id == reading.id);
    if (idx == -1) return;
    final current = list[idx];
    if (!current.hasResult || isFortuneResultError(current.result)) return;
    if (!current.isReadyDisplay) return;

    _stopPollingReading(reading.id);
    if (!current.isManualPremium && current.firestoreStatus != 'ready') {
      unawaited(_markReadingReady(current, list));
    }
    final refreshed = current.copyWith(
      status: FortuneStatus.hazir,
      firestoreStatus: current.isManualPremium ? 'answered' : 'ready',
    );
    if (mounted) {
      setState(() => list[idx] = refreshed);
    } else {
      list[idx] = refreshed;
    }
    _readingNotifiers[current.id]?.value = refreshed;
  }

  void _scheduleReadyAtUnlock(FortuneReading reading, List<FortuneReading> list) {
    _readyTimers[reading.id]?.cancel();
    final delay = reading.remainingUntilReady;
    if (delay <= Duration.zero) {
      _onReadyAtElapsed(reading, list);
      return;
    }
    _readyTimers[reading.id] = Timer(
      delay + const Duration(milliseconds: 200),
      () {
        if (!mounted) return;
        final idx = list.indexWhere((r) => r.id == reading.id);
        if (idx == -1) return;
        _onReadyAtElapsed(list[idx], list);
      },
    );
  }

  void _onReadyAtElapsed(FortuneReading reading, List<FortuneReading> list) {
    _readyTimers.remove(reading.id)?.cancel();
    ReadingReadyLogger.countdownDone(reading.id);
    final idx = list.indexWhere((r) => r.id == reading.id);
    if (idx == -1) return;
    final current = list[idx];
    if (!current.hasResult || isFortuneResultError(current.result)) {
      if (mounted) setState(() {});
      unawaited(_syncAndEnsureReadingResolved(current, list));
      return;
    }
    _applyReadyUnlock(current, list);
  }

  Future<void> _promptInsufficientTokensShop(String message) async {
    if (!mounted) return;

    final goShop = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Yetersiz Jeton'),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Vazgeç'),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Mağazaya Git'),
          ),
        ],
      ),
    );

    if (goShop == true && mounted) {
      _openShop();
    }
  }

  bool _checkTokenBalance({
    required String logPrefix,
    required int tokenCost,
  }) {
    if (_liveUser.tokens >= tokenCost) {
      debugPrint('$logPrefix TOKEN CHECK OK');
      return true;
    }
    if (!mounted) return false;
    unawaited(
      _promptInsufficientTokensShop(
        'Yetersiz jeton. Bu işlem $tokenCost jeton gerektirir.\n'
        'Bakiyeniz: ${_liveUser.tokens}',
      ),
    );
    return false;
  }

  Future<bool> _checkManualFortuneTokenBalance() async {
    const tokenCost = manualFortuneTokenCost;
    if (_liveUser.tokens >= tokenCost) {
      debugPrint('MANUAL TOKEN CHECK OK');
      return true;
    }
    if (!mounted) return false;

    await _promptInsufficientTokensShop(
      'Bu özel yorum için 1500 jeton gerekiyor.\n'
      'Jeton bakiyeniz yetersiz.\n'
      'Jeton mağazasından paket satın alabilirsiniz.',
    );
    return false;
  }

  Future<bool> _checkCategoryTokenBalance(int tokenCost) async {
    debugPrint('CATEGORY TOKEN CHECK');
    if (_liveUser.tokens >= tokenCost) {
      debugPrint('CATEGORY TOKEN CHECK OK');
      return true;
    }
    if (!mounted) return false;

    await _promptInsufficientTokensShop(
      'Bu yorum için $tokenCost jeton gerekiyor.\n'
      'Jeton bakiyeniz yetersiz.\n'
      'Jeton mağazasından paket satın alabilirsiniz.',
    );
    return false;
  }

  void _showSubmitError(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  Future<void> _rollbackFortuneRequest(String id) async {
    try {
      await FortuneStorageService.instance.deleteFortune(id);
    } catch (e) {
      debugPrint('FORTUNE ROLLBACK ERROR: $e');
    }
  }

  Future<void> _rollbackCoupleRequest(String id) async {
    try {
      await FortuneStorageService.instance.deleteCoupleFortune(id);
    } catch (e) {
      debugPrint('COUPLE ROLLBACK ERROR: $e');
    }
  }

  Future<void> _onFortuneSubmitted() async {
    InterstitialAdService.instance.recordFortuneSubmission();
    if (!mounted) return;
    await InterstitialAdService.instance.maybeShowAfterSubmission(context);
  }

  void _clearSessionData() {
    for (final timer in _readyTimers.values) {
      timer.cancel();
    }
    _readyTimers.clear();
    _fortuneRequests.clear();
    _coupleCompatibilityRequests.clear();
    _readingNotifiers.clear();
    AiResultCache.clearMemory();
  }

  Future<void> _handleLogout() async {
    _clearSessionData();
    TokenService.instance.unbindLiveUser();
    widget.onLogout();
  }

  ValueNotifier<FortuneReading> _registerReading(FortuneReading reading) {
    final notifier = ValueNotifier(reading);
    _readingNotifiers[reading.id] = notifier;
    return notifier;
  }

  Future<void> _markReadingReady(
    FortuneReading reading,
    List<FortuneReading> list,
  ) async {
    if (reading.isManualPremium) return;
    final isCouple = list == _coupleCompatibilityRequests;
    if (isCouple) {
      await FortuneStorageService.instance.markCoupleReady(reading.id);
    } else {
      await FortuneStorageService.instance.markFortuneReady(reading.id);
    }
    if (!mounted) return;
    final idx = list.indexWhere((r) => r.id == reading.id);
    if (idx == -1) return;
    final updated = list[idx].copyWith(
      status: FortuneStatus.hazir,
      firestoreStatus: 'ready',
    );
    setState(() => list[idx] = updated);
    _readingNotifiers[reading.id]?.value = updated;
  }

  void _scheduleReadyPushNotification({
    required String readingId,
    required DateTime readyAt,
    required bool isCouple,
  }) {
    unawaited(
      NotificationBackendService.instance.scheduleNotify(
        userId: _userId,
        isCouple: isCouple,
        notifyAt: readyAt,
        readingId: readingId,
      ),
    );
  }

  void _addFortuneRequest(FortuneReading reading) {
    if (!mounted) return;
    setState(() => _fortuneRequests.insert(0, reading));
  }

  void _addCoupleRequest(FortuneReading reading) {
    if (!mounted) return;
    setState(() => _coupleCompatibilityRequests.insert(0, reading));
  }

  void _openSonuc(FortuneReading reading) {
    if (!reading.isViewable) {
      final remaining = reading.remainingUntilReady;
      ReadingReadyLogger.resultOpenBlockedRemainingTime(reading.id, remaining);
      final message = reading.readyAt != null && !reading.isReadyAtElapsed
          ? 'Yorumunuz hazırlanıyor. Kalan süre: ${formatReadingCountdown(remaining)}'
          : 'Yorumunuz hazırlanıyor.';
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(message)),
      );
      return;
    }
    ReadingReadyLogger.resultOpenAllowed(reading.id);
    final notifier = _readingNotifiers[reading.id];
    if (notifier == null) return;
    Navigator.of(context).push(
      faloraPageRoute<void>(
        SonucPage(
          notifier: notifier,
          userId: _userId,
        ),
      ),
    );
  }

  void _openCategory(FortuneCategory cat) {
    if (cat == FortuneCategory.ciftUyumu) {
      FortuneFormPrefill.logSkippedCouple();
      Navigator.of(context).push(
        faloraPageRoute<void>(
          CiftUyumuFormPage(
            onSubmit: _submitCiftUyumu,
            onOpenShop: _openShop,
          ),
        ),
      );
      return;
    }
    Navigator.of(context).push(
      faloraPageRoute<void>(
        FortuneTellerSelectionPage(
          category: cat,
          onTellerChosen: (ctx, teller) {
            if (isAutoOnlyCategory(cat)) {
              _openAutoCategoryForm(ctx, cat, teller);
            } else {
              _openFortuneForm(ctx, cat, teller);
            }
          },
          onManualReaderChosen: (ctx, reader) =>
              _openManualFortuneForm(ctx, cat, reader),
          onOpenShop: _openShop,
        ),
      ),
    );
  }

  FortuneFormPrefill? _fortuneFormPrefill() {
    final prefill = FortuneFormPrefill.fromUser(_liveUser);
    if (prefill != null && prefill.hasAny) {
      FortuneFormPrefill.logApplied();
    }
    return prefill;
  }

  void _openAutoCategoryForm(
    BuildContext context,
    FortuneCategory cat,
    FortuneTeller teller,
  ) {
    final resolved = resolveFortuneTeller(cat, teller.id);
    logFortuneSelectedCost(cat, teller.id);
    if (_liveUser.tokens < resolved.tokenCost) {
      _promptInsufficientTokensShop(
        'Yetersiz jeton. ${resolved.name} ${resolved.tokenCost} jeton gerektirir.\n'
        'Mağazadan jeton satın alabilirsiniz.',
      );
      return;
    }
    switch (cat) {
      case FortuneCategory.ruyaTabiri:
        Navigator.of(context).push(
          faloraPageRoute<void>(
            DreamInterpretationFormPage(
              tokenCost: resolved.tokenCost,
              onSubmit: (dream) =>
                  _submitDreamInterpretation(dream, teller: resolved),
              onOpenShop: _openShop,
            ),
          ),
        );
      case FortuneCategory.numeroloji:
        Navigator.of(context).push(
          faloraPageRoute<void>(
            NumerologyFormPage(
              tokenCost: resolved.tokenCost,
              prefill: _fortuneFormPrefill(),
              onSubmit: (name, birthDate) =>
                  _submitNumerology(name, birthDate, teller: resolved),
              onOpenShop: _openShop,
            ),
          ),
        );
      case FortuneCategory.burcYorumu:
        Navigator.of(context).push(
          faloraPageRoute<void>(
            HoroscopeFormPage(
              tokenCost: resolved.tokenCost,
              prefill: _fortuneFormPrefill(),
              onSubmit: (sun, moon, focus) =>
                  _submitHoroscope(sun, moon, focus, teller: resolved),
              onOpenShop: _openShop,
            ),
          ),
        );
      default:
        break;
    }
  }

  Future<void> _openFortuneForm(
    BuildContext context,
    FortuneCategory cat,
    FortuneTeller teller,
  ) async {
    final resolved = resolveFortuneTeller(cat, teller.id);
    logFortuneSelectedCost(cat, teller.id);
    if (_liveUser.tokens < resolved.tokenCost) {
      await _promptInsufficientTokensShop(
        'Yetersiz jeton. ${resolved.name} ${resolved.tokenCost} jeton gerektirir.\n'
        'Bakiyeniz: ${_liveUser.tokens}',
      );
      return;
    }
    if (!context.mounted) return;
    Navigator.of(context).push(
      faloraPageRoute<void>(
        cat == FortuneCategory.kahve
            ? KahveFormPage(
                teller: resolved,
                prefill: _fortuneFormPrefill(),
                onSubmit: _submitNormal,
                onOpenShop: _openShop,
              )
            : NormalFalFormPage(
                category: cat,
                teller: resolved,
                prefill: _fortuneFormPrefill(),
                onSubmit: _submitNormal,
                onOpenShop: _openShop,
              ),
      ),
    );
  }

  void _openManualFortuneForm(
    BuildContext context,
    FortuneCategory cat,
    ManualFortuneReader reader,
  ) {
    final offer = manualOfferFor(cat);
    logManualReaderConfig(cat);
    debugPrint('MANUAL READER SELECTED: ${reader.id} (${reader.name})');
    debugPrint('MANUAL TOKEN COST: ${offer.priceLabel}');
    Navigator.of(context).push(
      faloraPageRoute<void>(
        ManualFortuneFormPage(
          category: cat,
          reader: reader,
          offer: offer,
          prefill: _fortuneFormPrefill(),
          onSubmit: _submitManualFortune,
          onOpenShop: _openShop,
        ),
      ),
    );
  }

  void _openShop() {
    Navigator.of(context).push(
      faloraPageRoute<void>(
        ShopScreen(userId: _userId),
      ),
    );
  }

  void _openRewardAd() {
    showRewardAdSheet(
      context,
      user: _liveUser,
    );
  }

  Future<void> _deductSubmitTokens({
    required String logPrefix,
    required int amount,
  }) async {
    final before = TokenService.instance.liveUser.value?.tokens ??
        await TokenService.instance.readTokenBalance(_userId);
    debugPrint('TOKEN_DEDUCT_BEFORE balance=$before amount=$amount');
    debugPrint('$logPrefix TOKEN DEDUCT START ($amount)');
    await TokenService.instance.spendTokens(_userId, amount);
    final after = TokenService.instance.liveUser.value?.tokens ??
        await TokenService.instance.readTokenBalance(_userId);
    debugPrint('TOKEN_DEDUCT_AFTER balance=$after');
    debugPrint('$logPrefix TOKEN DEDUCT OK');
  }

  void _handleSubmitFailure(
    Object error,
    StackTrace? stackTrace, {
    required String logPrefix,
    String? requestId,
    required bool tokensDeducted,
    bool isCouple = false,
    Future<void> Function()? rollback,
  }) {
    FortuneSubmitLogger.logError(error, stackTrace);
    if (requestId != null && !tokensDeducted && rollback != null) {
      unawaited(rollback());
    }
    if (requestId != null && tokensDeducted) {
      unawaited(
        _refundFailedReading(
          requestId: requestId,
          isCouple: isCouple,
          notifyUser: true,
        ),
      );
    }
    _showSubmitError(
      mapFortuneSubmitError(
        error,
        logPrefix: logPrefix,
        tokensDeducted: tokensDeducted,
        requestCreated: requestId != null,
      ),
    );
  }

  Future<FortuneRefundResult?> _refundFailedReading({
    required String requestId,
    required bool isCouple,
    bool markError = true,
    bool notifyUser = false,
  }) async {
    final storage = FortuneStorageService.instance;
    if (markError) {
      try {
        if (isCouple) {
          await storage.markCoupleError(requestId);
        } else {
          await storage.markFortuneError(requestId);
        }
      } catch (e) {
        debugPrint('REFUND MARK ERROR FAILED: $e');
      }
    }

    try {
      final result = await FortuneBackendService.instance.refundFailedRequest(
        requestId: requestId,
        isCouple: isCouple,
      );
      if (result.wasRefunded) {
        debugPrint('TOKEN REFUND OK: ${result.amount}');
      } else {
        debugPrint('TOKEN REFUND SKIP: ${result.reason}');
      }
      if (notifyUser && result.wasRefunded && mounted) {
        _showTokenRefundSnackBar(result.amount);
      }
      return result;
    } catch (e) {
      debugPrint('TOKEN REFUND FAILED: $e');
      return null;
    }
  }

  void _showTokenRefundSnackBar(int amount) {
    if (!mounted || amount <= 0) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('$amount jeton hesabınıza iade edildi.'),
      ),
    );
  }

  void _updateReading(
    List<FortuneReading> list,
    String id, {
    String? result,
    FortuneStatus? status,
    String? firestoreStatus,
  }) {
    final idx = list.indexWhere((r) => r.id == id);
    if (idx == -1) return;

    final updated = list[idx].copyWith(
      result: result,
      status: status,
      firestoreStatus: firestoreStatus,
    );

    if (result != null &&
        result.isNotEmpty &&
        !isFortuneResultError(result)) {
      if (updated.isReadyDisplay) {
        _stopPollingReading(id);
        if (!updated.isManualPremium) {
          unawaited(_markReadingReady(updated, list));
        }
      } else if (updated.readyAt != null && !updated.isReadyAtElapsed) {
        ReadingReadyLogger.resultReadyLockedUntilReadyAt(id);
        _scheduleReadyAtUnlock(updated, list);
      }
    }

    if (updated.isFailedDisplay) {
      _stopPollingReading(id);
    }

    if (!mounted) {
      list[idx] = updated;
      _readingNotifiers[id]?.value = updated;
      return;
    }
    setState(() => list[idx] = updated);
    _readingNotifiers[id]?.value = updated;
  }

  Future<void> _resolveFortuneInBackground({
    required String requestId,
    required FortuneCategory cat,
    required String tellerId,
    required String name,
    required int age,
    required String burc,
    required String niyet,
    List<String>? photoNames,
    List<TarotCardSelection>? selectedTarotCards,
  }) async {
    final storage = FortuneStorageService.instance;
    debugPrint('FORTUNE BACKEND START');
    debugPrint('API ENDPOINT: $apiBaseUrl/generate-fortune');
    debugPrint('IS MANUAL READER: false');
    try {
      final cached = await AiResultCache.get(_userId, requestId);
      if (cached != null && cached.isNotEmpty) {
        debugPrint('FORTUNE BACKEND SUCCESS');
        await storage.updateFortuneResult(requestId, cached);
        debugPrint('FORTUNE RESULT SAVED');
        if (!mounted) return;
        _updateReading(_fortuneRequests, requestId, result: cached);
        return;
      }

      final result = await _aiService.generateFortune(
        category: cat.label,
        name: name,
        age: age,
        zodiac: burc,
        intention: niyet,
        tellerId: tellerId,
        requestId: requestId,
        imageNames: photoNames ?? const [],
        selectedTarotCards: selectedTarotCards ?? const [],
      );
      debugPrint('FORTUNE BACKEND SUCCESS');
      await storage.updateFortuneResult(requestId, result);
      debugPrint('FORTUNE RESULT SAVED');
      await AiResultCache.put(_userId, requestId, result);
      if (!mounted) return;
      _updateReading(_fortuneRequests, requestId, result: result);
    } catch (e, stackTrace) {
      debugPrint('FORTUNE BACKEND ERROR: $e');
      debugPrint(stackTrace.toString());
      if (await _tryRecoverReadingFromFirestore(
        requestId,
        _fortuneRequests,
      )) {
        return;
      }
      try {
        await storage.markFortuneError(requestId);
      } catch (markError) {
        debugPrint('FORTUNE ERROR STATUS SAVE FAILED: $markError');
      }
      unawaited(
        _refundFailedReading(
          requestId: requestId,
          isCouple: false,
          markError: false,
          notifyUser: true,
        ),
      );
      if (!mounted) return;
      _updateReading(
        _fortuneRequests,
        requestId,
        result: aiErrorMessage,
        firestoreStatus: 'error',
      );
    }
  }

  Future<void> _resolveAutoCategoryInBackground({
    required String requestId,
    required FortuneCategory category,
    required String backendType,
    required Map<String, dynamic> inputData,
    required String logPrefix,
  }) async {
    final storage = FortuneStorageService.instance;
    debugPrint('$logPrefix BACKEND START');
    debugPrint('API ENDPOINT: $apiBaseUrl/generate-fortune');
    try {
      final cached = await AiResultCache.get(_userId, requestId);
      if (cached != null && cached.isNotEmpty) {
        debugPrint('CATEGORY RESPONSE SUCCESS');
        await storage.updateFortuneResult(requestId, cached);
        if (!mounted) return;
        _updateReading(_fortuneRequests, requestId, result: cached);
        return;
      }

      final result = await _aiService.generateCategoryReading(
        categoryType: backendType,
        inputData: inputData,
        requestId: requestId,
      );
      debugPrint('CATEGORY RESPONSE SUCCESS');
      await storage.updateFortuneResult(requestId, result);
      await AiResultCache.put(_userId, requestId, result);
      if (!mounted) return;
      _updateReading(_fortuneRequests, requestId, result: result);
    } catch (e, stackTrace) {
      debugPrint('CATEGORY RESPONSE ERROR: $e');
      debugPrint(stackTrace.toString());
      if (await _tryRecoverReadingFromFirestore(
        requestId,
        _fortuneRequests,
      )) {
        return;
      }
      try {
        await storage.markFortuneError(requestId);
      } catch (markError) {
        debugPrint('CATEGORY ERROR STATUS SAVE FAILED: $markError');
      }
      unawaited(
        _refundFailedReading(
          requestId: requestId,
          isCouple: false,
          markError: false,
          notifyUser: true,
        ),
      );
      if (!mounted) return;
      _updateReading(
        _fortuneRequests,
        requestId,
        result: aiErrorMessage,
        firestoreStatus: 'error',
      );
    }
  }

  Future<void> _validateCoupleImages({
    required PickedImage kadinFoto,
    required PickedImage erkekFoto,
  }) async {
    debugPrint('COUPLE IMAGE PROCESS START');
    try {
      if (kadinFoto.bytes.isEmpty) {
        throw StateError('Kadın fotoğrafı boş');
      }
      if (erkekFoto.bytes.isEmpty) {
        throw StateError('Erkek fotoğrafı boş');
      }
      debugPrint(
        'COUPLE IMAGE woman: ${kadinFoto.name} | ${kadinFoto.bytes.length} bytes',
      );
      debugPrint(
        'COUPLE IMAGE man: ${erkekFoto.name} | ${erkekFoto.bytes.length} bytes',
      );
      debugPrint('COUPLE IMAGE PROCESS OK');
    } catch (e, stackTrace) {
      debugPrint('COUPLE IMAGE PROCESS ERROR: $e');
      debugPrint(stackTrace.toString());
      rethrow;
    }
  }

  Future<void> _failCoupleRequest(String requestId) async {
    if (await _tryRecoverReadingFromFirestore(
      requestId,
      _coupleCompatibilityRequests,
    )) {
      return;
    }
    final storage = FortuneStorageService.instance;
    try {
      await storage.markCoupleError(requestId);
    } catch (markError) {
      debugPrint('COUPLE ERROR STATUS SAVE FAILED: $markError');
    }
    final refund = await _refundFailedReading(
      requestId: requestId,
      isCouple: true,
      markError: false,
    );
    if (!mounted) return;
    _updateReading(
      _coupleCompatibilityRequests,
      requestId,
      result: coupleErrorMessage,
      firestoreStatus: 'error',
    );
    if (refund?.wasRefunded == true) {
      _showTokenRefundSnackBar(refund!.amount);
    }
  }

  static const _coupleBackendTimeout = Duration(seconds: 120);

  Future<void> _resolveCoupleInBackground({
    required String requestId,
    required String kadinIsim,
    required int kadinYas,
    required String kadinBurc,
    required String erkekIsim,
    required int erkekYas,
    required String erkekBurc,
    required PickedImage kadinFoto,
    required PickedImage erkekFoto,
  }) async {
    final storage = FortuneStorageService.instance;
    debugPrint('COUPLE BACKEND START');
    debugPrint('COUPLE BACKEND URL: $apiBaseUrl/generate-couple');
    try {
      final cached = await AiResultCache.get(_userId, requestId);
      if (cached != null && cached.isNotEmpty) {
        debugPrint('COUPLE BACKEND SUCCESS');
        await storage.updateCoupleResult(requestId, cached);
        debugPrint('COUPLE RESULT SAVED');
        if (!mounted) return;
        _updateReading(_coupleCompatibilityRequests, requestId, result: cached);
        return;
      }

      final result = await _aiService
          .generateCoupleCompatibility(
            womanName: kadinIsim,
            womanAge: kadinYas,
            womanZodiac: kadinBurc,
            manName: erkekIsim,
            manAge: erkekYas,
            manZodiac: erkekBurc,
            requestId: requestId,
            womanImage: kadinFoto,
            manImage: erkekFoto,
          )
          .timeout(
            _coupleBackendTimeout,
            onTimeout: () {
              throw TimeoutException(
                'Couple backend timeout after ${_coupleBackendTimeout.inSeconds}s',
              );
            },
          );
      debugPrint('COUPLE BACKEND SUCCESS');
      await storage.updateCoupleResult(requestId, result);
      debugPrint('COUPLE RESULT SAVED');
      await AiResultCache.put(_userId, requestId, result);
      if (!mounted) return;
      _updateReading(_coupleCompatibilityRequests, requestId, result: result);
    } on TimeoutException catch (e, stackTrace) {
      debugPrint('COUPLE ERROR: $e');
      debugPrint(stackTrace.toString());
      await _failCoupleRequest(requestId);
    } catch (e, stackTrace) {
      debugPrint('COUPLE ERROR: $e');
      debugPrint(stackTrace.toString());
      await _failCoupleRequest(requestId);
    }
  }

  void _navigateAfterFortuneSubmit({
    required String logPrefix,
    required int tabIndex,
    required String successMessage,
    FortuneReading? openReading,
    bool popToRoot = false,
  }) {
    debugPrint('$logPrefix NAVIGATION START');
    if (!mounted) {
      debugPrint('$logPrefix NAVIGATION SKIPPED (not mounted)');
      return;
    }
    if (popToRoot) {
      Navigator.of(context).popUntil((route) => route.isFirst);
    } else {
      Navigator.of(context).pop();
    }
    if (!mounted) {
      debugPrint('$logPrefix NAVIGATION SKIPPED (not mounted after pop)');
      return;
    }
    setState(() => _tabIndex = tabIndex);
    debugPrint('$logPrefix NAVIGATION OK');
    if (openReading != null) {
      final notifier = _readingNotifiers[openReading.id];
      if (notifier != null && mounted) {
        Navigator.of(context).push(
          faloraPageRoute<void>(
            SonucPage(
              notifier: notifier,
              userId: _userId,
            ),
          ),
        );
      }
    }
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(successMessage)),
    );
  }

  Future<void> _submitNormal(
    FortuneCategory cat,
    FortuneTeller teller,
    String name,
    int age,
    String burc,
    String niyet, {
    List<String>? photoNames,
    List<TarotCardSelection>? selectedTarotCards,
  }) async {
    if (cat == FortuneCategory.tarot) {
      final cards = selectedTarotCards ?? const [];
      if (cards.length != tarotSpreadCardCount) {
        _showSubmitError('Tarot falı için $tarotSpreadCardCount kart seçmelisiniz.');
        return;
      }
    }

    final submitCost = resolveTellerTokenCost(cat, teller.id);
    logFortuneSubmitCost(cat, teller.id, submitCost);

    await FortuneSubmitLogger.logSubmitStart(
      fortuneType: cat.label,
      selectedReader: '${teller.id} (${teller.name})',
      isManualReader: false,
      endpoint: '$apiBaseUrl/generate-fortune',
      requestBody: {
        'flow': 'ai_token',
        'tellerId': teller.id,
        'tokenCost': submitCost,
        'billingUsed': false,
      },
    );

    final storage = FortuneStorageService.instance;
    String? requestId;
    var tokensDeducted = false;

    try {
      await prepareFortuneSubmit(
        uid: _userId,
        name: widget.user.name,
        email: _liveUser.email,
        fortuneCost: submitCost,
        logPrefix: 'FORTUNE',
      );
      debugPrint('FORTUNE VALIDATION OK');

      requestId = storage.newFortuneId();
      final now = DateTime.now();
      final readyAt = computeReadyAt(now);

      try {
        debugPrint('FORTUNE REQUEST CREATE START');
        await storage.createFortune(
          id: requestId,
          userId: _userId,
          category: cat,
          name: name,
          age: age,
          zodiac: burc,
          intention: niyet,
          tokenCost: submitCost,
          imageNames: photoNames ?? const [],
          tellerId: teller.id,
          tellerName: teller.name,
          selectedTarotCards: selectedTarotCards ?? const [],
          createdAt: now,
          readyAt: readyAt,
        );
        debugPrint('FORTUNE REQUEST CREATE OK');
        debugPrint('FORTUNE_REQUEST_CREATE_SUCCESS id=$requestId');
      } catch (e, stackTrace) {
        debugPrint('FORTUNE REAL ERROR at REQUEST CREATE: $e');
        debugPrint(stackTrace.toString());
        rethrow;
      }

      try {
        await _deductSubmitTokens(
          logPrefix: 'FORTUNE',
          amount: submitCost,
        );
        tokensDeducted = true;
      } catch (e, stackTrace) {
        debugPrint('FORTUNE REAL ERROR at TOKEN DEDUCT: $e');
        debugPrint(stackTrace.toString());
        rethrow;
      }

      unawaited(
        TokenService.instance.mergeProfileFields(
          uid: _userId,
          age: age,
          zodiac: burc,
        ),
      );

      final summary = cat == FortuneCategory.tarot &&
              (selectedTarotCards?.isNotEmpty ?? false)
          ? '${cat.label} — ${teller.name} — $name, $age, $burc\n'
              'Niyet: $niyet\n'
              '${selectedTarotCards!.length} tarot kartı seçildi'
          : '${cat.label} — ${teller.name} — $name, $age, $burc\nNiyet: $niyet';
      final reading = _newPendingReading(
        id: requestId,
        category: cat,
        createdAt: now,
        summary: summary,
        selectedTarotCards: selectedTarotCards ?? const [],
      );
      _registerReading(reading);
      _addFortuneRequest(reading);
      _scheduleReadyAtUnlock(reading, _fortuneRequests);
      _scheduleReadyPushNotification(
        readingId: requestId,
        readyAt: readyAt,
        isCouple: false,
      );
      unawaited(
        _resolveFortuneInBackground(
          requestId: requestId,
          cat: cat,
          tellerId: teller.id,
          name: name,
          age: age,
          burc: burc,
          niyet: niyet,
          photoNames: photoNames,
          selectedTarotCards: selectedTarotCards,
        ),
      );

      _navigateAfterFortuneSubmit(
        logPrefix: 'FORTUNE',
        tabIndex: 1,
        successMessage: 'Falınız hazırlanıyor...',
        popToRoot: true,
      );
      unawaited(_onFortuneSubmitted());
    } catch (e, stackTrace) {
      _handleSubmitFailure(
        e,
        stackTrace,
        logPrefix: 'FORTUNE',
        requestId: requestId,
        tokensDeducted: tokensDeducted,
        rollback: requestId != null && !tokensDeducted
            ? () => _rollbackFortuneRequest(requestId!)
            : null,
      );
    }
  }

  Future<void> _submitAutoCategory({
    required FortuneCategory category,
    required FortuneTeller teller,
    required String logPrefix,
    required Map<String, dynamic> inputData,
  }) async {
    debugPrint('$logPrefix SUBMIT START');
    final tokenCost = resolveTellerTokenCost(category, teller.id);
    logFortuneSubmitCost(category, teller.id, tokenCost);
    final backendType = backendCategoryType(category);
    final title = categoryFortuneTitle(category);
    final summary = buildCategorySummary(category, inputData);

    final storage = FortuneStorageService.instance;
    String? requestId;
    var tokensDeducted = false;

    try {
      await prepareFortuneSubmit(
        uid: _userId,
        name: widget.user.name,
        email: _liveUser.email,
        fortuneCost: tokenCost,
        logPrefix: logPrefix,
      );

      requestId = storage.newFortuneId();
      final now = DateTime.now();
      final readyAt = computeReadyAt(now);

      await storage.createCategoryFortune(
        id: requestId,
        userId: _userId,
        category: category,
        title: title,
        inputData: inputData,
        tokenCost: tokenCost,
        tellerId: teller.id,
        tellerName: teller.name,
        createdAt: now,
        readyAt: readyAt,
      );
      debugPrint('FORTUNE_REQUEST_CREATE_SUCCESS id=$requestId');

      await _deductSubmitTokens(logPrefix: logPrefix, amount: tokenCost);
      tokensDeducted = true;

      final reading = _newPendingReading(
        id: requestId,
        category: category,
        createdAt: now,
        summary: summary,
      );
      _registerReading(reading);
      _addFortuneRequest(reading);
      _scheduleReadyAtUnlock(reading, _fortuneRequests);
      _scheduleReadyPushNotification(
        readingId: requestId,
        readyAt: readyAt,
        isCouple: false,
      );
      unawaited(
        _resolveAutoCategoryInBackground(
          requestId: requestId,
          category: category,
          backendType: backendType,
          inputData: inputData,
          logPrefix: logPrefix,
        ),
      );

      _navigateAfterFortuneSubmit(
        logPrefix: logPrefix,
        tabIndex: 1,
        successMessage: '${category.label} hazırlanıyor...',
        popToRoot: true,
      );
      unawaited(_onFortuneSubmitted());
    } catch (e, stackTrace) {
      _handleSubmitFailure(
        e,
        stackTrace,
        logPrefix: logPrefix,
        requestId: requestId,
        tokensDeducted: tokensDeducted,
        rollback: requestId != null && !tokensDeducted
            ? () => _rollbackFortuneRequest(requestId!)
            : null,
      );
    }
  }

  Future<void> _submitDreamInterpretation(
    String dreamText, {
    required FortuneTeller teller,
  }) async {
    await _submitAutoCategory(
      category: FortuneCategory.ruyaTabiri,
      teller: teller,
      logPrefix: 'DREAM',
      inputData: {'dreamText': dreamText},
    );
  }

  Future<void> _submitNumerology(
    String name,
    DateTime birthDate, {
    required FortuneTeller teller,
  }) async {
    await _submitAutoCategory(
      category: FortuneCategory.numeroloji,
      teller: teller,
      logPrefix: 'NUMEROLOGY',
      inputData: {
        'name': name,
        'birthDate': formatBirthDate(birthDate),
      },
    );
  }

  Future<void> _submitHoroscope(
    String sunSign,
    String moonSign,
    String focusArea, {
    required FortuneTeller teller,
  }) async {
    await _submitAutoCategory(
      category: FortuneCategory.burcYorumu,
      teller: teller,
      logPrefix: 'HOROSCOPE',
      inputData: {
        'sunSign': sunSign,
        'moonSign': moonSign,
        'focusArea': focusArea,
      },
    );
  }

  Future<void> _submitManualFortune({
    required FortuneCategory category,
    required ManualFortuneReader reader,
    required ManualFortuneOffer offer,
    required String name,
    required int age,
    required String zodiac,
    required String intention,
    required List<String> questions,
    List<PickedImage>? images,
  }) async {
    const tokenCost = manualFortuneTokenCost;
    await FortuneSubmitLogger.logSubmitStart(
      fortuneType: category.label,
      selectedReader: '${reader.id} (${reader.name})',
      isManualReader: true,
      endpoint: 'firestore:manual_fortune_requests',
      requestBody: {
        'flow': 'token_payment',
        'tokenCost': tokenCost,
      },
    );

    final storage = ManualFortuneStorageService.instance;
    final requestId = storage.newRequestId();
    final now = DateTime.now();
    var tokensDeducted = false;
    var requestCreated = false;

    try {
      await prepareFortuneSubmit(
        uid: _userId,
        name: widget.user.name,
        email: _liveUser.email,
        fortuneCost: tokenCost,
        logPrefix: 'MANUAL',
      );

      debugPrint('FORTUNE_REQUEST_CREATE_START id=$requestId');
      await storage.createRequest(
        id: requestId,
        userId: _userId,
        userEmail: _liveUser.email,
        category: category,
        readerId: reader.id,
        readerName: reader.name,
        offer: offer,
        tokenCost: tokenCost,
        name: name,
        age: age,
        zodiac: zodiac,
        intention: intention,
        questions: questions,
        images: images,
      );
      requestCreated = true;
      debugPrint('FORTUNE_REQUEST_CREATE_SUCCESS id=$requestId');

      await _deductSubmitTokens(logPrefix: 'MANUAL', amount: tokenCost);
      tokensDeducted = true;

      final summary =
          '${category.label} — ${reader.name} (Özel)\n$name, $age, $zodiac\nNiyet: $intention';
      final reading = _newPendingReading(
        id: requestId,
        category: category,
        createdAt: now,
        summary: summary,
        isManualPremium: true,
        manualReaderName: reader.name,
      );
      _registerReading(reading);
      _addFortuneRequest(reading);
      _scheduleReadyAtUnlock(reading, _fortuneRequests);

      _navigateAfterFortuneSubmit(
        logPrefix: 'MANUAL',
        tabIndex: 1,
        successMessage:
            'Özel fal talebin alındı. $tokenCost jeton hesabından düşüldü.',
        popToRoot: true,
      );
    } on ManualFortuneException catch (e) {
      if (tokensDeducted) {
        await TokenService.instance.addTokens(_userId, tokenCost);
      }
      _handleSubmitFailure(
        e,
        null,
        logPrefix: 'MANUAL',
        requestId: requestCreated ? requestId : null,
        tokensDeducted: tokensDeducted,
        rollback: requestCreated && !tokensDeducted
            ? () => storage.deleteRequest(requestId)
            : null,
      );
    } catch (e, stackTrace) {
      if (tokensDeducted) {
        await TokenService.instance.addTokens(_userId, tokenCost);
      }
      _handleSubmitFailure(
        e,
        stackTrace,
        logPrefix: 'MANUAL',
        requestId: requestCreated ? requestId : null,
        tokensDeducted: tokensDeducted,
        rollback: requestCreated && !tokensDeducted
            ? () => storage.deleteRequest(requestId)
            : null,
      );
    }
  }

  Future<void> _submitCiftUyumu({
    required String kadinIsim,
    required int kadinYas,
    required String kadinBurc,
    required String erkekIsim,
    required int erkekYas,
    required String erkekBurc,
    required PickedImage kadinFoto,
    required PickedImage erkekFoto,
  }) async {
    debugPrint('COUPLE SUBMIT START');
    final storage = FortuneStorageService.instance;
    String? requestId;
    var tokensDeducted = false;

    try {
      await prepareFortuneSubmit(
        uid: _userId,
        name: widget.user.name,
        email: _liveUser.email,
        fortuneCost: coupleTokenCost,
        logPrefix: 'COUPLE',
      );
      debugPrint('COUPLE VALIDATION OK');

      await _validateCoupleImages(
        kadinFoto: kadinFoto,
        erkekFoto: erkekFoto,
      );

      requestId = storage.newCoupleId();
      final now = DateTime.now();
      final readyAt = computeReadyAt(now);
      final summary =
          'Kadın: $kadinIsim, $kadinYas, $kadinBurc\n'
          'Erkek: $erkekIsim, $erkekYas, $erkekBurc';

      try {
        debugPrint('COUPLE REQUEST CREATE START');
        await storage.createCoupleFortune(
          id: requestId,
          userId: _userId,
          femaleName: kadinIsim,
          maleName: erkekIsim,
          femaleZodiac: kadinBurc,
          maleZodiac: erkekBurc,
          femaleAge: kadinYas,
          maleAge: erkekYas,
          tokenCost: coupleTokenCost,
          womanImageName: kadinFoto.name,
          manImageName: erkekFoto.name,
          createdAt: now,
          readyAt: readyAt,
        );
        debugPrint('COUPLE REQUEST CREATE OK');
        debugPrint('FORTUNE_REQUEST_CREATE_SUCCESS id=$requestId');
      } catch (e, stackTrace) {
        debugPrint('COUPLE REAL ERROR at REQUEST CREATE: $e');
        debugPrint(stackTrace.toString());
        rethrow;
      }

      try {
        await _deductSubmitTokens(
          logPrefix: 'COUPLE',
          amount: coupleTokenCost,
        );
        tokensDeducted = true;
      } catch (e, stackTrace) {
        debugPrint('COUPLE REAL ERROR at TOKEN DEDUCT: $e');
        debugPrint(stackTrace.toString());
        rethrow;
      }

      final reading = _newPendingReading(
        id: requestId,
        category: FortuneCategory.ciftUyumu,
        createdAt: now,
        summary: summary,
      );
      _registerReading(reading);
      _addCoupleRequest(reading);
      _scheduleReadyAtUnlock(reading, _coupleCompatibilityRequests);
      _scheduleReadyPushNotification(
        readingId: requestId,
        readyAt: readyAt,
        isCouple: true,
      );
      unawaited(
        _resolveCoupleInBackground(
          requestId: requestId,
          kadinIsim: kadinIsim,
          kadinYas: kadinYas,
          kadinBurc: kadinBurc,
          erkekIsim: erkekIsim,
          erkekYas: erkekYas,
          erkekBurc: erkekBurc,
          kadinFoto: kadinFoto,
          erkekFoto: erkekFoto,
        ),
      );

      _navigateAfterFortuneSubmit(
        logPrefix: 'COUPLE',
        tabIndex: 2,
        successMessage: 'Uyum raporunuz hazırlanıyor...',
        popToRoot: true,
      );
      unawaited(_onFortuneSubmitted());
    } catch (e, stackTrace) {
      _handleSubmitFailure(
        e,
        stackTrace,
        logPrefix: 'COUPLE',
        requestId: requestId,
        tokensDeducted: tokensDeducted,
        isCouple: true,
        rollback: requestId != null && !tokensDeducted
            ? () => _rollbackCoupleRequest(requestId!)
            : null,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<AppUser?>(
      valueListenable: TokenService.instance.liveUser,
      builder: (context, _, __) {
        final user = _liveUser;
        return _buildShell(user);
      },
    );
  }

  Widget _buildShell(AppUser user) {
    final tabTitles = ['', 'Fallarım', 'Çift Uyumu', 'Profil'];
    return Scaffold(
      appBar: _tabIndex == 0
          ? null
          : AppBar(
              title: Text(
                tabTitles[_tabIndex],
                style: const TextStyle(
                  fontWeight: FontWeight.w600,
                  color: _textPrimary,
                ),
              ),
              actions: [
                Padding(
                  padding: const EdgeInsets.only(right: 12),
                  child: Center(
                    child: FaloraTappableTokenBalance(
                      tokens: user.tokens,
                      onTap: _openShop,
                      compact: true,
                      showHint: false,
                    ),
                  ),
                ),
              ],
            ),
      body: IndexedStack(
        index: _tabIndex,
        children: [
          _AnaSayfa(
            userName: widget.user.name,
            tokens: user.tokens,
            onCategoryTap: _openCategory,
            onOpenShop: _openShop,
            onOpenReward: _openRewardAd,
          ),
          _FallarimPage(
            readings: _fortuneRequests,
            readingNotifiers: _readingNotifiers,
            onTap: (r) => _openSonuc(r),
          ),
          CiftUyumuTab(
            readings: _coupleCompatibilityRequests,
            onStart: () => _openCategory(FortuneCategory.ciftUyumu),
            readingNotifiers: _readingNotifiers,
            onTap: (r) => _openSonuc(r),
          ),
          ProfileScreen(
            user: user,
            onLogout: _handleLogout,
          ),
        ],
      ),
      bottomNavigationBar: FaloraAncientBottomNav(
        currentIndex: _tabIndex,
        onTap: (i) => setState(() => _tabIndex = i),
        bottomPadding: _mobileBottomInset(context),
      ),
    );
  }
}

// ─── Ana Sayfa ──────────────────────────────────────────────────────────────

class _AnaSayfa extends StatelessWidget {
  const _AnaSayfa({
    required this.userName,
    required this.tokens,
    required this.onCategoryTap,
    required this.onOpenShop,
    required this.onOpenReward,
  });

  final String userName;
  final int tokens;
  final void Function(FortuneCategory) onCategoryTap;
  final VoidCallback onOpenShop;
  final VoidCallback onOpenReward;

  @override
  Widget build(BuildContext context) {
    final categories = FortuneCategory.values;

    return FaloraBackground(
      child: SafeArea(
        bottom: false,
        child: Stack(
          children: [
            CustomScrollView(
              slivers: [
                SliverToBoxAdapter(
                  child: PremiumWelcomeHeader(userName: userName),
                ),
                SliverPadding(
                  padding: EdgeInsets.fromLTRB(
                    22,
                    12,
                    22,
                    28 + _mobileBottomInset(context),
                  ),
                  sliver: SliverList.separated(
                    itemCount: categories.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 16),
                    itemBuilder: (context, i) => PremiumCategoryCard(
                      category: categories[i],
                      onTap: () => onCategoryTap(categories[i]),
                    ),
                  ),
                ),
              ],
            ),
            Positioned(
              top: 8,
              right: 18,
              child: HomeQuickActions(
                tokens: tokens,
                onOpenShop: onOpenShop,
                onOpenReward: onOpenReward,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Fallarım ───────────────────────────────────────────────────────────────

class _FallarimPage extends StatelessWidget {
  const _FallarimPage({
    required this.readings,
    required this.readingNotifiers,
    required this.onTap,
  });

  final List<FortuneReading> readings;
  final Map<String, ValueNotifier<FortuneReading>> readingNotifiers;
  final void Function(FortuneReading) onTap;

  @override
  Widget build(BuildContext context) {
    if (readings.isEmpty) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.nights_stay, size: 64, color: _textSecondary),
            SizedBox(height: 16),
            Text(
              'Henüz falınız yok',
              style: TextStyle(color: _textSecondary, fontSize: 16),
            ),
            SizedBox(height: 8),
            Text(
              'Ana sayfadan bir fal türü seçin',
              style: TextStyle(color: _textSecondary, fontSize: 13),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: EdgeInsets.fromLTRB(16, 16, 16, 16 + _mobileBottomInset(context)),
      itemCount: readings.length,
      itemBuilder: (context, i) {
        final r = readings[i];
        final notifier = readingNotifiers[r.id];
        if (notifier == null) return const SizedBox.shrink();
        return ValueListenableBuilder<FortuneReading>(
          valueListenable: notifier,
          builder: (context, reading, _) {
            return ReadingRecordCard(
              leading: CategoryIconWidget(
                iconPath: reading.category.iconPath,
                fallbackIcon: reading.category.fallbackIcon,
                color: reading.category.color,
                size: 48,
                iconSize: 22,
              ),
              title: reading.isManualPremium
                  ? '${reading.category.label} · ${reading.manualReaderName ?? 'Özel'}'
                  : reading.category.label,
              subtitle: reading.isManualPremium
                  ? '${_formatDate(reading.createdAt)} · ${reading.isReadyDisplay ? 'Hazır' : 'Beklemede'}'
                  : _formatDate(reading.createdAt),
              reading: reading,
              onTap: () => onTap(reading),
            );
          },
        );
      },
    );
  }

  String _formatDate(DateTime d) => formatDate(d);

  static String formatDate(DateTime d) {
    return '${d.day.toString().padLeft(2, '0')}.'
        '${d.month.toString().padLeft(2, '0')}.'
        '${d.year} '
        '${d.hour.toString().padLeft(2, '0')}:'
        '${d.minute.toString().padLeft(2, '0')}';
  }
}

// ─── Çift Uyumu Sekmesi ──────────────────────────────────────────────────────

class CiftUyumuTab extends StatelessWidget {
  const CiftUyumuTab({
    super.key,
    required this.readings,
    required this.onStart,
    required this.readingNotifiers,
    required this.onTap,
  });

  final List<FortuneReading> readings;
  final VoidCallback onStart;
  final Map<String, ValueNotifier<FortuneReading>> readingNotifiers;
  final void Function(FortuneReading) onTap;

  @override
  Widget build(BuildContext context) {
    return CustomScrollView(
      slivers: [
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(22, 24, 22, 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                FaloraZodiacHero(
                  title: 'Çift Uyumu Analizi',
                  subtitle:
                      'Burç uyumu, çekim, iletişim ve ilişki potansiyelinizi keşfedin.',
                  accent: FortuneCategory.ciftUyumu.color,
                  tokenCost: coupleTokenCost,
                  onStart: onStart,
                ),
                const SizedBox(height: 24),
                const Text(
                  'Geçmiş Analizler',
                  style: TextStyle(
                    color: _textPrimary,
                    fontWeight: FontWeight.w600,
                    fontSize: 16,
                  ),
                ),
              ],
            ),
          ),
        ),
        if (readings.isEmpty)
          const SliverFillRemaining(
            hasScrollBody: false,
            child: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  FaIcon(
                    FontAwesomeIcons.peopleArrows,
                    size: 48,
                    color: _textSecondary,
                  ),
                  SizedBox(height: 14),
                  Text(
                    'Henüz çift uyumu analizi yok',
                    style: TextStyle(color: _textSecondary, fontSize: 15),
                  ),
                ],
              ),
            ),
          )
        else
          SliverPadding(
            padding: EdgeInsets.fromLTRB(16, 0, 16, 24 + _mobileBottomInset(context)),
            sliver: SliverList.separated(
              itemCount: readings.length,
              separatorBuilder: (_, _) => const SizedBox(height: 12),
              itemBuilder: (context, i) {
                final r = readings[i];
                final notifier = readingNotifiers[r.id];
                if (notifier == null) return const SizedBox.shrink();
                return ValueListenableBuilder<FortuneReading>(
                  valueListenable: notifier,
                  builder: (context, reading, _) {
                    return ReadingRecordCard(
                      leading: CategoryIconWidget(
                        iconPath: FortuneCategory.ciftUyumu.iconPath,
                        fallbackIcon: FortuneCategory.ciftUyumu.fallbackIcon,
                        color: FortuneCategory.ciftUyumu.color,
                        size: 48,
                        iconSize: 22,
                        hasGradient: true,
                      ),
                      title: _coupleListTitle(reading.summary),
                      subtitle: _FallarimPage.formatDate(reading.createdAt),
                      reading: reading,
                      onTap: () => onTap(reading),
                    );
                  },
                );
              },
            ),
          ),
      ],
    );
  }

  static String _coupleListTitle(String summary) {
    final lines = summary.split('\n');
    if (lines.length < 2) return 'Çift Uyumu';
    final kadin = lines[0].replaceFirst('Kadın: ', '').split(',').first.trim();
    final erkek = lines[1].replaceFirst('Erkek: ', '').split(',').first.trim();
    return '$kadin & $erkek';
  }
}

// ─── Normal Fal Formu ───────────────────────────────────────────────────────

typedef NormalSubmit = Future<void> Function(
  FortuneCategory cat,
  FortuneTeller teller,
  String name,
  int age,
  String burc,
  String niyet, {
  List<String>? photoNames,
  List<TarotCardSelection>? selectedTarotCards,
});

class NormalFalFormPage extends StatefulWidget {
  const NormalFalFormPage({
    super.key,
    required this.category,
    required this.teller,
    required this.onSubmit,
    required this.onOpenShop,
    this.prefill,
  });

  final FortuneCategory category;
  final FortuneTeller teller;
  final NormalSubmit onSubmit;
  final VoidCallback onOpenShop;
  final FortuneFormPrefill? prefill;

  @override
  State<NormalFalFormPage> createState() => _NormalFalFormPageState();
}

class _NormalFalFormPageState extends State<NormalFalFormPage> {
  final _formKey = GlobalKey<FormState>();
  final _nameCtrl = TextEditingController();
  final _ageCtrl = TextEditingController();
  final _niyetCtrl = TextEditingController();
  String _burc = burclar.first;
  bool _submitting = false;
  List<TarotCardSelection> _selectedTarotCards = const [];

  bool get _isTarot => widget.category == FortuneCategory.tarot;

  @override
  void initState() {
    super.initState();
    logFortuneVisibleCost(widget.category, widget.teller.id);
    final prefill = widget.prefill;
    if (prefill != null && prefill.hasAny) {
      prefill.applyToNameController(_nameCtrl);
      prefill.applyToAgeController(_ageCtrl);
      _burc = prefill.applyToZodiac(_burc);
    }
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _ageCtrl.dispose();
    _niyetCtrl.dispose();
    super.dispose();
  }

  Future<void> _openTarotPicker() async {
    final result = await showTarotCardPickerSheet(
      context,
      initialSelection: _selectedTarotCards,
    );
    if (result != null && mounted) {
      setState(() => _selectedTarotCards = result);
    }
  }

  Future<void> _submit() async {
    if (_submitting || !_formKey.currentState!.validate()) return;
    if (_isTarot && _selectedTarotCards.length != tarotSpreadCardCount) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Tarot falı için $tarotSpreadCardCount kart seçmelisiniz.',
          ),
        ),
      );
      return;
    }
    setState(() => _submitting = true);
    try {
      await widget.onSubmit(
        widget.category,
        widget.teller,
        _nameCtrl.text.trim(),
        int.parse(_ageCtrl.text.trim()),
        _burc,
        _niyetCtrl.text.trim(),
        selectedTarotCards:
            _isTarot ? _selectedTarotCards : null,
      );
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(widget.category.label)),
      body: SingleChildScrollView(
        padding: EdgeInsets.fromLTRB(
          20,
          20,
          20,
          20 + _mobileBottomInset(context),
        ),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              FaloraLiveTappableTokenBalance(onOpenShop: widget.onOpenShop),
              const SizedBox(height: 12),
              _FormHeader(category: widget.category, teller: widget.teller),
              const SizedBox(height: 20),
              FaloraLabeledFormField(
                label: 'İsim',
                controller: _nameCtrl,
                validator: (v) =>
                    (v == null || v.trim().isEmpty) ? 'İsim gerekli' : null,
              ),
              const SizedBox(height: 18),
              FaloraLabeledFormField(
                label: 'Yaş',
                controller: _ageCtrl,
                keyboardType: TextInputType.number,
                validator: (v) {
                  if (v == null || v.trim().isEmpty) return 'Yaş gerekli';
                  final age = int.tryParse(v.trim());
                  if (age == null || age < 1 || age > 120) {
                    return 'Geçerli bir yaş girin';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 18),
              FaloraLabeledDropdown<String>(
                label: 'Burç',
                value: _burc,
                items: burclar
                    .map((b) => DropdownMenuItem(value: b, child: Text(b)))
                    .toList(),
                onChanged: (v) => setState(() => _burc = v ?? _burc),
              ),
              const SizedBox(height: 18),
              FaloraLabeledFormField(
                label: 'Niyet',
                controller: _niyetCtrl,
                maxLines: 3,
                validator: (v) =>
                    (v == null || v.trim().isEmpty) ? 'Niyet gerekli' : null,
              ),
              if (_isTarot) ...[
                const SizedBox(height: 24),
                Row(
                  children: [
                    Expanded(
                      child: FaloraSealButton(
                        label: 'Kartları Seç',
                        icon: Icons.style_rounded,
                        enabled: !_submitting,
                        onPressed: _openTarotPicker,
                      ),
                    ),
                    const SizedBox(width: 12),
                    FaloraSelectionCounter(
                      selected: _selectedTarotCards.length,
                      total: tarotSpreadCardCount,
                      prefix:
                          '${_selectedTarotCards.length}/$tarotSpreadCardCount',
                    ),
                  ],
                ),
                if (_selectedTarotCards.isNotEmpty) ...[
                  const SizedBox(height: 16),
                  TarotSelectedCardsStrip(cards: _selectedTarotCards),
                ],
              ],
              const SizedBox(height: 32),
              FaloraPrimaryButton(
                label: 'Falı Gönder',
                loading: _submitting,
                onPressed: (_submitting ||
                        (_isTarot &&
                            _selectedTarotCards.length != tarotSpreadCardCount))
                    ? null
                    : _submit,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─── Kahve Falı Formu ───────────────────────────────────────────────────────

class KahveFormPage extends StatefulWidget {
  const KahveFormPage({
    super.key,
    required this.teller,
    required this.onSubmit,
    required this.onOpenShop,
    this.prefill,
  });

  final FortuneTeller teller;
  final NormalSubmit onSubmit;
  final VoidCallback onOpenShop;
  final FortuneFormPrefill? prefill;

  @override
  State<KahveFormPage> createState() => _KahveFormPageState();
}

class _KahveFormPageState extends State<KahveFormPage> {
  final _formKey = GlobalKey<FormState>();
  final _nameCtrl = TextEditingController();
  final _ageCtrl = TextEditingController();
  final _niyetCtrl = TextEditingController();
  String _burc = burclar.first;
  PickedImage? _fincan1;
  PickedImage? _fincan2;
  PickedImage? _tabak;
  bool _submitting = false;

  @override
  void initState() {
    super.initState();
    logFortuneVisibleCost(FortuneCategory.kahve, widget.teller.id);
    final prefill = widget.prefill;
    if (prefill != null && prefill.hasAny) {
      prefill.applyToNameController(_nameCtrl);
      prefill.applyToAgeController(_ageCtrl);
      _burc = prefill.applyToZodiac(_burc);
    }
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _ageCtrl.dispose();
    _niyetCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_submitting || !_formKey.currentState!.validate()) return;
    if (_fincan1 == null || _fincan2 == null || _tabak == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Lütfen 2 fincan ve 1 tabak fotoğrafı yükleyin. Tüm alanlar zorunludur.',
          ),
          backgroundColor: faloraBronzeDark,
        ),
      );
      return;
    }
    setState(() => _submitting = true);
    try {
      await widget.onSubmit(
        FortuneCategory.kahve,
        widget.teller,
        _nameCtrl.text.trim(),
        int.parse(_ageCtrl.text.trim()),
        _burc,
        _niyetCtrl.text.trim(),
        photoNames: [
          _fincan1!.name,
          _fincan2!.name,
          _tabak!.name,
        ],
      );
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Kahve Falı')),
      body: SingleChildScrollView(
        padding: EdgeInsets.fromLTRB(
          20,
          20,
          20,
          20 + _mobileBottomInset(context),
        ),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              FaloraLiveTappableTokenBalance(onOpenShop: widget.onOpenShop),
              const SizedBox(height: 12),
              _FormHeader(
                category: FortuneCategory.kahve,
                teller: widget.teller,
              ),
              const SizedBox(height: 20),
              FaloraLabeledFormField(
                label: 'İsim',
                controller: _nameCtrl,
                validator: (v) =>
                    (v == null || v.trim().isEmpty) ? 'İsim gerekli' : null,
              ),
              const SizedBox(height: 18),
              FaloraLabeledFormField(
                label: 'Yaş',
                controller: _ageCtrl,
                keyboardType: TextInputType.number,
                validator: (v) {
                  if (v == null || v.trim().isEmpty) return 'Yaş gerekli';
                  final age = int.tryParse(v.trim());
                  if (age == null || age < 1 || age > 120) {
                    return 'Geçerli bir yaş girin';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 18),
              FaloraLabeledDropdown<String>(
                label: 'Burç',
                value: _burc,
                items: burclar
                    .map((b) => DropdownMenuItem(value: b, child: Text(b)))
                    .toList(),
                onChanged: (v) => setState(() => _burc = v ?? _burc),
              ),
              const SizedBox(height: 18),
              FaloraLabeledFormField(
                label: 'Niyet',
                controller: _niyetCtrl,
                maxLines: 3,
                validator: (v) =>
                    (v == null || v.trim().isEmpty) ? 'Niyet gerekli' : null,
              ),
              const SizedBox(height: 24),
              const Text(
                'Fotoğraflar',
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  color: _textPrimary,
                  fontSize: 15,
                ),
              ),
              const SizedBox(height: 6),
              const Text(
                'Kahve falı için 2 fincan ve 1 tabak fotoğrafı yükleyin',
                style: TextStyle(color: _textSecondary, fontSize: 12),
              ),
              const SizedBox(height: 14),
              ImageUploadCard(
                label: 'Fincan Fotoğrafı 1',
                image: _fincan1,
                icon: FontAwesomeIcons.mugHot,
                accentColor: FortuneCategory.kahve.color,
                onChanged: (img) => setState(() => _fincan1 = img),
              ),
              const SizedBox(height: 12),
              ImageUploadCard(
                label: 'Fincan Fotoğrafı 2',
                image: _fincan2,
                icon: FontAwesomeIcons.mugHot,
                accentColor: FortuneCategory.kahve.color,
                onChanged: (img) => setState(() => _fincan2 = img),
              ),
              const SizedBox(height: 12),
              ImageUploadCard(
                label: 'Fincan Tabağı',
                image: _tabak,
                icon: FontAwesomeIcons.circleDot,
                accentColor: FortuneCategory.kahve.color,
                onChanged: (img) => setState(() => _tabak = img),
              ),
              const SizedBox(height: 32),
              ElevatedButton(
                onPressed: _submitting ? null : _submit,
                child: _submitting
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Text('Falı Gönder'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─── Çift Uyumu Formu ───────────────────────────────────────────────────────

typedef CiftSubmit = Future<void> Function({
  required String kadinIsim,
  required int kadinYas,
  required String kadinBurc,
  required String erkekIsim,
  required int erkekYas,
  required String erkekBurc,
  required PickedImage kadinFoto,
  required PickedImage erkekFoto,
});

class CiftUyumuFormPage extends StatefulWidget {
  const CiftUyumuFormPage({
    super.key,
    required this.onSubmit,
    required this.onOpenShop,
  });

  final CiftSubmit onSubmit;
  final VoidCallback onOpenShop;

  @override
  State<CiftUyumuFormPage> createState() => _CiftUyumuFormPageState();
}

class _CiftUyumuFormPageState extends State<CiftUyumuFormPage> {
  final _formKey = GlobalKey<FormState>();
  final _kadinIsim = TextEditingController();
  final _kadinYas = TextEditingController();
  final _erkekIsim = TextEditingController();
  final _erkekYas = TextEditingController();
  String _kadinBurc = burclar.first;
  String _erkekBurc = burclar.first;
  PickedImage? _kadinFoto;
  PickedImage? _erkekFoto;
  bool _submitting = false;

  @override
  void dispose() {
    _kadinIsim.dispose();
    _kadinYas.dispose();
    _erkekIsim.dispose();
    _erkekYas.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    debugPrint('COUPLE BUTTON CLICKED');
    if (_submitting) return;
    if (!_formKey.currentState!.validate()) {
      debugPrint('COUPLE FORM VALIDATION FAILED');
      return;
    }
    if (_kadinFoto == null || _erkekFoto == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Lütfen kadın ve erkek fotoğraflarını yükleyin. Her iki alan zorunludur.',
          ),
          backgroundColor: faloraBronzeDark,
        ),
      );
      return;
    }
    setState(() => _submitting = true);
    try {
      await widget.onSubmit(
        kadinIsim: _kadinIsim.text.trim(),
        kadinYas: int.parse(_kadinYas.text.trim()),
        kadinBurc: _kadinBurc,
        erkekIsim: _erkekIsim.text.trim(),
        erkekYas: int.parse(_erkekYas.text.trim()),
        erkekBurc: _erkekBurc,
        kadinFoto: _kadinFoto!,
        erkekFoto: _erkekFoto!,
      );
    } catch (e, stackTrace) {
      debugPrint('COUPLE ERROR: $e');
      debugPrint(stackTrace.toString());
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text(coupleErrorMessage)),
        );
      }
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Çift Uyumu')),
      body: SingleChildScrollView(
        padding: EdgeInsets.fromLTRB(
          20,
          20,
          20,
          20 + _mobileBottomInset(context),
        ),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              FaloraLiveTappableTokenBalance(onOpenShop: widget.onOpenShop),
              const SizedBox(height: 12),
              const _FormHeader(
                category: FortuneCategory.ciftUyumu,
                tokenCost: coupleTokenCost,
              ),
              const SizedBox(height: 24),
              _PersonSection(
                title: 'Kadın',
                color: FortuneCategory.ciftUyumu.color,
                isimCtrl: _kadinIsim,
                yasCtrl: _kadinYas,
                burc: _kadinBurc,
                onBurcChanged: (v) => setState(() => _kadinBurc = v),
                photo: _kadinFoto,
                onPhotoChanged: (img) => setState(() => _kadinFoto = img),
              ),
              const SizedBox(height: 24),
              _PersonSection(
                title: 'Erkek',
                color: const Color(0xFF5C4228),
                isimCtrl: _erkekIsim,
                yasCtrl: _erkekYas,
                burc: _erkekBurc,
                onBurcChanged: (v) => setState(() => _erkekBurc = v),
                photo: _erkekFoto,
                onPhotoChanged: (img) => setState(() => _erkekFoto = img),
              ),
              const SizedBox(height: 32),
              ElevatedButton(
                onPressed: _submitting ? null : _submit,
                child: _submitting
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : Text('Analizi Gönder · $coupleTokenCost jeton'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PersonSection extends StatelessWidget {
  const _PersonSection({
    required this.title,
    required this.color,
    required this.isimCtrl,
    required this.yasCtrl,
    required this.burc,
    required this.onBurcChanged,
    required this.photo,
    required this.onPhotoChanged,
  });

  final String title;
  final Color color;
  final TextEditingController isimCtrl;
  final TextEditingController yasCtrl;
  final String burc;
  final ValueChanged<String> onBurcChanged;
  final PickedImage? photo;
  final ValueChanged<PickedImage?> onPhotoChanged;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Icon(Icons.person, color: color),
                const SizedBox(width: 8),
                Text(
                  title,
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                    color: color,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            FaloraLabeledFormField(
              label: 'İsim',
              controller: isimCtrl,
              validator: (v) =>
                  (v == null || v.trim().isEmpty) ? 'İsim gerekli' : null,
            ),
            const SizedBox(height: 18),
            FaloraLabeledFormField(
              label: 'Yaş',
              controller: yasCtrl,
              keyboardType: TextInputType.number,
              validator: (v) {
                if (v == null || v.trim().isEmpty) return 'Yaş gerekli';
                final age = int.tryParse(v.trim());
                if (age == null || age < 1 || age > 120) {
                  return 'Geçerli bir yaş girin';
                }
                return null;
              },
            ),
            const SizedBox(height: 18),
            FaloraLabeledDropdown<String>(
              label: 'Burç',
              value: burc,
              items: burclar
                  .map((b) => DropdownMenuItem(value: b, child: Text(b)))
                  .toList(),
              onChanged: (v) => onBurcChanged(v ?? burc),
            ),
            const SizedBox(height: 18),
            ImageUploadCard(
              label: '$title Fotoğrafı',
              image: photo,
              icon: FontAwesomeIcons.camera,
              accentColor: color,
              onChanged: onPhotoChanged,
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Ortak Widget'lar ───────────────────────────────────────────────────────

class _FormHeader extends StatelessWidget {
  const _FormHeader({
    required this.category,
    this.teller,
    this.tokenCost,
  });

  final FortuneCategory category;
  final FortuneTeller? teller;
  final int? tokenCost;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        CategoryIconWidget(
          iconPath: category.iconPath,
          fallbackIcon: category.fallbackIcon,
          color: category.color,
          size: 44,
          iconSize: 24,
          hasGradient: category.hasGradientIcon,
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                category.label,
                style: FaloraTypography.titleLarge.copyWith(
                  fontSize: 20,
                  color: faloraInk,
                ),
              ),
              if (teller != null) ...[
                const SizedBox(height: 4),
                Text(
                  '${teller!.name} · ${resolveTellerTokenCost(category, teller!.id)} jeton',
                  style: FaloraTypography.bodyMedium.copyWith(
                    color: faloraInkSoft,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ] else if (tokenCost != null) ...[
                const SizedBox(height: 4),
                Text(
                  '$tokenCost jeton',
                  style: FaloraTypography.bodyMedium.copyWith(
                    color: faloraInkSoft,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ],
          ),
        ),
        if (teller != null) ...[
          const SizedBox(width: 12),
          FortuneTellerAvatar(
            teller: teller!,
            size: 52,
            borderWidth: 2,
          ),
        ],
      ],
    );
  }
}

// ─── Sonuç Ekranı ───────────────────────────────────────────────────────────

class SonucPage extends StatefulWidget {
  const SonucPage({
    super.key,
    required this.notifier,
    required this.userId,
  });

  final ValueNotifier<FortuneReading> notifier;
  final String userId;

  @override
  State<SonucPage> createState() => _SonucPageState();
}

class _SonucPageState extends State<SonucPage> {
  late FortuneReading _reading;
  ManualFortuneRequest? _manualRequest;
  StreamSubscription<ManualFortuneRequest?>? _manualSub;

  @override
  void initState() {
    super.initState();
    _reading = widget.notifier.value;
    widget.notifier.addListener(_onReadingChanged);
    if (_reading.isManualPremium) {
      _manualSub = ManualFortuneStorageService.instance
          .watchRequest(_reading.id)
          .listen((req) {
        if (req == null || !mounted) return;
        setState(() => _manualRequest = req);
        widget.notifier.value = req.toFortuneReading();
      });
    }
  }

  void _onReadingChanged() {
    if (!mounted) return;
    setState(() => _reading = widget.notifier.value);
  }

  @override
  void dispose() {
    _manualSub?.cancel();
    widget.notifier.removeListener(_onReadingChanged);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final reading = _reading;

    return Scaffold(
      appBar: AppBar(title: Text(reading.category.label)),
      body: reading.isViewable
          ? _SonucContent(
              reading: reading,
              answerImageInfo: _manualRequest?.answerImageInfo ?? const {},
            )
          : _SonucWaitingView(reading: reading),
    );
  }
}

class _SonucContent extends StatefulWidget {
  const _SonucContent({
    required this.reading,
    this.answerImageInfo = const {},
  });

  final FortuneReading reading;
  final Map<String, String> answerImageInfo;

  @override
  State<_SonucContent> createState() => _SonucContentState();
}

class _SonucContentState extends State<_SonucContent>
    with SingleTickerProviderStateMixin {
  late final ScrollController _scrollController;
  late final AnimationController _fadeCtrl;
  late final Animation<double> _fadeAnim;

  @override
  void initState() {
    super.initState();
    _scrollController = ScrollController();
    _fadeCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 650),
    );
    _fadeAnim = CurvedAnimation(parent: _fadeCtrl, curve: Curves.easeOut);
    _fadeCtrl.forward();
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _fadeCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final reading = widget.reading;
    final isError =
        isFortuneResultError(reading.result) || reading.isFailedDisplay;
    final isCouple = reading.category == FortuneCategory.ciftUyumu;
    final isAutoCategory = isAutoOnlyCategory(reading.category);
    final hasTarotCards = reading.category == FortuneCategory.tarot &&
        reading.selectedTarotCards.isNotEmpty;
    final compatibility = isCouple && !isError
        ? parseCompatibilityPercent(reading.result)
        : null;
    final bodyText = isError
        ? (reading.result.isNotEmpty ? reading.result : coupleErrorMessage)
        : isCouple
            ? stripCompatibilityHeader(reading.result)
            : reading.result;
    final paragraphs = splitFortuneParagraphs(bodyText);

    return FadeTransition(
      opacity: _fadeAnim,
      child: Scrollbar(
        controller: _scrollController,
        thumbVisibility: true,
        child: SingleChildScrollView(
          controller: _scrollController,
          padding: EdgeInsets.fromLTRB(
            18,
            12,
            18,
            32 + _mobileBottomInset(context),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Container(
                padding: const EdgeInsets.all(24),
                decoration: faloraGlassDecoration(
                  accent: reading.category.color,
                  radius: 26,
                  opacity: 0.2,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        CategoryIconWidget(
                          iconPath: reading.category.iconPath,
                          fallbackIcon: reading.category.fallbackIcon,
                          color: reading.category.color,
                          size: 52,
                          iconSize: 26,
                          hasGradient: reading.category.hasGradientIcon,
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                isCouple
                                    ? 'Uyum Raporu'
                                    : isAutoCategory
                                        ? reading.category.resultScreenTitle
                                        : 'Fal Yorumun',
                                style: FaloraTypography.sectionHeading.copyWith(
                                  fontSize: 12,
                                  letterSpacing: 1.1,
                                ),
                              ),
                              const SizedBox(height: 6),
                              Text(
                                isAutoCategory
                                    ? reading.category.resultScreenTitle
                                    : reading.category.label,
                                style: const TextStyle(
                                  fontWeight: FontWeight.w800,
                                  fontSize: 22,
                                  color: _textPrimary,
                                ),
                              ),
                              const SizedBox(height: 6),
                              Text(
                                reading.summary,
                                style: const TextStyle(
                                  color: _textSecondary,
                                  fontSize: 13,
                                  height: 1.45,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    if (compatibility != null) ...[
                      const SizedBox(height: 20),
                      Center(
                        child: CoupleCompatibilityDashboard(
                          percent: compatibility,
                          readingId: reading.id,
                        ),
                      ),
                      const SizedBox(height: 28),
                      Text(
                        'Detaylı Yorum',
                        style: FaloraTypography.sectionHeading.copyWith(
                          fontSize: 12,
                          letterSpacing: 1.1,
                        ),
                      ),
                      const SizedBox(height: 16),
                    ] else if (hasTarotCards) ...[
                      const SizedBox(height: 20),
                      Text(
                        'Seçilen Kartlar',
                        style: FaloraTypography.sectionHeading.copyWith(
                          fontSize: 12,
                          letterSpacing: 1.1,
                        ),
                      ),
                      const SizedBox(height: 12),
                      TarotResultCardsGrid(cards: reading.selectedTarotCards),
                      const SizedBox(height: 20),
                      Text(
                        'Tarot Yorumu',
                        style: FaloraTypography.sectionHeading.copyWith(
                          fontSize: 12,
                          letterSpacing: 1.1,
                        ),
                      ),
                      const SizedBox(height: 16),
                    ] else
                      const SizedBox(height: 24),
                    ...paragraphs.asMap().entries.map((entry) {
                      return Padding(
                        padding: EdgeInsets.only(
                          bottom: entry.key == paragraphs.length - 1 ? 0 : 20,
                        ),
                        child: Text(
                          entry.value,
                          style: TextStyle(
                            color: isError ? Colors.orangeAccent : _textPrimary,
                            fontSize: 16.5,
                            height: 1.95,
                            letterSpacing: 0.25,
                          ),
                        ),
                      );
                    }),
                    if (widget.answerImageInfo['base64']?.isNotEmpty == true) ...[
                      const SizedBox(height: 24),
                      Text(
                        'Falcı Görseli',
                        style: FaloraTypography.sectionHeading.copyWith(
                          fontSize: 12,
                          letterSpacing: 1.1,
                        ),
                      ),
                      const SizedBox(height: 12),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(14),
                        child: Image.memory(
                          base64Decode(widget.answerImageInfo['base64']!),
                          fit: BoxFit.cover,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 20),
              PremiumOutlinedButton(
                label: 'Fallarıma Dön',
                icon: Icons.arrow_back_rounded,
                onPressed: () => Navigator.of(context).pop(),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SonucWaitingView extends StatelessWidget {
  const _SonucWaitingView({required this.reading});

  final FortuneReading reading;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 420),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              SizedBox(
                width: 48,
                height: 48,
                child: CircularProgressIndicator(
                  strokeWidth: 3,
                  color: _accent.withValues(alpha: 0.9),
                ),
              ),
              const SizedBox(height: 24),
              Text(
                reading.isManualPremium
                    ? 'Falcın yorumunu hazırlıyor'
                    : reading.category.waitingMessage,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: _textPrimary,
                  fontSize: 17,
                  fontWeight: FontWeight.w500,
                  letterSpacing: 0.2,
                ),
              ),
              if (reading.isManualPremium) ...[
                const SizedBox(height: 12),
                const Text(
                  'Özel yorumun en kısa sürede hazırlanacak.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: _textSecondary,
                    fontSize: 14,
                    height: 1.45,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
