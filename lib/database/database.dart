import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:collection/collection.dart';
import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:kfusion/common/common.dart';
import 'package:kfusion/enum/enum.dart';
import 'package:kfusion/models/models.dart';
import 'package:flutter/foundation.dart' show visibleForTesting;

part 'clash_providers.dart';
part 'converter.dart';
part 'generated/database.g.dart';
part 'icons.dart';
part 'legacy.dart';
part 'profiles.dart';

@DriftDatabase(
  tables: [Profiles, IconRecords, IconSets, ClashProviders],
  daos: [ProfilesDao, IconRecordsDao, IconSetsDao, ClashProvidersDao],
)
class Database extends _$Database {
  Database([QueryExecutor? executor]) : super(executor ?? _openConnection());

  @override
  int get schemaVersion => 22;

  static LazyDatabase _openConnection() {
    return LazyDatabase(() async {
      final databaseFile = File(await appPath.databasePath);
      return NativeDatabase.createInBackground(databaseFile);
    });
  }

  @override
  MigrationStrategy get migration {
    return MigrationStrategy(
      onUpgrade: (m, from, to) => transaction(() async {
        if (from < 2) {
          await m.createTable(iconRecords);
          await _migrateV1Rules();
        }
        if (from < 3) {
          await _addRawColumnIfMissing('profiles', 'match_target', 'TEXT NULL');
        }
        if (from < 6) {
          await _createTableIfMissing(m, clashProviders);
        }
        if (from < 8) {
          await m.alterTable(TableMigration(clashProviders));
        }
        if (from < 10) {
          await _createRawTableIfMissing('custom_proxies', _customProxiesDdl);
        }
        if (from < 17) {
          await _renameRawColumnIfPresent(
            'profiles',
            'overwrite_type',
            'extend_type',
          );
          await _dropProfileCustomProxies();
          await _migrateToCustomProfiles();
          await _createTableIfMissing(m, iconSets);
          await _addColumnIfMissing(m, iconSets, iconSets.lastUpdateTime);
          await _addRawColumnIfMissing('profiles', 'overrides', 'TEXT NULL');
        }
        if (from < 18) {
          await _moveGroupOptionsToDefinition();
        }
        if (from < 19) {
          await _addColumnIfMissing(m, profiles, profiles.ageSecretKey);
        }
        if (from < 20) {
          await _addRawColumnIfMissing(
            'custom_proxies',
            'empty_options',
            'TEXT NULL',
          );
        }
        // Schema 21 drops the scripts table from the schema only; the
        // physical table stays in place, unread, so stored rows survive.
        // Schema 22 retires the per-profile tables and the profiles
        // override columns from the schema the same way: the physical
        // shape stays until the startup conversion has materialized any
        // custom profiles out of it (see legacy.dart), because a backup
        // snapshot opened for restore must still find its rows.
      }),
      beforeOpen: (_) => customStatement('PRAGMA foreign_keys = ON'),
    );
  }

  Future<Set<String>> _columnsOf(String table) async {
    final tableInfo = await customSelect('PRAGMA table_info($table)').get();
    return {for (final row in tableInfo) row.read<String>('name')};
  }

  /// Drift rewinds user_version on downgrade but keeps the tables it added.
  Future<bool> _createTableIfMissing(Migrator m, TableInfo table) async {
    if ((await _columnsOf(table.actualTableName)).isNotEmpty) {
      return false;
    }
    await m.createTable(table);
    return true;
  }

  /// Drift rewinds user_version on downgrade but keeps the columns it added.
  Future<void> _addColumnIfMissing(
    Migrator m,
    TableInfo table,
    GeneratedColumn column,
  ) async {
    if ((await _columnsOf(table.actualTableName)).contains(column.name)) {
      return;
    }
    await m.addColumn(table, column);
  }

  /// The tables retired at schema 22 have no table info to migrate with,
  /// so their steps speak raw SQL throughout.
  Future<void> _addRawColumnIfMissing(
    String table,
    String column,
    String definition,
  ) async {
    if ((await _columnsOf(table)).contains(column)) {
      return;
    }
    await customStatement('ALTER TABLE $table ADD COLUMN $column $definition');
  }

  Future<bool> _createRawTableIfMissing(String table, String ddl) async {
    if ((await _columnsOf(table)).isNotEmpty) {
      return false;
    }
    await customStatement(ddl);
    return true;
  }

  Future<void> _renameRawColumnIfPresent(
    String table,
    String oldName,
    String newName,
  ) async {
    final columns = await _columnsOf(table);
    if (!columns.contains(oldName) || columns.contains(newName)) {
      return;
    }
    await customStatement(
      'ALTER TABLE $table RENAME COLUMN $oldName TO $newName',
    );
  }

  /// Rebuilding the table is what sheds the dropped column; the old index
  /// names it, so it goes first.
  Future<void> _dropProfileCustomProxies() async {
    final columns = await _columnsOf('custom_proxies');
    if (!columns.contains('profile_id')) {
      return;
    }
    await customStatement(
      'DELETE FROM custom_proxies WHERE profile_id IS NOT NULL',
    );
    await customStatement(
      'DROP INDEX IF EXISTS idx_custom_proxies_profile_order',
    );
    await customStatement(
      'CREATE TABLE custom_proxies_new ('
      '"id" INTEGER NOT NULL, "definition" TEXT NOT NULL, '
      '"order" TEXT NULL, "empty_options" TEXT NULL, PRIMARY KEY ("id"))',
    );
    await customStatement(
      'INSERT INTO custom_proxies_new (id, definition, "order", empty_options) '
      'SELECT id, definition, "order", '
      '${columns.contains('empty_options') ? 'empty_options' : 'NULL'} '
      'FROM custom_proxies',
    );
    await customStatement('DROP TABLE custom_proxies');
    await customStatement(
      'ALTER TABLE custom_proxies_new RENAME TO custom_proxies',
    );
  }

  /// Schema 17 kept each group option in a column of its own.
  Future<void> _moveGroupOptionsToDefinition() async {
    final columns = await _columnsOf('proxy_groups');
    if (columns.isEmpty || columns.contains('definition')) {
      return;
    }
    final rows = await customSelect('SELECT * FROM proxy_groups').get();
    await customStatement(_proxyGroupsRebuiltDdl);
    await customStatement(
      'INSERT INTO proxy_groups_new '
      '(id, profile_id, name, type, proxies, use, definition, "order") '
      "SELECT id, profile_id, name, type, proxies, use, '{}', \"order\" "
      'FROM proxy_groups',
    );
    await customStatement('DROP TABLE proxy_groups');
    await customStatement(
      'ALTER TABLE proxy_groups_new RENAME TO proxy_groups',
    );
    await customStatement(
      'CREATE INDEX idx_proxy_groups_profile_order '
      'ON proxy_groups (profile_id, "order")',
    );
    for (final row in rows) {
      final options = {
        for (final (column, key) in _v17GroupOptions)
          if (row.data[column] case final Object value) key: value,
        for (final (column, key) in _v17GroupFlags)
          if (row.data[column] case final int value) key: value != 0,
      };
      if (options.isEmpty) {
        continue;
      }
      await customStatement(
        'UPDATE proxy_groups SET definition = ? WHERE id = ?',
        [json.encode(options), row.read<int>('id')],
      );
    }
  }

  /// Schema 1 kept each rule as one `value` string and its links in reverse
  /// order; [_migrateToCustomProfiles] then moves both onto the rules.
  Future<void> _migrateV1Rules() async {
    final columns = await _columnsOf('rules');
    if (columns.contains('value')) {
      await customStatement(
        'ALTER TABLE rules ADD COLUMN rule_action TEXT NOT NULL DEFAULT ""',
      );
      await customStatement('ALTER TABLE rules ADD COLUMN content TEXT');
      await customStatement('ALTER TABLE rules ADD COLUMN rule_target TEXT');
      await customStatement('ALTER TABLE rules ADD COLUMN rule_provider TEXT');
      await customStatement('ALTER TABLE rules ADD COLUMN sub_rule TEXT');
      await customStatement(
        'ALTER TABLE rules ADD COLUMN no_resolve INTEGER NOT NULL DEFAULT 0',
      );
      await customStatement(
        'ALTER TABLE rules ADD COLUMN src INTEGER NOT NULL DEFAULT 0',
      );
      final oldRows = await customSelect('SELECT id, value FROM rules').get();
      for (final row in oldRows) {
        final id = row.read<int>('id');
        final parsed = Rule.parse(row.read<String>('value'), id: id);
        await customStatement(
          'UPDATE rules SET rule_action = ?, content = ?, rule_target = ?, rule_provider = ?, sub_rule = ?, no_resolve = ?, src = ? WHERE id = ?',
          [
            parsed.ruleAction.name,
            parsed.content,
            parsed.ruleTarget,
            parsed.ruleProvider,
            parsed.subRule,
            parsed.noResolve ? 1 : 0,
            parsed.src ? 1 : 0,
            id,
          ],
        );
      }
      await customStatement('ALTER TABLE rules DROP COLUMN value');
    }
    final links = await customSelect(
      'SELECT id FROM profile_rule_mapping '
      'ORDER BY scene ASC, "order" DESC, id DESC',
    ).get();
    final keys = indexing.generateNKeys(links.length);
    for (final (index, link) in links.indexed) {
      await customStatement(
        'UPDATE profile_rule_mapping SET "order" = ? WHERE id = ?',
        [keys[index], link.read<String>('id')],
      );
    }
  }

  /// Rules move from `profile_rule_mapping` onto their owner, and everything a
  /// custom overwrite kept — its groups, its rules and its dialers — is
  /// dropped: those groups named the subscription's own proxies, which a
  /// custom profile does not have. The mapping table marks the old shape, so
  /// a database that went back to an older build and returns is left as is.
  Future<void> _migrateToCustomProfiles() async {
    final profileColumns = await _columnsOf('profiles');
    if (!profileColumns.contains('type')) {
      for (final MapEntry(key: name, value: ddl) in _profileColumnDdl.entries) {
        if (!profileColumns.contains(name)) {
          await customStatement('ALTER TABLE profiles ADD COLUMN "$name" $ddl');
        }
      }
      await customStatement(
        'UPDATE profiles SET type = '
        "CASE WHEN url = '' THEN 'file' ELSE 'url' END",
      );
    }
    final customOverwrites = {
      for (final row in await customSelect(
        'SELECT id FROM profiles '
        "WHERE extend_type NOT IN ('standard', 'script')",
      ).get())
        row.read<int>('id'),
    };
    await customStatement(
      "UPDATE profiles SET extend_type = 'standard', match_target = NULL "
      "WHERE extend_type NOT IN ('standard', 'script')",
    );
    if ((await _columnsOf('profile_rule_mapping')).isEmpty) {
      return;
    }
    final profileIds = {
      for (final row in await customSelect('SELECT id FROM profiles').get())
        row.read<int>('id'),
    };
    final ruleRows = (await _columnsOf('rules')).isEmpty
        ? const <QueryRow>[]
        : await customSelect(
            'SELECT id, rule_action, content, rule_target, rule_provider, '
            'sub_rule, no_resolve, src FROM rules',
          ).get();
    final linkRows = await customSelect(
      'SELECT profile_id, rule_id, scene, "order" FROM profile_rule_mapping '
      'ORDER BY profile_id IS NOT NULL, "order"',
    ).get();
    final owners = <int, (int?, String?)>{};
    final disabled = <(int, int)>{};
    for (final link in linkRows) {
      final profileId = link.readNullable<int>('profile_id');
      final ruleId = link.read<int>('rule_id');
      final scene = link.readNullable<String>('scene');
      if (profileId != null && !profileIds.contains(profileId)) {
        continue;
      }
      switch ((profileId, scene)) {
        case (null, null):
        case (int(), 'added') when !customOverwrites.contains(profileId):
          owners.putIfAbsent(
            ruleId,
            () => (profileId, link.readNullable<String>('order')),
          );
        case (final int owner, 'disabled'):
          disabled.add((owner, ruleId));
      }
    }
    for (final MapEntry(key: ruleId, value: (owner, _)) in owners.entries) {
      if (owner != null) {
        continue;
      }
      for (final profileId in customOverwrites) {
        disabled.add((profileId, ruleId));
      }
    }
    for (final table in [
      'profile_rule_mapping',
      'rules',
      'proxy_dialers',
      'proxy_groups',
    ]) {
      await customStatement('DROP TABLE IF EXISTS $table');
    }
    for (final ddl in [
      _rulesDdl,
      _disabledRulesDdl,
      _proxyGroupsDdl,
      _proxyDialersDdl,
      'CREATE INDEX idx_rule_target ON rules (rule_target)',
      'CREATE INDEX idx_rules_profile_order ON rules (profile_id, "order")',
      'CREATE INDEX idx_proxy_groups_profile_order ON proxy_groups (profile_id, "order")',
    ]) {
      await customStatement(ddl);
    }
    final keptRuleIds = <int>{};
    for (final row in ruleRows) {
      final id = row.read<int>('id');
      final owner = owners[id];
      if (owner == null) {
        continue;
      }
      keptRuleIds.add(id);
      await customStatement(
        'INSERT INTO rules (id, profile_id, rule_action, content, rule_target, '
        'rule_provider, sub_rule, no_resolve, src, "order") '
        'VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?)',
        [
          id,
          owner.$1,
          row.read<String>('rule_action'),
          row.readNullable<String>('content'),
          row.readNullable<String>('rule_target'),
          row.readNullable<String>('rule_provider'),
          row.readNullable<String>('sub_rule'),
          row.read<int>('no_resolve'),
          row.read<int>('src'),
          owner.$2,
        ],
      );
    }
    for (final (profileId, ruleId) in disabled) {
      if (!keptRuleIds.contains(ruleId)) {
        continue;
      }
      await customStatement(
        'INSERT INTO disabled_rules (profile_id, rule_id) VALUES (?, ?)',
        [profileId, ruleId],
      );
    }
  }

  /// The per-profile rows a backup may still carry in its [MigrationData]
  /// are not written: the restore converter materializes them into file
  /// profiles beforehand, and what it could not convert stays in the
  /// backup, not in tables this schema no longer has.
  Future<void> restore(
    List<Profile> profiles, {
    List<ClashProvider> clashProviders = const [],
    bool isOverride = false,
  }) async {
    if (profiles.isEmpty && clashProviders.isEmpty) {
      return;
    }
    await transaction(() async {
      // Backups taken while foreign keys were off may carry orphaned rows.
      await customStatement('PRAGMA defer_foreign_keys = ON');
      await batch((b) {
        if (isOverride) {
          profilesDao.setAllWithBatch(b, profiles);
          clashProvidersDao.setAllWithBatch(b, clashProviders);
          return;
        }
        profilesDao.putAllWithBatch(
          b,
          profiles.map((item) => item.toCompanion()),
        );
        clashProvidersDao.putAllWithBatch(b, clashProviders);
      });
    });
  }

  Future<void> deleteProfile(int profileId) {
    return profiles.remove((t) => t.id.equals(profileId));
  }
}

/// The schema-21 shapes of the retired per-profile tables, kept as raw
/// SQL because the migration chain still has to build them on its way
/// through the old versions (and the test harness rebuilds them to walk
/// a database back).
const _rulesDdl =
    'CREATE TABLE "rules" ("id" INTEGER NOT NULL, '
    '"profile_id" INTEGER NULL REFERENCES profiles (id) ON DELETE CASCADE, '
    '"rule_action" TEXT NOT NULL, "content" TEXT NULL, '
    '"rule_target" TEXT NULL, "rule_provider" TEXT NULL, '
    '"sub_rule" TEXT NULL, '
    '"no_resolve" INTEGER NOT NULL DEFAULT 0 CHECK ("no_resolve" IN (0, 1)), '
    '"src" INTEGER NOT NULL DEFAULT 0 CHECK ("src" IN (0, 1)), '
    '"order" TEXT NULL, PRIMARY KEY ("id"))';

const _disabledRulesDdl =
    'CREATE TABLE "disabled_rules" ('
    '"profile_id" INTEGER NOT NULL REFERENCES profiles (id) '
    'ON DELETE CASCADE, '
    '"rule_id" INTEGER NOT NULL REFERENCES rules (id) ON DELETE CASCADE, '
    'PRIMARY KEY ("profile_id", "rule_id"))';

const _proxyGroupsDdl =
    'CREATE TABLE "proxy_groups" ("id" INTEGER NOT NULL, '
    '"profile_id" INTEGER NOT NULL REFERENCES profiles (id) '
    'ON DELETE CASCADE, '
    '"name" TEXT NOT NULL, "type" TEXT NOT NULL, "proxies" TEXT NULL, '
    '"use" TEXT NULL, "definition" TEXT NOT NULL DEFAULT \'{}\', '
    '"order" TEXT NULL, PRIMARY KEY ("id"))';

const _proxyGroupsRebuiltDdl =
    'CREATE TABLE "proxy_groups_new" ("id" INTEGER NOT NULL, '
    '"profile_id" INTEGER NOT NULL REFERENCES profiles (id) '
    'ON DELETE CASCADE, '
    '"name" TEXT NOT NULL, "type" TEXT NOT NULL, "proxies" TEXT NULL, '
    '"use" TEXT NULL, "definition" TEXT NOT NULL DEFAULT \'{}\', '
    '"order" TEXT NULL, PRIMARY KEY ("id"))';

const _customProxiesDdl =
    'CREATE TABLE "custom_proxies" ("id" INTEGER NOT NULL, '
    '"definition" TEXT NOT NULL, "order" TEXT NULL, '
    '"empty_options" TEXT NULL, PRIMARY KEY ("id"))';

const _proxyDialersDdl =
    'CREATE TABLE "proxy_dialers" ('
    '"profile_id" INTEGER NOT NULL REFERENCES profiles (id) '
    'ON DELETE CASCADE, '
    '"proxy_id" INTEGER NOT NULL REFERENCES custom_proxies (id) '
    'ON DELETE CASCADE, '
    '"target" TEXT NOT NULL, PRIMARY KEY ("profile_id", "proxy_id"))';

/// Ballast for adding a declared profiles column to a pre-v17 table that
/// lacks it: the stored value wins wherever the column already exists,
/// these defaults only fill a column the file never had.
const _profileColumnDdl = {
  'type': "TEXT NOT NULL DEFAULT 'file'",
  'label': "TEXT NOT NULL DEFAULT ''",
  'current_group_name': 'TEXT NULL',
  'url': "TEXT NOT NULL DEFAULT ''",
  'age_secret_key': 'TEXT NULL',
  'last_update_date': 'INTEGER NULL',
  'auto_update_duration_millis': 'INTEGER NOT NULL DEFAULT 0',
  'subscription_info': 'TEXT NULL',
  'auto_update': 'INTEGER NOT NULL DEFAULT 0',
  'selected_map': "TEXT NOT NULL DEFAULT '{}'",
  'unfold_set': "TEXT NOT NULL DEFAULT '[]'",
  'order': 'INTEGER NULL',
};

const _v17GroupOptions = [
  ('url', 'url'),
  ('interval', 'interval'),
  ('timeout', 'timeout'),
  ('max_failed_times', 'max-failed-times'),
  ('filter', 'filter'),
  ('exclude_filter', 'exclude-filter'),
  ('exclude_type', 'exclude-type'),
  ('expected_status', 'expected-status'),
  ('tolerance', 'tolerance'),
  ('strategy', 'strategy'),
  ('hash_key', 'hash-key'),
  ('default_selected', 'default-selected'),
  ('empty_fallback', 'empty-fallback'),
  ('icon', 'icon'),
];

const _v17GroupFlags = [
  ('lazy', 'lazy'),
  ('disable_u_d_p', 'disable-udp'),
  ('include_all', 'include-all'),
  ('include_all_proxies', 'include-all-proxies'),
  ('include_all_providers', 'include-all-providers'),
  ('hidden', 'hidden'),
];

// SQLite builds before 3.32 cap a statement at 999 bound parameters.
const _maxBoundValues = 900;

extension TableInfoExt<Tbl extends Table, Row> on TableInfo<Tbl, Row> {
  void setAll(
    Batch batch,
    Iterable<Insertable<Row>> items, {
    required Expression<bool> Function(Tbl tbl) deleteFilter,
    bool preDelete = false,
  }) async {
    if (preDelete) {
      batch.deleteWhere(this, deleteFilter);
    }
    batch.insertAllOnConflictUpdate(this, items);
    if (!preDelete) {
      batch.deleteWhere(this, deleteFilter);
    }
  }

  void deleteInChunks<V extends Object>(
    Batch batch,
    Iterable<V> values,
    Expression<bool> Function(Tbl tbl, List<V> chunk) filter,
  ) {
    for (final chunk in values.chunks(_maxBoundValues)) {
      batch.deleteWhere(this, (tbl) => filter(tbl, chunk));
    }
  }

  Selectable<int?> get count {
    final countExp = countAll();
    final query = select().addColumns([countExp]);
    return query.map((row) => row.read(countExp));
  }

  /// [select] that skips a row this version cannot read instead of failing the
  /// whole query; the row itself stays in the table.
  Selectable<R> readable<R extends Object>(
    R Function(Row row) read, {
    Expression<bool> Function(Tbl tbl)? where,
    List<OrderingTerm Function(Tbl tbl)> orderBy = const [],
  }) {
    final query = selectOnly()..addColumns($columns);
    if (where != null) {
      query.where(where(asDslTable));
    }
    query.orderBy([for (final term in orderBy) term(asDslTable)]);
    return _NonNullSelectable(
      query.map((row) => _readRow(row.rawData.data, read)),
    );
  }

  R? _readRow<R extends Object>(
    Map<String, Object?> data,
    R Function(Row row) read,
  ) {
    try {
      return read(map(data, tablePrefix: aliasedName) as Row);
    } catch (error) {
      commonPrint.log(
        'Skipped unreadable $actualTableName row: ${compactError(error)}',
        logLevel: LogLevel.warning,
      );
      return null;
    }
  }

  Future<int> remove(Expression<bool> Function(Tbl tbl) filter) async {
    return (delete()..where(filter)).go();
  }

  Future<int> put(Insertable<Row> item) async {
    return insertOnConflictUpdate(item);
  }
}

class _NonNullSelectable<T extends Object> extends Selectable<T> {
  _NonNullSelectable(this._source);

  final Selectable<T?> _source;

  @override
  Future<List<T>> get() async => (await _source.get()).nonNulls.toList();

  @override
  Stream<List<T>> watch() =>
      _source.watch().map((rows) => rows.nonNulls.toList());
}

extension SimpleSelectStatementExt<T extends HasResultSet, D>
    on SimpleSelectStatement<T, D> {
  Selectable<int> get count {
    final countExp = countAll();
    final query = addColumns([countExp]);
    return query.map((row) => row.read(countExp)!);
  }
}

extension JoinedSelectStatementExt<T extends HasResultSet, D>
    on JoinedSelectStatement<T, D> {
  Selectable<int> get count {
    final countExp = countAll();
    addColumns([countExp]);
    return map((row) => row.read(countExp)!);
  }
}

Database _database = Database();

Database get database => _database;

@visibleForTesting
set database(Database value) => _database = value;
