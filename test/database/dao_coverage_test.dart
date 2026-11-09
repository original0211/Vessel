import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:kfusion/database/database.dart';
import 'package:kfusion/enum/enum.dart';
import 'package:kfusion/models/models.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late Database database;

  setUp(() {
    database = Database(NativeDatabase.memory());
  });

  tearDown(() async {
    await database.close();
  });

  test(
    'profiles DAO round-trips fields, ordering, filenames, and setAll',
    () async {
      final first = Profile(
        id: 1,
        label: 'First',
        currentGroupName: 'Selector',
        url: 'https://first.example',
        lastUpdateDate: DateTime(2026, 1, 2),
        autoUpdateDuration: const Duration(hours: 6),
        subscriptionInfo: const SubscriptionInfo(
          upload: 1,
          download: 2,
          total: 3,
          expire: 4,
        ),
        autoUpdate: false,
        selectedMap: const {'Selector': 'Proxy'},
        unfoldSet: const {'Selector'},
        type: ProfileType.url,
        order: 1,
      );
      const second = Profile(
        id: 2,
        label: 'Second',
        autoUpdateDuration: Duration.zero,
        order: 0,
      );

      await database.profilesDao.putAll([
        first.toCompanion(),
        second.toCompanion(),
      ]);

      final profiles = await database.profilesDao.query().get();
      expect(profiles.map((profile) => profile.id), [2, 1]);
      expect(profiles.last, first);
      expect(await database.profilesDao.fileNames().get(), [
        '1.yaml',
        '2.yaml',
      ]);
      expect(await database.profiles.count.getSingle(), 2);

      final replacement = first.copyWith(label: 'Replaced', order: 0);
      await database.profilesDao.setAll([replacement]);

      expect(await database.profilesDao.query().get(), [replacement]);
      expect(await database.profiles.remove((table) => table.id.equals(1)), 1);
      expect(await database.profiles.count.getSingle(), 0);
    },
  );

  test('profiles query skips a row it cannot read and keeps it', () async {
    const readable = Profile(
      id: 1,
      label: 'Readable',
      autoUpdateDuration: Duration.zero,
    );
    await database.profilesDao.putAll([readable.toCompanion()]);
    await database.customStatement(
      'INSERT INTO profiles (id, type, label, url, '
      'auto_update_duration_millis, auto_update, selected_map, unfold_set) '
      "VALUES (2, 'future', 'Future', '', 0, 1, '{}', '[]')",
    );

    expect(await database.profilesDao.query().get(), [readable]);
    expect(await database.profilesDao.ids().get(), [1, 2]);
  });

  test('provider queries skip a row they cannot read', () async {
    await database.customStatement(
      'INSERT INTO clash_providers (id, kind, label, url, behavior) VALUES '
      "(1, 'rule', 'Kept', 'https://a.example', 'domain'), "
      "(2, 'rule', 'Future', 'https://b.example', 'future')",
    );

    final providers = await database.clashProvidersDao.query().get();
    expect(providers.map((provider) => provider.id), [1]);
    expect(await database.clashProvidersDao.fileNames().get(), [
      providers.single.fileName,
      const ClashProvider(id: 2, label: '', url: 'https://b.example').fileName,
    ]);
  });

  test('profiles query resets damaged JSON columns of a profile', () async {
    await database.customStatement(
      'INSERT INTO profiles (id, type, label, url, '
      'auto_update_duration_millis, auto_update, selected_map, unfold_set, '
      'subscription_info) '
      "VALUES (1, 'url', 'Damaged', '', 0, 1, 'x', '{}', '[')",
    );

    final profile = (await database.profilesDao.query().get()).single;
    expect(profile.label, 'Damaged');
    expect(profile.selectedMap, isEmpty);
    expect(profile.unfoldSet, isEmpty);
    expect(profile.subscriptionInfo, null);
  });

  test(
    'generated table managers create, filter, order, and update rows',
    () async {
      await database.managers.profiles.create(
        (row) => row(
          type: ProfileType.custom,
          label: 'Managed profile',
          url: 'https://example.com/profile.yaml',
          autoUpdateDurationMillis: 60000,
          autoUpdate: true,
          selectedMap: const {'Proxy': 'DIRECT'},
          unfoldSet: const {'Proxy'},
        ),
      );
      await database.managers.iconRecords.create(
        (row) => row(url: 'https://example.com/icon.png', lastAccessed: 1),
      );

      final profiles = await database.managers.profiles
          .filter((row) => row.label.contains('Managed'))
          .orderBy((row) => row.label.asc())
          .get();
      expect(profiles.single.label, 'Managed profile');

      await database.managers.profiles
          .filter((row) => row.id.equals(profiles.single.id))
          .update((row) => row(label: const Value('Updated profile')));
      expect(
        (await database.managers.profiles
                .filter((row) => row.currentGroupName.isNull())
                .getSingle())
            .label,
        'Updated profile',
      );

      expect(
        await database.managers.iconRecords
            .filter((row) => row.lastAccessed.equals(1))
            .getSingle(),
        isA<IconRecord>(),
      );
    },
  );

  test('clash providers DAO skips proxy rows, orders, and replaces', () async {
    const rules = ClashProvider(
      id: 51,
      label: 'Rules',
      url: 'https://rules.example',
      behavior: RuleProviderBehavior.domain,
      format: RuleProviderFormat.mrs,
    );
    const earlier = ClashProvider(
      id: 52,
      label: 'Earlier',
      url: 'https://earlier.example',
      order: 0,
    );
    const local = ClashProvider(id: 53, label: 'Local', order: 2);

    await database.clashProvidersDao.putAll([
      ...[rules, earlier, local].map((item) => item.toCompanion()),
      ClashProvidersCompanion.insert(
        id: const Value(50),
        kind: ProviderKind.proxy,
        label: 'Proxies',
        url: 'https://proxies.example',
      ),
    ]);

    expect(await database.clashProvidersDao.query().get(), [
      earlier,
      local,
      rules,
    ]);
    expect(
      await database.clashProvidersDao.fileNames().get(),
      unorderedEquals([rules, earlier, local].map((item) => item.fileName)),
    );

    await database.restore(
      const [],
      clashProviders: const [rules],
      isOverride: true,
    );
    expect(await database.clashProvidersDao.query().get(), [rules]);
  });

  test('database restore replaces profiles and providers', () async {
    const profile = Profile(
      id: 1,
      type: ProfileType.custom,
      autoUpdateDuration: Duration.zero,
    );
    const provider = ClashProvider(id: 9, label: 'Set');

    await database.restore(
      const [Profile(id: 7, label: 'Stale', autoUpdateDuration: Duration.zero)],
      clashProviders: const [ClashProvider(id: 8, label: 'Stale set')],
    );
    await database.restore(
      [profile],
      clashProviders: [provider],
      isOverride: true,
    );

    expect(await database.profilesDao.query().get(), [
      profile.copyWith(order: 0),
    ]);
    expect(await database.clashProvidersDao.query().get(), [provider]);
  });

  test(
    'a compatible restore keeps records the backup does not carry',
    () async {
      const keptProfile = Profile(id: 1, autoUpdateDuration: Duration.zero);
      const keptProvider = ClashProvider(id: 41, label: 'Kept');
      await database.restore(
        [keptProfile],
        clashProviders: [keptProvider],
        isOverride: true,
      );

      const backupProfile = Profile(id: 2, autoUpdateDuration: Duration.zero);
      const backupProvider = ClashProvider(id: 42, label: 'Backup');
      await database.restore([backupProfile], clashProviders: [backupProvider]);

      expect(
        (await database.profilesDao.query().get()).map((item) => item.id),
        unorderedEquals([1, 2]),
      );
      expect(
        (await database.clashProvidersDao.query().get()).map((item) => item.id),
        unorderedEquals([41, 42]),
      );
    },
  );

  test('icon records evict down to their capacity', () async {
    final dao = database.iconRecordsDao;
    for (var index = 0; index <= dao.maxCapacity; index++) {
      await dao.put('https://example.com/$index.png');
    }

    expect(await database.iconRecords.count.getSingle(), dao.maxCapacity);
  });

  test(
    'icon records update access time, avoid duplicates, and filter queries',
    () async {
      await database.iconRecordsDao.put('https://example.com/a.png');
      await database.iconRecordsDao.put('https://example.com/a.png');
      await database.iconRecordsDao.put('https://other.com/b.png');

      final before = await database.iconRecordsDao.query('example.com');
      expect(before.map((record) => record.url), ['https://example.com/a.png']);
      final record = await database.iconRecordsDao.get(
        'https://example.com/a.png',
      );
      expect(record?.url, 'https://example.com/a.png');
      expect(await database.iconRecordsDao.get('missing'), null);
      expect(await database.iconRecords.count.getSingle(), 2);

      await database.iconRecordsDao.del('https://example.com/a.png');

      expect(
        (await database.iconRecordsDao.query('')).map((record) => record.url),
        ['https://other.com/b.png'],
      );
    },
  );

  test('icon sets round-trip their icons and keep their order', () async {
    const icons = [
      IconSetIcon(name: 'Hong_Kong.png', url: 'https://example.com/hk.png'),
      IconSetIcon(name: 'Japan.svg', url: 'https://example.com/jp.svg'),
    ];
    await database.iconSetsDao.putAll([
      const IconSet(
        id: 2,
        name: 'Second',
        icons: icons,
        order: 0,
      ).toCompanion(),
      const IconSet(
        id: 1,
        name: 'First',
        url: 'https://example.com/set.json',
      ).toCompanion(),
      const IconSet(id: 3, name: 'Unordered').toCompanion(1),
    ]);

    final iconSets = await database.iconSetsDao.query().get();

    expect(iconSets.map((iconSet) => iconSet.id), [2, 3, 1]);
    expect(iconSets.first.icons, icons);
    expect(iconSets.last.url, 'https://example.com/set.json');
  });
}
