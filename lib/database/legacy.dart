part of 'database.dart';

/// The per-profile tables schema 21 kept custom profiles in. Schema 22
/// declares none of them, but an older database — and every backup
/// snapshot — still physically carries them until the startup conversion
/// retires the shape, so these readers speak raw SQL.
const _legacyProfileTables = [
  'rules',
  'disabled_rules',
  'proxy_groups',
  'custom_proxies',
  'proxy_dialers',
];

const _legacyProfileColumns = [
  'extend_type',
  'script_id',
  'match_target',
  'overrides',
];

extension LegacyProfileData on Database {
  Future<Set<String>> _existingTables() async {
    final rows = await customSelect(
      "SELECT name FROM sqlite_master WHERE type = 'table'",
    ).get();
    return {for (final row in rows) row.read<String>('name')};
  }

  /// Whether any retired table or dropped profiles column is present.
  Future<bool> get hasLegacyProfileData async {
    final tables = await _existingTables();
    if (_legacyProfileTables.any(tables.contains)) {
      return true;
    }
    final columns = await _columnsOf('profiles');
    return _legacyProfileColumns.any(columns.contains);
  }

  /// Every profile alongside the data the retired tables still hold for
  /// it, in the shape the restore converter eats; absent pieces read empty.
  Future<MigrationData> readLegacyProfileData() async {
    final profiles = await profilesDao.query().get();
    final tables = await _existingTables();
    final profileColumns = await _columnsOf('profiles');
    return MigrationData(
      profiles: profiles,
      rules: tables.contains('rules') ? await _readLegacyRules() : const [],
      disabledRules: tables.contains('disabled_rules')
          ? await _readLegacyDisabledRules()
          : const [],
      proxyGroups: tables.contains('proxy_groups')
          ? await _readLegacyProxyGroups()
          : const [],
      customProxies: tables.contains('custom_proxies')
          ? await _readLegacyCustomProxies()
          : const [],
      proxyDialers: tables.contains('proxy_dialers')
          ? await _readLegacyProxyDialers()
          : const [],
      profileOverrides: profileColumns.contains('overrides')
          ? await _readLegacyProfileOverrides()
          : const {},
    );
  }

  Future<List<Rule>> _readLegacyRules() async {
    final actions = RuleAction.values.asNameMap();
    final rows = await customSelect(
      'SELECT id, profile_id, rule_action, content, rule_target, '
      'rule_provider, sub_rule, no_resolve, src, "order" FROM rules '
      'ORDER BY "order" IS NULL, "order"',
    ).get();
    return [
      for (final row in rows)
        Rule(
          id: row.read<int>('id'),
          profileId: row.readNullable<int>('profile_id'),
          ruleAction: actions[row.read<String>('rule_action')]!,
          content: row.readNullable<String>('content'),
          ruleTarget: row.readNullable<String>('rule_target'),
          ruleProvider: row.readNullable<String>('rule_provider'),
          subRule: row.readNullable<String>('sub_rule'),
          noResolve: row.read<int>('no_resolve') != 0,
          src: row.read<int>('src') != 0,
          order: row.readNullable<String>('order'),
        ),
    ];
  }

  Future<List<DisabledRule>> _readLegacyDisabledRules() async {
    final rows = await customSelect(
      'SELECT profile_id, rule_id FROM disabled_rules',
    ).get();
    return [
      for (final row in rows)
        DisabledRule(
          profileId: row.read<int>('profile_id'),
          ruleId: row.read<int>('rule_id'),
        ),
    ];
  }

  Future<List<ProxyGroup>> _readLegacyProxyGroups() async {
    final rows = await customSelect(
      'SELECT id, profile_id, name, type, proxies, use, definition, "order" '
      'FROM proxy_groups ORDER BY "order" IS NULL, "order"',
    ).get();
    List<String>? stringList(String? stored) {
      if (stored == null) return null;
      return decodeOrRestoreDefault(
        'string list',
        () => List<String>.from(json.decode(stored)),
        () => <String>[],
      );
    }

    return [
      for (final row in rows)
        decodeSalvaging(
          'proxy group options',
          decodeOrRestoreDefault(
            'proxy group options',
            () => Map<String, Object?>.from(
              json.decode(row.read<String>('definition')),
            ),
            () => const <String, Object?>{},
          ),
          (options) => ProxyGroup.fromJson({
            ...options,
            'profileId': row.read<int>('profile_id'),
            'id': row.read<int>('id'),
            'name': row.read<String>('name'),
            'type': row.read<String>('type'),
            'proxies': stringList(row.readNullable<String>('proxies')),
            'use': stringList(row.readNullable<String>('use')),
            'order': row.readNullable<String>('order'),
          }),
        ),
    ];
  }

  Future<List<CustomProxy>> _readLegacyCustomProxies() async {
    final columns = await _columnsOf('custom_proxies');
    final fields = ProxyField.values.asNameMap();
    final rows = await customSelect(
      'SELECT id, definition, "order"'
      '${columns.contains('empty_options') ? ', empty_options' : ''} '
      'FROM custom_proxies ORDER BY "order" IS NULL, "order"',
    ).get();
    return [
      for (final row in rows)
        CustomProxy(
          id: row.read<int>('id'),
          definition: Map<String, dynamic>.from(
            json.decode(row.read<String>('definition')),
          ),
          order: row.readNullable<String>('order'),
          emptyOptions: {
            for (final name in decodeOrRestoreDefault(
              'string set',
              () => Set<String>.from(
                json.decode(
                  columns.contains('empty_options')
                      ? row.readNullable<String>('empty_options') ?? '[]'
                      : '[]',
                ),
              ),
              () => <String>{},
            ))
              ?fields[name],
          },
        ),
    ];
  }

  Future<List<ProxyDialer>> _readLegacyProxyDialers() async {
    final rows = await customSelect(
      'SELECT profile_id, proxy_id, target FROM proxy_dialers',
    ).get();
    return [
      for (final row in rows)
        ProxyDialer(
          profileId: row.read<int>('profile_id'),
          proxyId: row.read<int>('proxy_id'),
          target: row.read<String>('target'),
        ),
    ];
  }

  Future<Map<int, ProfileOverrides>> _readLegacyProfileOverrides() async {
    final rows = await customSelect(
      'SELECT id, overrides FROM profiles WHERE overrides IS NOT NULL',
    ).get();
    return {
      for (final row in rows)
        if (decodeOrRestoreDefault(
              'profile overrides',
              () => ProfileOverrides.safeFromJson(
                json.decode(row.read<String>('overrides')),
              ),
              () => null,
            )
            case final ProfileOverrides overrides)
          row.read<int>('id'): overrides,
    };
  }

  /// Removes the retired rows of profiles whose data has been baked into
  /// file snapshots, so a later pass only sees what is still unconverted.
  Future<void> deleteLegacyProfileRows(Set<int> profileIds) async {
    if (profileIds.isEmpty) {
      return;
    }
    final tables = await _existingTables();
    await transaction(() async {
      for (final table in [
        'proxy_dialers',
        'disabled_rules',
        'rules',
        'proxy_groups',
      ]) {
        if (!tables.contains(table)) {
          continue;
        }
        for (final chunk in profileIds.chunks(_maxBoundValues)) {
          final placeholders = List.filled(chunk.length, '?').join(', ');
          await customStatement(
            'DELETE FROM $table WHERE profile_id IN ($placeholders)',
            chunk,
          );
        }
      }
    });
  }

  /// Drops the retired tables and the dropped profiles columns once no
  /// unconverted custom profile remains to need them. Guarded per object,
  /// so a database that already shed part of the shape still finishes.
  Future<void> dropLegacyProfileData() async {
    await transaction(() async {
      // Referencing tables go before the tables they reference.
      for (final table in [
        'proxy_dialers',
        'disabled_rules',
        'rules',
        'proxy_groups',
        'custom_proxies',
      ]) {
        await customStatement('DROP TABLE IF EXISTS $table');
      }
      final columns = await _columnsOf('profiles');
      for (final column in _legacyProfileColumns) {
        if (columns.contains(column)) {
          await customStatement('ALTER TABLE profiles DROP COLUMN $column');
        }
      }
    });
  }
}
