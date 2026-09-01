import 'dart:async';
import 'dart:convert';

import 'package:cookbuk/data/meal_plan_repository.dart';
import 'package:cookbuk/domain/meal_plan_slot.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

class ApiMealPlanRepository
    implements MealPlanRepository, MealPlanConnectionDiagnostics {
  ApiMealPlanRepository({
    String? baseUrl,
    List<String>? baseUrls,
    String sharedToken = '',
  }) : _baseUris = _parseBaseUris(baseUrls ?? [baseUrl ?? '']),
       _sharedToken = sharedToken.trim();

  final List<Uri> _baseUris;
  final String _sharedToken;
  final Map<String, MealPlanSlot> _offlineSlots = {};
  final List<_PendingMealPlanWrite> _pendingWrites = [];
  final StreamController<MealPlanSyncStatus> _syncStatusController =
      StreamController<MealPlanSyncStatus>.broadcast();
  late Uri _activeBaseUri = _baseUris.first;
  MealPlanSyncStatus _syncStatus = MealPlanSyncStatus.idle;
  DateTime? _lastSuccessfulConnectionAt;
  Future<void>? _pendingWritesLoad;
  Timer? _syncTimer;
  bool _isSyncing = false;

  void _ensureSyncTimer() {
    _syncTimer ??= Timer.periodic(
      const Duration(seconds: 10),
      (_) => unawaited(syncPendingChanges().catchError((_) {})),
    );
  }

  @override
  MealPlanSyncStatus get syncStatus => _syncStatus;

  @override
  Stream<MealPlanSyncStatus> get syncStatusChanges =>
      _syncStatusController.stream;

  @override
  List<String> get configuredBaseUrls =>
      _baseUris.map((uri) => uri.toString()).toList(growable: false);

  @override
  String get activeBaseUrl => _activeBaseUri.toString();

  @override
  int get pendingWriteCount => _pendingWrites.length;

  @override
  DateTime? get lastSuccessfulConnectionAt => _lastSuccessfulConnectionAt;

  @override
  Future<BackendConnectionTestResult> testConnection() async {
    await _ensurePendingWritesLoaded();
    try {
      await _send('GET', '/health');
      await syncPendingChanges();
      return BackendConnectionTestResult(
        isConnected: true,
        checkedAt: DateTime.now(),
        activeBaseUrl: activeBaseUrl,
        message: pendingWriteCount == 0
            ? 'Pi erreichbar. Keine offenen Änderungen.'
            : 'Pi erreichbar. $pendingWriteCount Änderung(en) warten noch.',
      );
    } on Object catch (error) {
      return BackendConnectionTestResult(
        isConnected: false,
        checkedAt: DateTime.now(),
        activeBaseUrl: activeBaseUrl,
        message: _errorMessage(error),
      );
    }
  }

  @override
  Future<List<MealPlanSlot>> getRange({
    required DateTime from,
    required DateTime to,
  }) async {
    await _ensurePendingWritesLoaded();
    await syncPendingChanges();
    try {
      final response = await _send(
        'GET',
        '/meal-plan',
        queryParameters: {'from': _dateKey(from), 'to': _dateKey(to)},
      );
      final decoded = jsonDecode(response);
      return (decoded as List<dynamic>)
          .map((item) => MealPlanSlot.fromJson(item as Map<String, dynamic>))
          .toList();
    } on Object catch (error) {
      if (!_isOfflineError(error)) rethrow;
      return _offlineRange(from: from, to: to);
    }
  }

  @override
  Future<void> setRecipe({
    required DateTime date,
    required String meal,
    required String recipeId,
  }) async {
    await _ensurePendingWritesLoaded();
    final body = {'slotType': 'recipe', 'recipeId': recipeId};
    try {
      await _upsert(date: date, meal: meal, body: body);
    } on Object catch (error) {
      if (!_isOfflineError(error)) rethrow;
      await _queueWrite(
        method: 'PUT',
        path: '/meal-plan/${_dateKey(date)}/$meal',
        body: body,
        applyLocal: () {
          final existing = _offlineSlots[_slotKey(date, meal)];
          _writeOfflineSlot(
            date: date,
            meal: meal,
            slotType: 'recipe',
            recipeId: recipeId,
            extras: existing?.extras ?? const [],
            recipeExtraIds: existing?.recipeExtraIds ?? const [],
          );
        },
      );
      throw MealPlanQueuedException(_queuedMessage());
    }
  }

  @override
  Future<void> setLeftovers({
    required DateTime date,
    required String meal,
  }) async {
    await _ensurePendingWritesLoaded();
    const body = {'slotType': 'leftovers'};
    try {
      await _upsert(date: date, meal: meal, body: body);
    } on Object catch (error) {
      if (!_isOfflineError(error)) rethrow;
      await _queueWrite(
        method: 'PUT',
        path: '/meal-plan/${_dateKey(date)}/$meal',
        body: body,
        applyLocal: () {
          final existing = _offlineSlots[_slotKey(date, meal)];
          _writeOfflineSlot(
            date: date,
            meal: meal,
            slotType: 'leftovers',
            extras: existing?.extras ?? const [],
            recipeExtraIds: existing?.recipeExtraIds ?? const [],
          );
        },
      );
      throw MealPlanQueuedException(_queuedMessage());
    }
  }

  @override
  Future<void> setAway({
    required DateTime date,
    required String meal,
    String reason = '',
  }) async {
    await _ensurePendingWritesLoaded();
    final normalizedExtras = _normalizeExtras([reason]);
    final body = {'slotType': 'away', 'extras': normalizedExtras};
    try {
      await _upsert(date: date, meal: meal, body: body);
    } on Object catch (error) {
      if (!_isOfflineError(error)) rethrow;
      await _queueWrite(
        method: 'PUT',
        path: '/meal-plan/${_dateKey(date)}/$meal',
        body: body,
        applyLocal: () {
          _writeOfflineSlot(
            date: date,
            meal: meal,
            slotType: 'away',
            extras: normalizedExtras,
            recipeExtraIds: const [],
          );
        },
      );
      throw MealPlanQueuedException(_queuedMessage());
    }
  }

  @override
  Future<void> setEmpty({required DateTime date, required String meal}) async {
    await _ensurePendingWritesLoaded();
    const body = {'slotType': 'empty'};
    try {
      await _upsert(date: date, meal: meal, body: body);
    } on Object catch (error) {
      if (!_isOfflineError(error)) rethrow;
      await _queueWrite(
        method: 'PUT',
        path: '/meal-plan/${_dateKey(date)}/$meal',
        body: body,
        applyLocal: () =>
            _writeOfflineSlot(date: date, meal: meal, slotType: 'empty'),
      );
      throw MealPlanQueuedException(_queuedMessage());
    }
  }

  @override
  Future<void> setExtras({
    required DateTime date,
    required String meal,
    required List<String> extras,
    List<String> recipeExtraIds = const [],
  }) async {
    await _ensurePendingWritesLoaded();
    final normalized = _normalizeExtras(extras);
    final normalizedRecipeExtraIds = _normalizeRecipeExtraIds(recipeExtraIds);
    final body = {
      'extras': normalized,
      'recipeExtraIds': normalizedRecipeExtraIds,
    };
    try {
      await _send(
        'PUT',
        '/meal-plan/${_dateKey(date)}/$meal/extras',
        body: body,
      );
    } on Object catch (error) {
      if (!_isOfflineError(error)) rethrow;
      await _queueWrite(
        method: 'PUT',
        path: '/meal-plan/${_dateKey(date)}/$meal/extras',
        body: body,
        applyLocal: () {
          final existing = _offlineSlots[_slotKey(date, meal)];
          _writeOfflineSlot(
            date: date,
            meal: meal,
            slotType: existing?.slotType ?? 'empty',
            recipeId: existing?.recipeId,
            extras: normalized,
            recipeExtraIds: normalizedRecipeExtraIds,
          );
        },
      );
      throw MealPlanQueuedException(_queuedMessage());
    }
  }

  @override
  Future<CloseDayResult> closeDay(DateTime date) async {
    await _ensurePendingWritesLoaded();
    final response = await _send(
      'POST',
      '/meal-plan/close-day/${_dateKey(date)}',
    );
    return CloseDayResult.fromJson(
      jsonDecode(response) as Map<String, dynamic>,
    );
  }

  @override
  Future<void> syncPendingChanges() async {
    await _ensurePendingWritesLoaded();
    if (_pendingWrites.isEmpty || _isSyncing) return;

    _isSyncing = true;
    _emitSyncStatus(
      MealPlanSyncStatus(
        phase: MealPlanSyncPhase.syncing,
        pendingCount: _pendingWrites.length,
        message: 'Synchronisiere ${_pendingWrites.length} Änderung(en)...',
      ),
    );
    try {
      while (_pendingWrites.isNotEmpty) {
        final pending = _pendingWrites.first;
        try {
          await _send(pending.method, pending.path, body: pending.body);
          _pendingWrites.removeAt(0);
          await _savePendingWrites();
          if (_pendingWrites.isNotEmpty) {
            _emitSyncStatus(
              MealPlanSyncStatus(
                phase: MealPlanSyncPhase.syncing,
                pendingCount: _pendingWrites.length,
                message:
                    'Synchronisiere ${_pendingWrites.length} Änderung(en)...',
              ),
            );
          }
        } on Object catch (error) {
          if (_isOfflineError(error)) {
            _emitSyncStatus(
              MealPlanSyncStatus(
                phase: MealPlanSyncPhase.queued,
                pendingCount: _pendingWrites.length,
                message: _queuedMessage(),
              ),
            );
            return;
          }
          _emitSyncStatus(
            MealPlanSyncStatus(
              phase: MealPlanSyncPhase.blocked,
              pendingCount: _pendingWrites.length,
              message: _errorMessage(error),
            ),
          );
          rethrow;
        }
      }
      _syncTimer?.cancel();
      _syncTimer = null;
      _emitSyncStatus(
        const MealPlanSyncStatus(
          phase: MealPlanSyncPhase.synced,
          message: 'Änderungen wurden mit dem Pi synchronisiert.',
        ),
      );
    } finally {
      _isSyncing = false;
    }
  }

  Future<void> _upsert({
    required DateTime date,
    required String meal,
    required Map<String, dynamic> body,
  }) async {
    await _send('PUT', '/meal-plan/${_dateKey(date)}/$meal', body: body);
  }

  Uri _uri(Uri baseUri, String path, {Map<String, String>? queryParameters}) {
    return baseUri.replace(
      path: '${baseUri.path}$path',
      queryParameters: queryParameters,
    );
  }

  Future<String> _send(
    String method,
    String path, {
    Map<String, String>? queryParameters,
    Map<String, dynamic>? body,
  }) async {
    Object? lastOfflineError;
    final orderedBaseUris = [
      _activeBaseUri,
      ..._baseUris.where((uri) => uri != _activeBaseUri),
    ];

    for (final baseUri in orderedBaseUris) {
      try {
        final response = await _sendToBaseUri(
          method,
          baseUri,
          path,
          queryParameters: queryParameters,
          body: body,
        );
        _activeBaseUri = baseUri;
        _lastSuccessfulConnectionAt = DateTime.now();
        return response;
      } on Object catch (error) {
        if (!_isOfflineError(error)) rethrow;
        lastOfflineError = error;
      }
    }

    throw lastOfflineError ?? TimeoutException('Backend unavailable');
  }

  Future<String> _sendToBaseUri(
    String method,
    Uri baseUri,
    String path, {
    Map<String, String>? queryParameters,
    Map<String, dynamic>? body,
  }) async {
    final headers = {
      ..._authHeaders(),
      if (body != null) 'Content-Type': 'application/json',
    };
    final encodedBody = body == null ? null : jsonEncode(body);
    final uri = _uri(baseUri, path, queryParameters: queryParameters);
    final response = await switch (method) {
      'GET' => http.get(uri, headers: headers).timeout(_requestTimeout),
      'POST' =>
        http
            .post(uri, headers: headers, body: encodedBody)
            .timeout(_requestTimeout),
      'PUT' =>
        http
            .put(uri, headers: headers, body: encodedBody)
            .timeout(_requestTimeout),
      _ => throw ApiMealPlanRepositoryException('Unsupported method: $method'),
    };

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw ApiMealPlanRepositoryException(_statusMessage(response.statusCode));
    }

    return response.body;
  }

  Map<String, String> _authHeaders() {
    if (_sharedToken.isEmpty) return const {};
    return {'x-cookbuk-token': _sharedToken};
  }

  String _dateKey(DateTime date) {
    return [
      date.year.toString().padLeft(4, '0'),
      date.month.toString().padLeft(2, '0'),
      date.day.toString().padLeft(2, '0'),
    ].join('-');
  }

  List<MealPlanSlot> _offlineRange({
    required DateTime from,
    required DateTime to,
  }) {
    final fromKey = _dateKey(from);
    final toKey = _dateKey(to);
    return _offlineSlots.values.where((slot) {
      final key = _dateKey(slot.plannedFor);
      return key.compareTo(fromKey) >= 0 && key.compareTo(toKey) <= 0;
    }).toList();
  }

  Future<void> _queueWrite({
    required String method,
    required String path,
    required Map<String, dynamic> body,
    required void Function() applyLocal,
  }) async {
    applyLocal();
    _pendingWrites.add(
      _PendingMealPlanWrite(method: method, path: path, body: body),
    );
    await _savePendingWrites();
    _emitSyncStatus(
      MealPlanSyncStatus(
        phase: MealPlanSyncPhase.queued,
        pendingCount: _pendingWrites.length,
        message: _queuedMessage(),
      ),
    );
    _ensureSyncTimer();
  }

  Future<void> _ensurePendingWritesLoaded() {
    return _pendingWritesLoad ??= _loadPendingWrites();
  }

  Future<void> _loadPendingWrites() async {
    final preferences = await SharedPreferences.getInstance();
    final encodedWrites =
        preferences.getStringList(_pendingWritesStorageKey) ?? const [];

    _pendingWrites
      ..clear()
      ..addAll(
        encodedWrites
            .map(_PendingMealPlanWrite.tryDecode)
            .whereType<_PendingMealPlanWrite>(),
      );

    if (_pendingWrites.isEmpty) return;
    _emitSyncStatus(
      MealPlanSyncStatus(
        phase: MealPlanSyncPhase.queued,
        pendingCount: _pendingWrites.length,
        message: _queuedMessage(),
      ),
    );
    _ensureSyncTimer();
  }

  Future<void> _savePendingWrites() async {
    final preferences = await SharedPreferences.getInstance();
    await preferences.setStringList(
      _pendingWritesStorageKey,
      _pendingWrites.map((write) => write.encode()).toList(),
    );
  }

  void _emitSyncStatus(MealPlanSyncStatus status) {
    _syncStatus = status;
    if (!_syncStatusController.isClosed) {
      _syncStatusController.add(status);
    }
  }

  void _writeOfflineSlot({
    required DateTime date,
    required String meal,
    required String slotType,
    String? recipeId,
    List<String> extras = const [],
    List<String> recipeExtraIds = const [],
  }) {
    _offlineSlots[_slotKey(date, meal)] = MealPlanSlot(
      plannedFor: DateTime(date.year, date.month, date.day),
      meal: meal,
      slotType: slotType,
      recipeId: recipeId,
      extras: extras,
      recipeExtraIds: recipeExtraIds,
    );
  }

  String _slotKey(DateTime date, String meal) => '${_dateKey(date)}:$meal';

  List<String> _normalizeExtras(List<String> values) {
    return values
        .map((value) => value.trim())
        .where((value) => value.isNotEmpty)
        .take(8)
        .toList();
  }

  List<String> _normalizeRecipeExtraIds(List<String> values) {
    return values
        .map((value) => value.trim())
        .where((value) => value.isNotEmpty)
        .toSet()
        .take(8)
        .toList();
  }

  bool _isOfflineError(Object error) {
    return error is TimeoutException || error is http.ClientException;
  }

  String _queuedMessage() {
    return 'Pi nicht erreichbar. Änderung vorgemerkt und wird automatisch synchronisiert, sobald die Verbindung zurück ist.';
  }

  String _errorMessage(Object error) {
    if (error is MealPlanSaveException) return error.userMessage;
    return 'Plan konnte nicht synchronisiert werden.';
  }

  String _statusMessage(int statusCode) {
    if (statusCode == 401 || statusCode == 403) {
      return 'Pi hat die Anfrage abgelehnt. Prüfe den CookBuk Token.';
    }
    if (statusCode >= 500) {
      return 'Pi Backend hat einen Serverfehler gemeldet.';
    }
    return 'Pi Backend konnte die Änderung nicht speichern. HTTP $statusCode.';
  }

  static List<Uri> _parseBaseUris(List<String> values) {
    final uris = values
        .map((value) => value.trim())
        .where((value) => value.isNotEmpty)
        .map((value) => Uri.parse(value.replaceFirst(RegExp(r'/$'), '')))
        .toList();
    if (uris.isNotEmpty) return uris;
    return [Uri.parse('http://127.0.0.1:3000')];
  }

  static const _requestTimeout = Duration(seconds: 2);
  static const _pendingWritesStorageKey = 'cookbuk.pendingMealPlanWrites';
}

class ApiMealPlanRepositoryException extends MealPlanSaveException {
  const ApiMealPlanRepositoryException(super.userMessage);
}

class _PendingMealPlanWrite {
  const _PendingMealPlanWrite({
    required this.method,
    required this.path,
    required this.body,
  });

  final String method;
  final String path;
  final Map<String, dynamic> body;

  String encode() {
    return jsonEncode({'method': method, 'path': path, 'body': body});
  }

  static _PendingMealPlanWrite? tryDecode(String value) {
    try {
      final decoded = jsonDecode(value) as Map<String, dynamic>;
      final method = decoded['method'] as String?;
      final path = decoded['path'] as String?;
      final body = decoded['body'] as Map<String, dynamic>?;
      if (method == null || path == null || body == null) return null;
      return _PendingMealPlanWrite(method: method, path: path, body: body);
    } catch (_) {
      return null;
    }
  }
}
