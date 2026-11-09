import 'dart:async';

import 'package:collection/collection.dart';
import 'package:kfusion/common/common.dart';
import 'package:kfusion/database/database.dart';
import 'package:kfusion/enum/enum.dart';
import 'package:kfusion/models/models.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'generated/database.g.dart';

Future<void> withRollback<T>({
  required T snapshot,
  required FutureOr<void> Function() action,
  required void Function(T snapshot) rollback,
}) async {
  try {
    await action();
  } catch (e, s) {
    rollback(snapshot);
    Error.throwWithStackTrace(e, s);
  }
}

Future<void> _persistOptimistically<T>(
  T previous,
  T next,
  T Function() read,
  void Function(T value) write,
  FutureOr<void> Function() action,
) async {
  write(next);
  try {
    await action();
  } catch (e, s) {
    if (identical(read(), next)) {
      write(previous);
    }
    Error.throwWithStackTrace(e, s);
  }
}

void _reportReread(Object error, StackTrace stackTrace) {
  commonPrint.log(
    'Database read-back failed: ${compactError(error)}, $stackTrace',
    logLevel: LogLevel.warning,
  );
}

void _reportOptimisticFailure(Object error, StackTrace stackTrace) {
  commonPrint.log(
    'Optimistic database write failed: ${compactError(error)}, $stackTrace',
    logLevel: LogLevel.warning,
  );
  dialogs.showNotifier(
    currentAppLocalizations.databaseWriteFailedTip,
    level: MessageLevel.error,
  );
}

/// Read-backs landing while a write is in flight can predate the write and
/// would briefly undo its optimistic value, so they wait for [idle]. One
/// turned away may carry a write made outside the notifier, so the rows are
/// read again once the writes settle.
class _Writes {
  final void Function() _reread;
  var _pending = 0;
  var _missed = false;

  _Writes(this._reread);

  bool get idle => _pending == 0;

  bool admit() {
    _missed |= !idle;
    return idle;
  }

  Future<void> track(Future<void> Function() write) async {
    _pending++;
    try {
      await write();
    } finally {
      _pending--;
      if (idle && _missed) {
        _missed = false;
        _reread();
      }
    }
  }
}

mixin OptimisticMixin<T> on AsyncNotifierMixin<T> {
  late final _writes = _Writes(_reread);
  Future<T> Function()? _query;

  Stream<T> settled(Stream<T> rows, Future<T> Function() query) {
    _query = query;
    return rows.where((_) => _writes.admit());
  }

  void _reread() {
    _query?.call().then((rows) {
      if (ref.mounted && _writes.admit()) {
        value = rows;
      }
    }, onError: _reportReread);
  }

  void optimistic(T next, FutureOr<void> Function() action) {
    unawaited(
      optimisticAsync(next, action).catchError(_reportOptimisticFailure),
    );
  }

  Future<void> optimisticAsync(T next, FutureOr<void> Function() action) {
    return _writes.track(
      () => _persistOptimistically(
        value,
        next,
        () => value,
        (v) => value = v,
        action,
      ),
    );
  }
}

@riverpod
Stream<List<Profile>> profilesStream(Ref ref) {
  return database.profilesDao.query().watch();
}

@Riverpod(keepAlive: true)
class Profiles extends _$Profiles {
  late final _writes = _Writes(_reread);

  @override
  List<Profile> build() {
    ref.listen(profilesStreamProvider, (_, next) {
      if (_writes.admit()) {
        state = next.value ?? [];
      }
    });
    return ref.read(profilesStreamProvider).value ?? [];
  }

  void _reread() {
    database.profilesDao.query().get().then((rows) {
      if (ref.mounted && _writes.admit()) {
        state = rows;
      }
    }, onError: _reportReread);
  }

  void _optimistic(List<Profile> next, FutureOr<void> Function() action) {
    unawaited(
      _optimisticAsync(next, action).catchError(_reportOptimisticFailure),
    );
  }

  var _queue = Future<void>.value();

  /// Writes run in turn and each writes the rows as the state holds them then,
  /// so a put issued before a rewrite landed writes it along, not over it.
  Future<void> _serial(Future<void> Function() write) {
    final run = _queue.then((_) => write());
    _queue = run.then<void>((_) {}, onError: (Object _) {});
    return run;
  }

  Future<void> _putLatest(Iterable<int> ids) async {
    for (final id in ids) {
      if (state.getProfile(id) case final profile?) {
        await database.profiles.put(profile.toCompanion());
      }
    }
  }

  Future<void> _optimisticAsync(
    List<Profile> next,
    FutureOr<void> Function() action,
  ) {
    return _writes.track(
      () => _persistOptimistically(
        state,
        next,
        () => state,
        (v) => state = v,
        action,
      ),
    );
  }

  Profile labeled(Profile profile) => state.optimizeLabel(profile);

  void put(Profile profile) {
    final newProfile = labeled(profile);
    final next = state.copyAndPut(
      newProfile,
      (item) => item.id == newProfile.id,
    );
    _optimistic(next, () => _serial(() => _putLatest([newProfile.id])));
  }

  Future<void> del(int id) {
    return _optimisticAsync(
      state.where((e) => e.id != id).toList(),
      () => _serial(() => database.deleteProfile(id)),
    );
  }

  void updateProfile(int profileId, Profile Function(Profile profile) builder) {
    final index = state.indexWhere((element) => element.id == profileId);
    if (index == -1) return;
    final newProfile = builder(state[index]);
    if (newProfile == state[index]) return;
    final next = List<Profile>.from(state);
    next[index] = newProfile;
    _optimistic(next, () => _serial(() => _putLatest([profileId])));
  }

  void reorder(List<Profile> profiles) {
    final next = List<Profile>.from(profiles);
    final moved = <int>[];
    next.forEachIndexed((index, item) {
      if (item.order != index) {
        next[index] = item.copyWith(order: index);
        moved.add(item.id);
      }
    });
    _optimistic(
      next,
      () => _serial(() => database.transaction(() => _putLatest(moved))),
    );
  }

  @override
  bool updateShouldNotify(List<Profile> previous, List<Profile> next) {
    return !profileListEquality.equals(previous, next);
  }
}

@riverpod
class ClashProviders extends _$ClashProviders
    with AsyncNotifierMixin, OptimisticMixin {
  @override
  Stream<List<ClashProvider>> build() {
    final query = database.clashProvidersDao.query();
    return settled(query.watch(), query.get);
  }

  @override
  List<ClashProvider> get value => state.value ?? [];

  void put(ClashProvider provider) {
    final next = List<ClashProvider>.from(value);
    final index = next.indexWhere((item) => item.id == provider.id);
    if (index != -1) {
      next[index] = provider;
    } else {
      next.add(provider);
    }
    optimistic(next, () => database.clashProviders.put(provider.toCompanion()));
  }

  void del(int id) {
    final next = List<ClashProvider>.from(value);
    final index = next.indexWhere((item) => item.id == id);
    if (index == -1) return;
    next.removeAt(index);
    optimistic(
      next,
      () => database.clashProviders.remove((t) => t.id.equals(id)),
    );
  }

  void order(int oldIndex, int newIndex) {
    final next = value.copyAndReorder(oldIndex, newIndex);
    final changed = <ClashProvidersCompanion>[];
    next.forEachIndexed((index, item) {
      if (item.order != index) {
        next[index] = item.copyWith(order: index);
        changed.add(item.toCompanion(index));
      }
    });
    optimistic(next, () => database.clashProvidersDao.putAll(changed));
  }

  @override
  bool updateShouldNotify(
    AsyncValue<List<ClashProvider>> previous,
    AsyncValue<List<ClashProvider>> next,
  ) {
    return !clashProviderListEquality.equals(previous.value, next.value);
  }
}

@Riverpod(keepAlive: true)
class IconSets extends _$IconSets with AsyncNotifierMixin, OptimisticMixin {
  @override
  Stream<List<IconSet>> build() {
    final query = database.iconSetsDao.query();
    return settled(query.watch(), query.get);
  }

  @override
  List<IconSet> get value => state.value ?? [];

  void put(IconSet iconSet) {
    final next = List<IconSet>.from(value);
    final index = next.indexWhere((item) => item.id == iconSet.id);
    if (index != -1) {
      next[index] = iconSet;
    } else {
      next.add(iconSet);
    }
    optimistic(next, () => database.iconSets.put(iconSet.toCompanion()));
  }

  void del(int id) {
    optimistic(
      value.where((item) => item.id != id).toList(),
      () => database.iconSets.remove((t) => t.id.equals(id)),
    );
  }

  void order(int oldIndex, int newIndex) {
    final next = value.copyAndReorder(oldIndex, newIndex);
    final changed = <IconSetsCompanion>[];
    next.forEachIndexed((index, item) {
      if (item.order != index) {
        next[index] = item.copyWith(order: index);
        changed.add(item.toCompanion(index));
      }
    });
    optimistic(next, () => database.iconSetsDao.putAll(changed));
  }

  @override
  bool updateShouldNotify(
    AsyncValue<List<IconSet>> previous,
    AsyncValue<List<IconSet>> next,
  ) {
    return !iconSetListEquality.equals(previous.value, next.value);
  }
}
