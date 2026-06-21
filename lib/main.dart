import 'dart:async';
import 'dart:convert';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:falora/ai_config.dart';
import 'package:falora/ai_result_cache.dart';
import 'package:falora/ai_service.dart';
import 'package:falora/app/auth_gate.dart';
import 'package:falora/category_icon.dart';
import 'package:falora/config/manual_fortune_config.dart';
import 'package:falora/firebase_messaging_background.dart';
import 'package:falora/firebase_options.dart';
import 'package:falora/image_upload_card.dart';
import 'package:falora/models/app_user.dart';
import 'package:falora/models/fortune_models.dart';
import 'package:falora/models/fortune_teller_models.dart';
import 'package:falora/models/manual_fortune_request.dart';
import 'package:falora/models/manual_fortune_reader.dart';
import 'package:falora/screens/fortune_teller_selection_screen.dart';
import 'package:falora/screens/manual_fortune_form_screen.dart';
import 'package:falora/services/manual_fortune_storage_service.dart';
import 'package:falora/openai_backend_service.dart';
import 'package:falora/picked_image.dart';
import 'package:falora/screens/profile_screen.dart';
import 'package:falora/services/ads/ad_service_bootstrap.dart';
import 'package:falora/services/fortune_storage_service.dart';
import 'package:falora/services/fortune_submit_logger.dart';
import 'package:falora/services/interstitial_ad_service.dart';
import 'package:falora/services/notification_backend_service.dart';
import 'package:falora/services/notification_service.dart';
import 'package:falora/services/play_billing_service.dart';
import 'package:falora/services/token_service.dart';
import 'package:falora/theme/falora_theme.dart';
import 'package:falora/screens/shop_screen.dart';
import 'package:falora/token_config.dart';
import 'package:falora/widgets/fortune_teller_avatar.dart';
import 'package:falora/widgets/premium_ui.dart';
import 'package:falora/widgets/reward_ad_helper.dart';

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
const _gold = faloraGold;
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
      title: 'Falora',
      debugShowCheckedModeBanner: false,
      theme: faloraTheme(),
      home: const AuthGate(),
    );
  }
}

class FaloraShell extends StatefulWidget {
  const FaloraShell({
    super.key,
    required this.user,
    required this.onLogout,
  });

  final AppUser user;
  final VoidCallback onLogout;

  @override
  State<FaloraShell> createState() => _FaloraShellState();
}

class _FaloraShellState extends State<FaloraShell> {
  int _tabIndex = 0;
  late AppUser _user;
  final List<FortuneReading> _fortuneRequests = [];
  final List<FortuneReading> _coupleCompatibilityRequests = [];
  final Map<String, ValueNotifier<FortuneReading>> _readingNotifiers = {};
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
    _user = widget.user;
    TokenService.instance.bindLiveUser(_userId);
    unawaited(PlayBillingService.instance.init());
    _loadUserFortunes();
  }

  @override
  void dispose() {
    PlayBillingService.instance.dispose();
    super.dispose();
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
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          'Yetersiz jeton. Bu işlem $tokenCost jeton gerektirir. '
          'Bakiyeniz: ${_liveUser.tokens}',
        ),
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

    final goShop = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Yetersiz Jeton'),
        content: const Text(
          'Bu özel yorum için 1500 jeton gerekiyor.\n'
          'Jeton bakiyeniz yetersiz.\n'
          'Jeton mağazasından paket satın alabilirsiniz.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Vazgeç'),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Jeton Yükle'),
          ),
        ],
      ),
    );

    if (goShop == true && mounted) {
      _openShop();
    }
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
    unawaited(
      NotificationBackendService.instance.notifyFortuneReady(
        userId: _userId,
        isCouple: isCouple,
      ),
    );
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

  void _addFortuneRequest(FortuneReading reading) {
    if (!mounted) return;
    setState(() => _fortuneRequests.insert(0, reading));
  }

  void _addCoupleRequest(FortuneReading reading) {
    if (!mounted) return;
    setState(() => _coupleCompatibilityRequests.insert(0, reading));
  }

  void _openSonuc(FortuneReading reading) {
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
      Navigator.of(context).push(
        faloraPageRoute<void>(
          CiftUyumuFormPage(onSubmit: _submitCiftUyumu),
        ),
      );
      return;
    }
    Navigator.of(context).push(
      faloraPageRoute<void>(
        FortuneTellerSelectionPage(
          category: cat,
          onTellerChosen: (ctx, teller) => _openFortuneForm(ctx, cat, teller),
          onManualReaderChosen: (ctx, reader) =>
              _openManualFortuneForm(ctx, cat, reader),
        ),
      ),
    );
  }

  void _openFortuneForm(
    BuildContext context,
    FortuneCategory cat,
    FortuneTeller teller,
  ) {
    if (_liveUser.tokens < teller.tokenCost) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Yetersiz jeton. ${teller.name} ${teller.tokenCost} jeton gerektirir. '
            'Bakiyeniz: ${_liveUser.tokens}',
          ),
        ),
      );
      return;
    }
    Navigator.of(context).push(
      faloraPageRoute<void>(
        cat == FortuneCategory.kahve
            ? KahveFormPage(teller: teller, onSubmit: _submitNormal)
            : NormalFalFormPage(
                category: cat,
                teller: teller,
                onSubmit: _submitNormal,
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
          onSubmit: _submitManualFortune,
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
    debugPrint('$logPrefix TOKEN DEDUCT START ($amount)');
    try {
      final ok = await TokenService.instance.spendTokens(_userId, amount);
      if (!ok) {
        throw FortuneSubmitException('Yetersiz jeton veya jeton düşülemedi.');
      }
      debugPrint('$logPrefix TOKEN DEDUCT OK');
    } catch (e, stackTrace) {
      debugPrint('$logPrefix REAL ERROR at TOKEN DEDUCT: $e');
      debugPrint(stackTrace.toString());
      if (e is FortuneSubmitException) rethrow;
      throw FortuneSubmitException('Jeton düşme hatası: $e');
    }
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
    if (!mounted) {
      list[idx] = updated;
      _readingNotifiers[id]?.value = updated;
      return;
    }
    setState(() => list[idx] = updated);
    _readingNotifiers[id]?.value = updated;

    if (result != null &&
        result.isNotEmpty &&
        !isFortuneResultError(result)) {
      unawaited(_markReadingReady(updated, list));
    }
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
        imageNames: photoNames ?? const [],
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
      try {
        await storage.markFortuneError(requestId);
      } catch (markError) {
        debugPrint('FORTUNE ERROR STATUS SAVE FAILED: $markError');
      }
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

  void _showCoupleBackendFailure(String requestId) {
    if (mounted) {
      _updateReading(
        _coupleCompatibilityRequests,
        requestId,
        result: coupleErrorMessage,
        firestoreStatus: 'error',
      );
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text(coupleErrorMessage)),
      );
    }
  }

  static const _coupleBackendTimeout = Duration(seconds: 15);

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
      try {
        await storage.markCoupleError(requestId);
      } catch (markError) {
        debugPrint('COUPLE ERROR STATUS SAVE FAILED: $markError');
      }
      _showCoupleBackendFailure(requestId);
    } catch (e, stackTrace) {
      debugPrint('COUPLE ERROR: $e');
      debugPrint(stackTrace.toString());
      try {
        await storage.markCoupleError(requestId);
      } catch (markError) {
        debugPrint('COUPLE ERROR STATUS SAVE FAILED: $markError');
      }
      if (!mounted) return;
      _updateReading(
        _coupleCompatibilityRequests,
        requestId,
        result: coupleErrorMessage,
        firestoreStatus: 'error',
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text(coupleErrorMessage)),
        );
      }
    }
  }

  void _navigateAfterFortuneSubmit({
    required String logPrefix,
    required int tabIndex,
    required String successMessage,
    FortuneReading? openReading,
  }) {
    debugPrint('$logPrefix NAVIGATION START');
    if (!mounted) {
      debugPrint('$logPrefix NAVIGATION SKIPPED (not mounted)');
      return;
    }
    Navigator.of(context).pop();
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
  }) async {
    await FortuneSubmitLogger.logSubmitStart(
      fortuneType: cat.label,
      selectedReader: '${teller.id} (${teller.name})',
      isManualReader: false,
      endpoint: '$apiBaseUrl/generate-fortune',
      requestBody: {
        'flow': 'ai_token',
        'tellerId': teller.id,
        'tokenCost': teller.tokenCost,
        'billingUsed': false,
      },
    );

    final storage = FortuneStorageService.instance;
    String? requestId;
    var tokensDeducted = false;

    try {
      if (!_checkTokenBalance(
        logPrefix: 'FORTUNE',
        tokenCost: teller.tokenCost,
      )) {
        return;
      }
      debugPrint('FORTUNE VALIDATION OK');

      requestId = storage.newFortuneId();
      final now = DateTime.now();

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
          imageNames: photoNames ?? const [],
          tellerId: teller.id,
          tellerName: teller.name,
        );
        debugPrint('FORTUNE REQUEST CREATE OK');
      } catch (e, stackTrace) {
        debugPrint('FORTUNE REAL ERROR at REQUEST CREATE: $e');
        debugPrint(stackTrace.toString());
        rethrow;
      }

      try {
        await _deductSubmitTokens(
          logPrefix: 'FORTUNE',
          amount: teller.tokenCost,
        );
        tokensDeducted = true;
      } catch (e, stackTrace) {
        debugPrint('FORTUNE REAL ERROR at TOKEN DEDUCT: $e');
        debugPrint(stackTrace.toString());
        rethrow;
      }

      final summary =
          '${cat.label} — ${teller.name} — $name, $age, $burc\nNiyet: $niyet';
      final reading = FortuneReading(
        id: requestId,
        category: cat,
        status: FortuneStatus.hazirlaniyor,
        createdAt: now,
        summary: summary,
        result: '',
        firestoreStatus: 'pending',
        usesDelayGate: false,
      );
      _registerReading(reading);
      _addFortuneRequest(reading);

      _navigateAfterFortuneSubmit(
        logPrefix: 'FORTUNE',
        tabIndex: 1,
        successMessage: 'Falınız hazırlanıyor...',
        openReading: reading,
      );
      unawaited(_onFortuneSubmitted());
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
        ),
      );
    } on FortuneSubmitException catch (e) {
      FortuneSubmitLogger.logError(e);
      if (requestId != null && !tokensDeducted) {
        await _rollbackFortuneRequest(requestId);
      }
      _showSubmitError('Fal oluşturulamadı, jetonun düşmedi.');
    } catch (e, stackTrace) {
      FortuneSubmitLogger.logError(e, stackTrace);
      if (requestId != null && !tokensDeducted) {
        await _rollbackFortuneRequest(requestId);
      }
      _showSubmitError('Fal oluşturulamadı, jetonun düşmedi.');
    }
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

    if (!await _checkManualFortuneTokenBalance()) return;

    final storage = ManualFortuneStorageService.instance;
    final requestId = storage.newRequestId();
    final now = DateTime.now();
    var tokensDeducted = false;

    try {
      await _deductSubmitTokens(logPrefix: 'MANUAL', amount: tokenCost);
      tokensDeducted = true;

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

      final summary =
          '${category.label} — ${reader.name} (Özel)\n$name, $age, $zodiac\nNiyet: $intention';
      final reading = FortuneReading(
        id: requestId,
        category: category,
        status: FortuneStatus.hazirlaniyor,
        createdAt: now,
        summary: summary,
        result: '',
        firestoreStatus: 'pending',
        isManualPremium: true,
        manualReaderName: reader.name,
      );
      _registerReading(reading);
      _addFortuneRequest(reading);

      _navigateAfterFortuneSubmit(
        logPrefix: 'MANUAL',
        tabIndex: 1,
        successMessage:
            'Özel fal talebin alındı. $tokenCost jeton hesabından düşüldü.',
        openReading: reading,
      );
    } on ManualFortuneException catch (e) {
      FortuneSubmitLogger.logError(e);
      if (tokensDeducted) {
        await TokenService.instance.addTokens(_userId, tokenCost);
      }
      _showSubmitError(e.message);
    } catch (e, stackTrace) {
      FortuneSubmitLogger.logError(e, stackTrace);
      if (tokensDeducted) {
        await TokenService.instance.addTokens(_userId, tokenCost);
      }
      _showSubmitError('Talep oluşturulamadı. Lütfen tekrar deneyin.');
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
      if (!_checkTokenBalance(
        logPrefix: 'COUPLE',
        tokenCost: coupleTokenCost,
      )) {
        return;
      }
      debugPrint('COUPLE VALIDATION OK');

      await _validateCoupleImages(
        kadinFoto: kadinFoto,
        erkekFoto: erkekFoto,
      );

      requestId = storage.newCoupleId();
      final now = DateTime.now();
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
          womanImageName: kadinFoto.name,
          manImageName: erkekFoto.name,
        );
        debugPrint('COUPLE REQUEST CREATE OK');
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

      final reading = FortuneReading(
        id: requestId,
        category: FortuneCategory.ciftUyumu,
        status: FortuneStatus.hazirlaniyor,
        createdAt: now,
        summary: summary,
        result: '',
        firestoreStatus: 'pending',
        usesDelayGate: false,
      );
      _registerReading(reading);
      _addCoupleRequest(reading);

      _navigateAfterFortuneSubmit(
        logPrefix: 'COUPLE',
        tabIndex: 2,
        successMessage: 'Uyum raporunuz hazırlanıyor...',
        openReading: reading,
      );
      unawaited(_onFortuneSubmitted());
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
    } on FortuneSubmitException catch (e) {
      debugPrint('COUPLE SUBMIT ERROR: ${e.message}');
      debugPrint('COUPLE REAL ERROR: ${e.message}');
      if (requestId != null && !tokensDeducted) {
        await _rollbackCoupleRequest(requestId);
      }
      _showSubmitError('Çift uyumu oluşturulamadı, jetonun düşmedi.');
    } catch (e, stackTrace) {
      debugPrint('COUPLE SUBMIT ERROR: $e');
      debugPrint('COUPLE REAL ERROR: $e');
      debugPrint(stackTrace.toString());
      if (requestId != null && !tokensDeducted) {
        await _rollbackCoupleRequest(requestId);
      }
      _showSubmitError('Çift uyumu oluşturulamadı, jetonun düşmedi.');
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
                    child: _TokenChip(tokens: user.tokens),
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
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          border: Border(
            top: BorderSide(color: Colors.white.withValues(alpha: 0.06)),
          ),
          boxShadow: [
            BoxShadow(
              color: faloraAccent.withValues(alpha: 0.08),
              blurRadius: 20,
              offset: const Offset(0, -4),
            ),
          ],
        ),
        child: Padding(
          padding: EdgeInsets.only(bottom: _mobileBottomInset(context)),
          child: BottomNavigationBar(
            currentIndex: _tabIndex,
            onTap: (i) => setState(() => _tabIndex = i),
            items: const [
              BottomNavigationBarItem(icon: Icon(Icons.home_rounded), label: 'Ana Sayfa'),
              BottomNavigationBarItem(icon: Icon(Icons.auto_stories_rounded), label: 'Fallarım'),
              BottomNavigationBarItem(icon: Icon(Icons.favorite_rounded), label: 'Çift Uyumu'),
              BottomNavigationBarItem(icon: Icon(Icons.person_rounded), label: 'Profil'),
            ],
          ),
        ),
      ),
    );
  }
}

class _TokenChip extends StatelessWidget {
  const _TokenChip({required this.tokens});

  final int tokens;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: _gold.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: _gold.withValues(alpha: 0.35)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.toll, color: _gold, size: 16),
          const SizedBox(width: 4),
          Text(
            '$tokens',
            style: const TextStyle(
              color: _gold,
              fontWeight: FontWeight.bold,
              fontSize: 13,
            ),
          ),
        ],
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
        final hazir = r.displayStatus == FortuneStatus.hazir;
        return Card(
          margin: const EdgeInsets.only(bottom: 12),
          child: ListTile(
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            leading: CategoryIconWidget(
              iconPath: r.category.iconPath,
              fallbackIcon: r.category.fallbackIcon,
              color: r.category.color,
              size: 44,
              iconSize: 24,
            ),
            title: Text(
              r.isManualPremium
                  ? '${r.category.label} · ${r.manualReaderName ?? 'Özel'}'
                  : r.category.label,
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
            subtitle: Text(
              r.isManualPremium
                  ? '${_formatDate(r.createdAt)} · ${hazir ? 'Hazır' : 'Beklemede'}'
                  : _formatDate(r.createdAt),
              style: const TextStyle(color: _textSecondary, fontSize: 12),
            ),
            trailing: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: hazir
                    ? Colors.green.withValues(alpha: 0.2)
                    : Colors.orange.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                hazir
                    ? 'Hazır'
                    : (r.isManualPremium ? 'Beklemede' : 'Hazırlanıyor'),
                style: TextStyle(
                  color: hazir ? Colors.greenAccent : Colors.orangeAccent,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            onTap: readingNotifiers.containsKey(r.id) ? () => onTap(r) : null,
          ),
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
                Container(
                  padding: const EdgeInsets.all(22),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(20),
                    gradient: LinearGradient(
                      colors: [
                        FortuneCategory.ciftUyumu.color.withValues(alpha: 0.18),
                        _accent.withValues(alpha: 0.1),
                      ],
                    ),
                    border: Border.all(
                      color: FortuneCategory.ciftUyumu.color.withValues(alpha: 0.2),
                    ),
                  ),
                  child: Column(
                    children: [
                      CategoryIconWidget(
                        iconPath: FortuneCategory.ciftUyumu.iconPath,
                        fallbackIcon: FortuneCategory.ciftUyumu.fallbackIcon,
                        color: FortuneCategory.ciftUyumu.color,
                        size: 44,
                        iconSize: 24,
                        hasGradient: true,
                      ),
                      const SizedBox(height: 14),
                      const Text(
                        'Çift Uyumu Analizi',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: _textPrimary,
                        ),
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        'Burç uyumu, çekim, iletişim ve ilişki potansiyelinizi keşfedin.',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: _textSecondary, height: 1.5),
                      ),
                      const SizedBox(height: 18),
                      ElevatedButton.icon(
                        onPressed: onStart,
                        icon: const FaIcon(FontAwesomeIcons.wandMagicSparkles, size: 16),
                        label: const Text('Yeni Analiz Başlat'),
                      ),
                    ],
                  ),
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
                final hazir = r.displayStatus == FortuneStatus.hazir;
                return Card(
                  child: ListTile(
                    contentPadding:
                        const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    leading: CategoryIconWidget(
                      iconPath: FortuneCategory.ciftUyumu.iconPath,
                      fallbackIcon: FortuneCategory.ciftUyumu.fallbackIcon,
                      color: FortuneCategory.ciftUyumu.color,
                      size: 44,
                      iconSize: 24,
                      hasGradient: true,
                    ),
                    title: Text(
                      _coupleListTitle(r.summary),
                      style: const TextStyle(fontWeight: FontWeight.w600),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    subtitle: Text(
                      _FallarimPage.formatDate(r.createdAt),
                      style: const TextStyle(color: _textSecondary, fontSize: 12),
                    ),
                    trailing: Container(
                      padding:
                          const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: hazir
                            ? Colors.green.withValues(alpha: 0.2)
                            : Colors.orange.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        hazir ? 'Hazır' : 'Hazırlanıyor',
                        style: TextStyle(
                          color: hazir ? Colors.greenAccent : Colors.orangeAccent,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    onTap: readingNotifiers.containsKey(r.id) ? () => onTap(r) : null,
                  ),
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
});

class NormalFalFormPage extends StatefulWidget {
  const NormalFalFormPage({
    super.key,
    required this.category,
    required this.teller,
    required this.onSubmit,
  });

  final FortuneCategory category;
  final FortuneTeller teller;
  final NormalSubmit onSubmit;

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

  @override
  void dispose() {
    _nameCtrl.dispose();
    _ageCtrl.dispose();
    _niyetCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_submitting || !_formKey.currentState!.validate()) return;
    setState(() => _submitting = true);
    try {
      await widget.onSubmit(
        widget.category,
        widget.teller,
        _nameCtrl.text.trim(),
        int.parse(_ageCtrl.text.trim()),
        _burc,
        _niyetCtrl.text.trim(),
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
              _FormHeader(category: widget.category, teller: widget.teller),
              const SizedBox(height: 24),
              TextFormField(
                controller: _nameCtrl,
                decoration: const InputDecoration(labelText: 'İsim'),
                validator: (v) =>
                    (v == null || v.trim().isEmpty) ? 'İsim gerekli' : null,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _ageCtrl,
                decoration: const InputDecoration(labelText: 'Yaş'),
                keyboardType: TextInputType.number,
                validator: (v) {
                  if (v == null || v.trim().isEmpty) return 'Yaş gerekli';
                  final age = int.tryParse(v.trim());
                  if (age == null || age < 1 || age > 120) return 'Geçerli bir yaş girin';
                  return null;
                },
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<String>(
                initialValue: _burc,
                decoration: const InputDecoration(labelText: 'Burç'),
                dropdownColor: _card,
                items: burclar
                    .map((b) => DropdownMenuItem(value: b, child: Text(b)))
                    .toList(),
                onChanged: (v) => setState(() => _burc = v!),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _niyetCtrl,
                decoration: const InputDecoration(labelText: 'Niyet'),
                maxLines: 3,
                validator: (v) =>
                    (v == null || v.trim().isEmpty) ? 'Niyet gerekli' : null,
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

// ─── Kahve Falı Formu ───────────────────────────────────────────────────────

class KahveFormPage extends StatefulWidget {
  const KahveFormPage({super.key, required this.teller, required this.onSubmit});

  final FortuneTeller teller;
  final NormalSubmit onSubmit;

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
          backgroundColor: Color(0xFFB76E79),
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
              _FormHeader(
                category: FortuneCategory.kahve,
                teller: widget.teller,
              ),
              const SizedBox(height: 24),
              TextFormField(
                controller: _nameCtrl,
                decoration: const InputDecoration(labelText: 'İsim'),
                validator: (v) =>
                    (v == null || v.trim().isEmpty) ? 'İsim gerekli' : null,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _ageCtrl,
                decoration: const InputDecoration(labelText: 'Yaş'),
                keyboardType: TextInputType.number,
                validator: (v) {
                  if (v == null || v.trim().isEmpty) return 'Yaş gerekli';
                  final age = int.tryParse(v.trim());
                  if (age == null || age < 1 || age > 120) return 'Geçerli bir yaş girin';
                  return null;
                },
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<String>(
                initialValue: _burc,
                decoration: const InputDecoration(labelText: 'Burç'),
                dropdownColor: _card,
                items: burclar
                    .map((b) => DropdownMenuItem(value: b, child: Text(b)))
                    .toList(),
                onChanged: (v) => setState(() => _burc = v!),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _niyetCtrl,
                decoration: const InputDecoration(labelText: 'Niyet'),
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
  const CiftUyumuFormPage({super.key, required this.onSubmit});

  final CiftSubmit onSubmit;

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
          backgroundColor: Color(0xFFB76E79),
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
              const _FormHeader(category: FortuneCategory.ciftUyumu),
              const SizedBox(height: 24),
              _PersonSection(
                title: 'Kadın',
                color: const Color(0xFFE879A8),
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
                color: const Color(0xFF64B5F6),
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
                    : const Text('Analizi Gönder'),
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
            TextFormField(
              controller: isimCtrl,
              decoration: InputDecoration(labelText: 'İsim'),
              validator: (v) =>
                  (v == null || v.trim().isEmpty) ? 'İsim gerekli' : null,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: yasCtrl,
              decoration: const InputDecoration(labelText: 'Yaş'),
              keyboardType: TextInputType.number,
              validator: (v) {
                if (v == null || v.trim().isEmpty) return 'Yaş gerekli';
                final age = int.tryParse(v.trim());
                if (age == null || age < 1 || age > 120) return 'Geçerli bir yaş girin';
                return null;
              },
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              initialValue: burc,
              decoration: const InputDecoration(labelText: 'Burç'),
              dropdownColor: _card,
              items: burclar
                  .map((b) => DropdownMenuItem(value: b, child: Text(b)))
                  .toList(),
              onChanged: (v) => onBurcChanged(v!),
            ),
            const SizedBox(height: 12),
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
  const _FormHeader({required this.category, this.teller});

  final FortuneCategory category;
  final FortuneTeller? teller;

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
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: _textPrimary,
                ),
              ),
              if (teller != null) ...[
                const SizedBox(height: 4),
                Text(
                  '${teller!.name} · ${teller!.tokenCost} jeton',
                  style: TextStyle(
                    fontSize: 13,
                    color: teller!.accentColor.withValues(alpha: 0.95),
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
    final isError = isFortuneResultError(reading.result);
    final isCouple = reading.category == FortuneCategory.ciftUyumu;
    final compatibility = isCouple && !isError
        ? parseCompatibilityPercent(reading.result)
        : null;
    final bodyText = isError
        ? reading.result
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
                                isCouple ? 'Uyum Raporu' : 'Fal Yorumun',
                                style: TextStyle(
                                  color: faloraGold.withValues(alpha: 0.9),
                                  fontSize: 12,
                                  fontWeight: FontWeight.w700,
                                  letterSpacing: 1.1,
                                ),
                              ),
                              const SizedBox(height: 6),
                              Text(
                                reading.category.label,
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
                        style: TextStyle(
                          color: faloraGold.withValues(alpha: 0.9),
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
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
                      const Text(
                        'Falcı Görseli',
                        style: TextStyle(
                          color: faloraGold,
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
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
