// GENERATED CODE - DO NOT MODIFY BY HAND

part of '../database.dart';

// ignore_for_file: type=lint
class $ProfilesTable extends Profiles
    with TableInfo<$ProfilesTable, RawProfile> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $ProfilesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  @override
  late final GeneratedColumnWithTypeConverter<ProfileType, String> type =
      GeneratedColumn<String>(
        'type',
        aliasedName,
        false,
        type: DriftSqlType.string,
        requiredDuringInsert: true,
      ).withConverter<ProfileType>($ProfilesTable.$convertertype);
  static const VerificationMeta _labelMeta = const VerificationMeta('label');
  @override
  late final GeneratedColumn<String> label = GeneratedColumn<String>(
    'label',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _currentGroupNameMeta = const VerificationMeta(
    'currentGroupName',
  );
  @override
  late final GeneratedColumn<String> currentGroupName = GeneratedColumn<String>(
    'current_group_name',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _urlMeta = const VerificationMeta('url');
  @override
  late final GeneratedColumn<String> url = GeneratedColumn<String>(
    'url',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _ageSecretKeyMeta = const VerificationMeta(
    'ageSecretKey',
  );
  @override
  late final GeneratedColumn<String> ageSecretKey = GeneratedColumn<String>(
    'age_secret_key',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _lastUpdateDateMeta = const VerificationMeta(
    'lastUpdateDate',
  );
  @override
  late final GeneratedColumn<DateTime> lastUpdateDate =
      GeneratedColumn<DateTime>(
        'last_update_date',
        aliasedName,
        true,
        type: DriftSqlType.dateTime,
        requiredDuringInsert: false,
      );
  static const VerificationMeta _autoUpdateDurationMillisMeta =
      const VerificationMeta('autoUpdateDurationMillis');
  @override
  late final GeneratedColumn<int> autoUpdateDurationMillis =
      GeneratedColumn<int>(
        'auto_update_duration_millis',
        aliasedName,
        false,
        type: DriftSqlType.int,
        requiredDuringInsert: true,
      );
  @override
  late final GeneratedColumnWithTypeConverter<SubscriptionInfo?, String>
  subscriptionInfo = GeneratedColumn<String>(
    'subscription_info',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  ).withConverter<SubscriptionInfo?>($ProfilesTable.$convertersubscriptionInfo);
  static const VerificationMeta _autoUpdateMeta = const VerificationMeta(
    'autoUpdate',
  );
  @override
  late final GeneratedColumn<bool> autoUpdate = GeneratedColumn<bool>(
    'auto_update',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("auto_update" IN (0, 1))',
    ),
  );
  @override
  late final GeneratedColumnWithTypeConverter<Map<String, String>, String>
  selectedMap = GeneratedColumn<String>(
    'selected_map',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  ).withConverter<Map<String, String>>($ProfilesTable.$converterselectedMap);
  @override
  late final GeneratedColumnWithTypeConverter<Set<String>, String> unfoldSet =
      GeneratedColumn<String>(
        'unfold_set',
        aliasedName,
        false,
        type: DriftSqlType.string,
        requiredDuringInsert: true,
      ).withConverter<Set<String>>($ProfilesTable.$converterunfoldSet);
  static const VerificationMeta _orderMeta = const VerificationMeta('order');
  @override
  late final GeneratedColumn<int> order = GeneratedColumn<int>(
    'order',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    type,
    label,
    currentGroupName,
    url,
    ageSecretKey,
    lastUpdateDate,
    autoUpdateDurationMillis,
    subscriptionInfo,
    autoUpdate,
    selectedMap,
    unfoldSet,
    order,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'profiles';
  @override
  VerificationContext validateIntegrity(
    Insertable<RawProfile> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('label')) {
      context.handle(
        _labelMeta,
        label.isAcceptableOrUnknown(data['label']!, _labelMeta),
      );
    } else if (isInserting) {
      context.missing(_labelMeta);
    }
    if (data.containsKey('current_group_name')) {
      context.handle(
        _currentGroupNameMeta,
        currentGroupName.isAcceptableOrUnknown(
          data['current_group_name']!,
          _currentGroupNameMeta,
        ),
      );
    }
    if (data.containsKey('url')) {
      context.handle(
        _urlMeta,
        url.isAcceptableOrUnknown(data['url']!, _urlMeta),
      );
    } else if (isInserting) {
      context.missing(_urlMeta);
    }
    if (data.containsKey('age_secret_key')) {
      context.handle(
        _ageSecretKeyMeta,
        ageSecretKey.isAcceptableOrUnknown(
          data['age_secret_key']!,
          _ageSecretKeyMeta,
        ),
      );
    }
    if (data.containsKey('last_update_date')) {
      context.handle(
        _lastUpdateDateMeta,
        lastUpdateDate.isAcceptableOrUnknown(
          data['last_update_date']!,
          _lastUpdateDateMeta,
        ),
      );
    }
    if (data.containsKey('auto_update_duration_millis')) {
      context.handle(
        _autoUpdateDurationMillisMeta,
        autoUpdateDurationMillis.isAcceptableOrUnknown(
          data['auto_update_duration_millis']!,
          _autoUpdateDurationMillisMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_autoUpdateDurationMillisMeta);
    }
    if (data.containsKey('auto_update')) {
      context.handle(
        _autoUpdateMeta,
        autoUpdate.isAcceptableOrUnknown(data['auto_update']!, _autoUpdateMeta),
      );
    } else if (isInserting) {
      context.missing(_autoUpdateMeta);
    }
    if (data.containsKey('order')) {
      context.handle(
        _orderMeta,
        order.isAcceptableOrUnknown(data['order']!, _orderMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  RawProfile map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return RawProfile(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      type: $ProfilesTable.$convertertype.fromSql(
        attachedDatabase.typeMapping.read(
          DriftSqlType.string,
          data['${effectivePrefix}type'],
        )!,
      ),
      label: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}label'],
      )!,
      currentGroupName: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}current_group_name'],
      ),
      url: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}url'],
      )!,
      ageSecretKey: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}age_secret_key'],
      ),
      lastUpdateDate: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}last_update_date'],
      ),
      autoUpdateDurationMillis: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}auto_update_duration_millis'],
      )!,
      subscriptionInfo: $ProfilesTable.$convertersubscriptionInfo.fromSql(
        attachedDatabase.typeMapping.read(
          DriftSqlType.string,
          data['${effectivePrefix}subscription_info'],
        ),
      ),
      autoUpdate: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}auto_update'],
      )!,
      selectedMap: $ProfilesTable.$converterselectedMap.fromSql(
        attachedDatabase.typeMapping.read(
          DriftSqlType.string,
          data['${effectivePrefix}selected_map'],
        )!,
      ),
      unfoldSet: $ProfilesTable.$converterunfoldSet.fromSql(
        attachedDatabase.typeMapping.read(
          DriftSqlType.string,
          data['${effectivePrefix}unfold_set'],
        )!,
      ),
      order: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}order'],
      ),
    );
  }

  @override
  $ProfilesTable createAlias(String alias) {
    return $ProfilesTable(attachedDatabase, alias);
  }

  static JsonTypeConverter2<ProfileType, String, String> $convertertype =
      const EnumNameConverter<ProfileType>(ProfileType.values);
  static TypeConverter<SubscriptionInfo?, String?> $convertersubscriptionInfo =
      const SubscriptionInfoConverter();
  static TypeConverter<Map<String, String>, String> $converterselectedMap =
      const StringMapConverter();
  static TypeConverter<Set<String>, String> $converterunfoldSet =
      const StringSetConverter();
}

class RawProfile extends DataClass implements Insertable<RawProfile> {
  final int id;
  final ProfileType type;
  final String label;
  final String? currentGroupName;
  final String url;
  final String? ageSecretKey;
  final DateTime? lastUpdateDate;
  final int autoUpdateDurationMillis;
  final SubscriptionInfo? subscriptionInfo;
  final bool autoUpdate;
  final Map<String, String> selectedMap;
  final Set<String> unfoldSet;
  final int? order;
  const RawProfile({
    required this.id,
    required this.type,
    required this.label,
    this.currentGroupName,
    required this.url,
    this.ageSecretKey,
    this.lastUpdateDate,
    required this.autoUpdateDurationMillis,
    this.subscriptionInfo,
    required this.autoUpdate,
    required this.selectedMap,
    required this.unfoldSet,
    this.order,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    {
      map['type'] = Variable<String>($ProfilesTable.$convertertype.toSql(type));
    }
    map['label'] = Variable<String>(label);
    if (!nullToAbsent || currentGroupName != null) {
      map['current_group_name'] = Variable<String>(currentGroupName);
    }
    map['url'] = Variable<String>(url);
    if (!nullToAbsent || ageSecretKey != null) {
      map['age_secret_key'] = Variable<String>(ageSecretKey);
    }
    if (!nullToAbsent || lastUpdateDate != null) {
      map['last_update_date'] = Variable<DateTime>(lastUpdateDate);
    }
    map['auto_update_duration_millis'] = Variable<int>(
      autoUpdateDurationMillis,
    );
    if (!nullToAbsent || subscriptionInfo != null) {
      map['subscription_info'] = Variable<String>(
        $ProfilesTable.$convertersubscriptionInfo.toSql(subscriptionInfo),
      );
    }
    map['auto_update'] = Variable<bool>(autoUpdate);
    {
      map['selected_map'] = Variable<String>(
        $ProfilesTable.$converterselectedMap.toSql(selectedMap),
      );
    }
    {
      map['unfold_set'] = Variable<String>(
        $ProfilesTable.$converterunfoldSet.toSql(unfoldSet),
      );
    }
    if (!nullToAbsent || order != null) {
      map['order'] = Variable<int>(order);
    }
    return map;
  }

  ProfilesCompanion toCompanion(bool nullToAbsent) {
    return ProfilesCompanion(
      id: Value(id),
      type: Value(type),
      label: Value(label),
      currentGroupName: currentGroupName == null && nullToAbsent
          ? const Value.absent()
          : Value(currentGroupName),
      url: Value(url),
      ageSecretKey: ageSecretKey == null && nullToAbsent
          ? const Value.absent()
          : Value(ageSecretKey),
      lastUpdateDate: lastUpdateDate == null && nullToAbsent
          ? const Value.absent()
          : Value(lastUpdateDate),
      autoUpdateDurationMillis: Value(autoUpdateDurationMillis),
      subscriptionInfo: subscriptionInfo == null && nullToAbsent
          ? const Value.absent()
          : Value(subscriptionInfo),
      autoUpdate: Value(autoUpdate),
      selectedMap: Value(selectedMap),
      unfoldSet: Value(unfoldSet),
      order: order == null && nullToAbsent
          ? const Value.absent()
          : Value(order),
    );
  }

  factory RawProfile.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return RawProfile(
      id: serializer.fromJson<int>(json['id']),
      type: $ProfilesTable.$convertertype.fromJson(
        serializer.fromJson<String>(json['type']),
      ),
      label: serializer.fromJson<String>(json['label']),
      currentGroupName: serializer.fromJson<String?>(json['currentGroupName']),
      url: serializer.fromJson<String>(json['url']),
      ageSecretKey: serializer.fromJson<String?>(json['ageSecretKey']),
      lastUpdateDate: serializer.fromJson<DateTime?>(json['lastUpdateDate']),
      autoUpdateDurationMillis: serializer.fromJson<int>(
        json['autoUpdateDurationMillis'],
      ),
      subscriptionInfo: serializer.fromJson<SubscriptionInfo?>(
        json['subscriptionInfo'],
      ),
      autoUpdate: serializer.fromJson<bool>(json['autoUpdate']),
      selectedMap: serializer.fromJson<Map<String, String>>(
        json['selectedMap'],
      ),
      unfoldSet: serializer.fromJson<Set<String>>(json['unfoldSet']),
      order: serializer.fromJson<int?>(json['order']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'type': serializer.toJson<String>(
        $ProfilesTable.$convertertype.toJson(type),
      ),
      'label': serializer.toJson<String>(label),
      'currentGroupName': serializer.toJson<String?>(currentGroupName),
      'url': serializer.toJson<String>(url),
      'ageSecretKey': serializer.toJson<String?>(ageSecretKey),
      'lastUpdateDate': serializer.toJson<DateTime?>(lastUpdateDate),
      'autoUpdateDurationMillis': serializer.toJson<int>(
        autoUpdateDurationMillis,
      ),
      'subscriptionInfo': serializer.toJson<SubscriptionInfo?>(
        subscriptionInfo,
      ),
      'autoUpdate': serializer.toJson<bool>(autoUpdate),
      'selectedMap': serializer.toJson<Map<String, String>>(selectedMap),
      'unfoldSet': serializer.toJson<Set<String>>(unfoldSet),
      'order': serializer.toJson<int?>(order),
    };
  }

  RawProfile copyWith({
    int? id,
    ProfileType? type,
    String? label,
    Value<String?> currentGroupName = const Value.absent(),
    String? url,
    Value<String?> ageSecretKey = const Value.absent(),
    Value<DateTime?> lastUpdateDate = const Value.absent(),
    int? autoUpdateDurationMillis,
    Value<SubscriptionInfo?> subscriptionInfo = const Value.absent(),
    bool? autoUpdate,
    Map<String, String>? selectedMap,
    Set<String>? unfoldSet,
    Value<int?> order = const Value.absent(),
  }) => RawProfile(
    id: id ?? this.id,
    type: type ?? this.type,
    label: label ?? this.label,
    currentGroupName: currentGroupName.present
        ? currentGroupName.value
        : this.currentGroupName,
    url: url ?? this.url,
    ageSecretKey: ageSecretKey.present ? ageSecretKey.value : this.ageSecretKey,
    lastUpdateDate: lastUpdateDate.present
        ? lastUpdateDate.value
        : this.lastUpdateDate,
    autoUpdateDurationMillis:
        autoUpdateDurationMillis ?? this.autoUpdateDurationMillis,
    subscriptionInfo: subscriptionInfo.present
        ? subscriptionInfo.value
        : this.subscriptionInfo,
    autoUpdate: autoUpdate ?? this.autoUpdate,
    selectedMap: selectedMap ?? this.selectedMap,
    unfoldSet: unfoldSet ?? this.unfoldSet,
    order: order.present ? order.value : this.order,
  );
  RawProfile copyWithCompanion(ProfilesCompanion data) {
    return RawProfile(
      id: data.id.present ? data.id.value : this.id,
      type: data.type.present ? data.type.value : this.type,
      label: data.label.present ? data.label.value : this.label,
      currentGroupName: data.currentGroupName.present
          ? data.currentGroupName.value
          : this.currentGroupName,
      url: data.url.present ? data.url.value : this.url,
      ageSecretKey: data.ageSecretKey.present
          ? data.ageSecretKey.value
          : this.ageSecretKey,
      lastUpdateDate: data.lastUpdateDate.present
          ? data.lastUpdateDate.value
          : this.lastUpdateDate,
      autoUpdateDurationMillis: data.autoUpdateDurationMillis.present
          ? data.autoUpdateDurationMillis.value
          : this.autoUpdateDurationMillis,
      subscriptionInfo: data.subscriptionInfo.present
          ? data.subscriptionInfo.value
          : this.subscriptionInfo,
      autoUpdate: data.autoUpdate.present
          ? data.autoUpdate.value
          : this.autoUpdate,
      selectedMap: data.selectedMap.present
          ? data.selectedMap.value
          : this.selectedMap,
      unfoldSet: data.unfoldSet.present ? data.unfoldSet.value : this.unfoldSet,
      order: data.order.present ? data.order.value : this.order,
    );
  }

  @override
  String toString() {
    return (StringBuffer('RawProfile(')
          ..write('id: $id, ')
          ..write('type: $type, ')
          ..write('label: $label, ')
          ..write('currentGroupName: $currentGroupName, ')
          ..write('url: $url, ')
          ..write('ageSecretKey: $ageSecretKey, ')
          ..write('lastUpdateDate: $lastUpdateDate, ')
          ..write('autoUpdateDurationMillis: $autoUpdateDurationMillis, ')
          ..write('subscriptionInfo: $subscriptionInfo, ')
          ..write('autoUpdate: $autoUpdate, ')
          ..write('selectedMap: $selectedMap, ')
          ..write('unfoldSet: $unfoldSet, ')
          ..write('order: $order')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    type,
    label,
    currentGroupName,
    url,
    ageSecretKey,
    lastUpdateDate,
    autoUpdateDurationMillis,
    subscriptionInfo,
    autoUpdate,
    selectedMap,
    unfoldSet,
    order,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is RawProfile &&
          other.id == this.id &&
          other.type == this.type &&
          other.label == this.label &&
          other.currentGroupName == this.currentGroupName &&
          other.url == this.url &&
          other.ageSecretKey == this.ageSecretKey &&
          other.lastUpdateDate == this.lastUpdateDate &&
          other.autoUpdateDurationMillis == this.autoUpdateDurationMillis &&
          other.subscriptionInfo == this.subscriptionInfo &&
          other.autoUpdate == this.autoUpdate &&
          other.selectedMap == this.selectedMap &&
          other.unfoldSet == this.unfoldSet &&
          other.order == this.order);
}

class ProfilesCompanion extends UpdateCompanion<RawProfile> {
  final Value<int> id;
  final Value<ProfileType> type;
  final Value<String> label;
  final Value<String?> currentGroupName;
  final Value<String> url;
  final Value<String?> ageSecretKey;
  final Value<DateTime?> lastUpdateDate;
  final Value<int> autoUpdateDurationMillis;
  final Value<SubscriptionInfo?> subscriptionInfo;
  final Value<bool> autoUpdate;
  final Value<Map<String, String>> selectedMap;
  final Value<Set<String>> unfoldSet;
  final Value<int?> order;
  const ProfilesCompanion({
    this.id = const Value.absent(),
    this.type = const Value.absent(),
    this.label = const Value.absent(),
    this.currentGroupName = const Value.absent(),
    this.url = const Value.absent(),
    this.ageSecretKey = const Value.absent(),
    this.lastUpdateDate = const Value.absent(),
    this.autoUpdateDurationMillis = const Value.absent(),
    this.subscriptionInfo = const Value.absent(),
    this.autoUpdate = const Value.absent(),
    this.selectedMap = const Value.absent(),
    this.unfoldSet = const Value.absent(),
    this.order = const Value.absent(),
  });
  ProfilesCompanion.insert({
    this.id = const Value.absent(),
    required ProfileType type,
    required String label,
    this.currentGroupName = const Value.absent(),
    required String url,
    this.ageSecretKey = const Value.absent(),
    this.lastUpdateDate = const Value.absent(),
    required int autoUpdateDurationMillis,
    this.subscriptionInfo = const Value.absent(),
    required bool autoUpdate,
    required Map<String, String> selectedMap,
    required Set<String> unfoldSet,
    this.order = const Value.absent(),
  }) : type = Value(type),
       label = Value(label),
       url = Value(url),
       autoUpdateDurationMillis = Value(autoUpdateDurationMillis),
       autoUpdate = Value(autoUpdate),
       selectedMap = Value(selectedMap),
       unfoldSet = Value(unfoldSet);
  static Insertable<RawProfile> custom({
    Expression<int>? id,
    Expression<String>? type,
    Expression<String>? label,
    Expression<String>? currentGroupName,
    Expression<String>? url,
    Expression<String>? ageSecretKey,
    Expression<DateTime>? lastUpdateDate,
    Expression<int>? autoUpdateDurationMillis,
    Expression<String>? subscriptionInfo,
    Expression<bool>? autoUpdate,
    Expression<String>? selectedMap,
    Expression<String>? unfoldSet,
    Expression<int>? order,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (type != null) 'type': type,
      if (label != null) 'label': label,
      if (currentGroupName != null) 'current_group_name': currentGroupName,
      if (url != null) 'url': url,
      if (ageSecretKey != null) 'age_secret_key': ageSecretKey,
      if (lastUpdateDate != null) 'last_update_date': lastUpdateDate,
      if (autoUpdateDurationMillis != null)
        'auto_update_duration_millis': autoUpdateDurationMillis,
      if (subscriptionInfo != null) 'subscription_info': subscriptionInfo,
      if (autoUpdate != null) 'auto_update': autoUpdate,
      if (selectedMap != null) 'selected_map': selectedMap,
      if (unfoldSet != null) 'unfold_set': unfoldSet,
      if (order != null) 'order': order,
    });
  }

  ProfilesCompanion copyWith({
    Value<int>? id,
    Value<ProfileType>? type,
    Value<String>? label,
    Value<String?>? currentGroupName,
    Value<String>? url,
    Value<String?>? ageSecretKey,
    Value<DateTime?>? lastUpdateDate,
    Value<int>? autoUpdateDurationMillis,
    Value<SubscriptionInfo?>? subscriptionInfo,
    Value<bool>? autoUpdate,
    Value<Map<String, String>>? selectedMap,
    Value<Set<String>>? unfoldSet,
    Value<int?>? order,
  }) {
    return ProfilesCompanion(
      id: id ?? this.id,
      type: type ?? this.type,
      label: label ?? this.label,
      currentGroupName: currentGroupName ?? this.currentGroupName,
      url: url ?? this.url,
      ageSecretKey: ageSecretKey ?? this.ageSecretKey,
      lastUpdateDate: lastUpdateDate ?? this.lastUpdateDate,
      autoUpdateDurationMillis:
          autoUpdateDurationMillis ?? this.autoUpdateDurationMillis,
      subscriptionInfo: subscriptionInfo ?? this.subscriptionInfo,
      autoUpdate: autoUpdate ?? this.autoUpdate,
      selectedMap: selectedMap ?? this.selectedMap,
      unfoldSet: unfoldSet ?? this.unfoldSet,
      order: order ?? this.order,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (type.present) {
      map['type'] = Variable<String>(
        $ProfilesTable.$convertertype.toSql(type.value),
      );
    }
    if (label.present) {
      map['label'] = Variable<String>(label.value);
    }
    if (currentGroupName.present) {
      map['current_group_name'] = Variable<String>(currentGroupName.value);
    }
    if (url.present) {
      map['url'] = Variable<String>(url.value);
    }
    if (ageSecretKey.present) {
      map['age_secret_key'] = Variable<String>(ageSecretKey.value);
    }
    if (lastUpdateDate.present) {
      map['last_update_date'] = Variable<DateTime>(lastUpdateDate.value);
    }
    if (autoUpdateDurationMillis.present) {
      map['auto_update_duration_millis'] = Variable<int>(
        autoUpdateDurationMillis.value,
      );
    }
    if (subscriptionInfo.present) {
      map['subscription_info'] = Variable<String>(
        $ProfilesTable.$convertersubscriptionInfo.toSql(subscriptionInfo.value),
      );
    }
    if (autoUpdate.present) {
      map['auto_update'] = Variable<bool>(autoUpdate.value);
    }
    if (selectedMap.present) {
      map['selected_map'] = Variable<String>(
        $ProfilesTable.$converterselectedMap.toSql(selectedMap.value),
      );
    }
    if (unfoldSet.present) {
      map['unfold_set'] = Variable<String>(
        $ProfilesTable.$converterunfoldSet.toSql(unfoldSet.value),
      );
    }
    if (order.present) {
      map['order'] = Variable<int>(order.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('ProfilesCompanion(')
          ..write('id: $id, ')
          ..write('type: $type, ')
          ..write('label: $label, ')
          ..write('currentGroupName: $currentGroupName, ')
          ..write('url: $url, ')
          ..write('ageSecretKey: $ageSecretKey, ')
          ..write('lastUpdateDate: $lastUpdateDate, ')
          ..write('autoUpdateDurationMillis: $autoUpdateDurationMillis, ')
          ..write('subscriptionInfo: $subscriptionInfo, ')
          ..write('autoUpdate: $autoUpdate, ')
          ..write('selectedMap: $selectedMap, ')
          ..write('unfoldSet: $unfoldSet, ')
          ..write('order: $order')
          ..write(')'))
        .toString();
  }
}

class $IconRecordsTable extends IconRecords
    with TableInfo<$IconRecordsTable, IconRecord> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $IconRecordsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _urlMeta = const VerificationMeta('url');
  @override
  late final GeneratedColumn<String> url = GeneratedColumn<String>(
    'url',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _lastAccessedMeta = const VerificationMeta(
    'lastAccessed',
  );
  @override
  late final GeneratedColumn<int> lastAccessed = GeneratedColumn<int>(
    'last_accessed',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [url, lastAccessed];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'icon_records';
  @override
  VerificationContext validateIntegrity(
    Insertable<IconRecord> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('url')) {
      context.handle(
        _urlMeta,
        url.isAcceptableOrUnknown(data['url']!, _urlMeta),
      );
    } else if (isInserting) {
      context.missing(_urlMeta);
    }
    if (data.containsKey('last_accessed')) {
      context.handle(
        _lastAccessedMeta,
        lastAccessed.isAcceptableOrUnknown(
          data['last_accessed']!,
          _lastAccessedMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_lastAccessedMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {url};
  @override
  IconRecord map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return IconRecord(
      url: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}url'],
      )!,
      lastAccessed: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}last_accessed'],
      )!,
    );
  }

  @override
  $IconRecordsTable createAlias(String alias) {
    return $IconRecordsTable(attachedDatabase, alias);
  }
}

class IconRecord extends DataClass implements Insertable<IconRecord> {
  final String url;
  final int lastAccessed;
  const IconRecord({required this.url, required this.lastAccessed});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['url'] = Variable<String>(url);
    map['last_accessed'] = Variable<int>(lastAccessed);
    return map;
  }

  IconRecordsCompanion toCompanion(bool nullToAbsent) {
    return IconRecordsCompanion(
      url: Value(url),
      lastAccessed: Value(lastAccessed),
    );
  }

  factory IconRecord.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return IconRecord(
      url: serializer.fromJson<String>(json['url']),
      lastAccessed: serializer.fromJson<int>(json['lastAccessed']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'url': serializer.toJson<String>(url),
      'lastAccessed': serializer.toJson<int>(lastAccessed),
    };
  }

  IconRecord copyWith({String? url, int? lastAccessed}) => IconRecord(
    url: url ?? this.url,
    lastAccessed: lastAccessed ?? this.lastAccessed,
  );
  IconRecord copyWithCompanion(IconRecordsCompanion data) {
    return IconRecord(
      url: data.url.present ? data.url.value : this.url,
      lastAccessed: data.lastAccessed.present
          ? data.lastAccessed.value
          : this.lastAccessed,
    );
  }

  @override
  String toString() {
    return (StringBuffer('IconRecord(')
          ..write('url: $url, ')
          ..write('lastAccessed: $lastAccessed')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(url, lastAccessed);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is IconRecord &&
          other.url == this.url &&
          other.lastAccessed == this.lastAccessed);
}

class IconRecordsCompanion extends UpdateCompanion<IconRecord> {
  final Value<String> url;
  final Value<int> lastAccessed;
  final Value<int> rowid;
  const IconRecordsCompanion({
    this.url = const Value.absent(),
    this.lastAccessed = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  IconRecordsCompanion.insert({
    required String url,
    required int lastAccessed,
    this.rowid = const Value.absent(),
  }) : url = Value(url),
       lastAccessed = Value(lastAccessed);
  static Insertable<IconRecord> custom({
    Expression<String>? url,
    Expression<int>? lastAccessed,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (url != null) 'url': url,
      if (lastAccessed != null) 'last_accessed': lastAccessed,
      if (rowid != null) 'rowid': rowid,
    });
  }

  IconRecordsCompanion copyWith({
    Value<String>? url,
    Value<int>? lastAccessed,
    Value<int>? rowid,
  }) {
    return IconRecordsCompanion(
      url: url ?? this.url,
      lastAccessed: lastAccessed ?? this.lastAccessed,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (url.present) {
      map['url'] = Variable<String>(url.value);
    }
    if (lastAccessed.present) {
      map['last_accessed'] = Variable<int>(lastAccessed.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('IconRecordsCompanion(')
          ..write('url: $url, ')
          ..write('lastAccessed: $lastAccessed, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $IconSetsTable extends IconSets
    with TableInfo<$IconSetsTable, RawIconSet> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $IconSetsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _nameMeta = const VerificationMeta('name');
  @override
  late final GeneratedColumn<String> name = GeneratedColumn<String>(
    'name',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _urlMeta = const VerificationMeta('url');
  @override
  late final GeneratedColumn<String> url = GeneratedColumn<String>(
    'url',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  @override
  late final GeneratedColumnWithTypeConverter<List<IconSetIcon>, String> icons =
      GeneratedColumn<String>(
        'icons',
        aliasedName,
        false,
        type: DriftSqlType.string,
        requiredDuringInsert: true,
      ).withConverter<List<IconSetIcon>>($IconSetsTable.$convertericons);
  static const VerificationMeta _lastUpdateTimeMeta = const VerificationMeta(
    'lastUpdateTime',
  );
  @override
  late final GeneratedColumn<DateTime> lastUpdateTime =
      GeneratedColumn<DateTime>(
        'last_update_time',
        aliasedName,
        true,
        type: DriftSqlType.dateTime,
        requiredDuringInsert: false,
      );
  static const VerificationMeta _orderMeta = const VerificationMeta('order');
  @override
  late final GeneratedColumn<int> order = GeneratedColumn<int>(
    'order',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    name,
    url,
    icons,
    lastUpdateTime,
    order,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'icon_sets';
  @override
  VerificationContext validateIntegrity(
    Insertable<RawIconSet> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('name')) {
      context.handle(
        _nameMeta,
        name.isAcceptableOrUnknown(data['name']!, _nameMeta),
      );
    } else if (isInserting) {
      context.missing(_nameMeta);
    }
    if (data.containsKey('url')) {
      context.handle(
        _urlMeta,
        url.isAcceptableOrUnknown(data['url']!, _urlMeta),
      );
    } else if (isInserting) {
      context.missing(_urlMeta);
    }
    if (data.containsKey('last_update_time')) {
      context.handle(
        _lastUpdateTimeMeta,
        lastUpdateTime.isAcceptableOrUnknown(
          data['last_update_time']!,
          _lastUpdateTimeMeta,
        ),
      );
    }
    if (data.containsKey('order')) {
      context.handle(
        _orderMeta,
        order.isAcceptableOrUnknown(data['order']!, _orderMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  RawIconSet map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return RawIconSet(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      name: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}name'],
      )!,
      url: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}url'],
      )!,
      icons: $IconSetsTable.$convertericons.fromSql(
        attachedDatabase.typeMapping.read(
          DriftSqlType.string,
          data['${effectivePrefix}icons'],
        )!,
      ),
      lastUpdateTime: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}last_update_time'],
      ),
      order: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}order'],
      ),
    );
  }

  @override
  $IconSetsTable createAlias(String alias) {
    return $IconSetsTable(attachedDatabase, alias);
  }

  static TypeConverter<List<IconSetIcon>, String> $convertericons =
      const IconSetIconsConverter();
}

class RawIconSet extends DataClass implements Insertable<RawIconSet> {
  final int id;
  final String name;
  final String url;
  final List<IconSetIcon> icons;
  final DateTime? lastUpdateTime;
  final int? order;
  const RawIconSet({
    required this.id,
    required this.name,
    required this.url,
    required this.icons,
    this.lastUpdateTime,
    this.order,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['name'] = Variable<String>(name);
    map['url'] = Variable<String>(url);
    {
      map['icons'] = Variable<String>(
        $IconSetsTable.$convertericons.toSql(icons),
      );
    }
    if (!nullToAbsent || lastUpdateTime != null) {
      map['last_update_time'] = Variable<DateTime>(lastUpdateTime);
    }
    if (!nullToAbsent || order != null) {
      map['order'] = Variable<int>(order);
    }
    return map;
  }

  IconSetsCompanion toCompanion(bool nullToAbsent) {
    return IconSetsCompanion(
      id: Value(id),
      name: Value(name),
      url: Value(url),
      icons: Value(icons),
      lastUpdateTime: lastUpdateTime == null && nullToAbsent
          ? const Value.absent()
          : Value(lastUpdateTime),
      order: order == null && nullToAbsent
          ? const Value.absent()
          : Value(order),
    );
  }

  factory RawIconSet.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return RawIconSet(
      id: serializer.fromJson<int>(json['id']),
      name: serializer.fromJson<String>(json['name']),
      url: serializer.fromJson<String>(json['url']),
      icons: serializer.fromJson<List<IconSetIcon>>(json['icons']),
      lastUpdateTime: serializer.fromJson<DateTime?>(json['lastUpdateTime']),
      order: serializer.fromJson<int?>(json['order']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'name': serializer.toJson<String>(name),
      'url': serializer.toJson<String>(url),
      'icons': serializer.toJson<List<IconSetIcon>>(icons),
      'lastUpdateTime': serializer.toJson<DateTime?>(lastUpdateTime),
      'order': serializer.toJson<int?>(order),
    };
  }

  RawIconSet copyWith({
    int? id,
    String? name,
    String? url,
    List<IconSetIcon>? icons,
    Value<DateTime?> lastUpdateTime = const Value.absent(),
    Value<int?> order = const Value.absent(),
  }) => RawIconSet(
    id: id ?? this.id,
    name: name ?? this.name,
    url: url ?? this.url,
    icons: icons ?? this.icons,
    lastUpdateTime: lastUpdateTime.present
        ? lastUpdateTime.value
        : this.lastUpdateTime,
    order: order.present ? order.value : this.order,
  );
  RawIconSet copyWithCompanion(IconSetsCompanion data) {
    return RawIconSet(
      id: data.id.present ? data.id.value : this.id,
      name: data.name.present ? data.name.value : this.name,
      url: data.url.present ? data.url.value : this.url,
      icons: data.icons.present ? data.icons.value : this.icons,
      lastUpdateTime: data.lastUpdateTime.present
          ? data.lastUpdateTime.value
          : this.lastUpdateTime,
      order: data.order.present ? data.order.value : this.order,
    );
  }

  @override
  String toString() {
    return (StringBuffer('RawIconSet(')
          ..write('id: $id, ')
          ..write('name: $name, ')
          ..write('url: $url, ')
          ..write('icons: $icons, ')
          ..write('lastUpdateTime: $lastUpdateTime, ')
          ..write('order: $order')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(id, name, url, icons, lastUpdateTime, order);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is RawIconSet &&
          other.id == this.id &&
          other.name == this.name &&
          other.url == this.url &&
          other.icons == this.icons &&
          other.lastUpdateTime == this.lastUpdateTime &&
          other.order == this.order);
}

class IconSetsCompanion extends UpdateCompanion<RawIconSet> {
  final Value<int> id;
  final Value<String> name;
  final Value<String> url;
  final Value<List<IconSetIcon>> icons;
  final Value<DateTime?> lastUpdateTime;
  final Value<int?> order;
  const IconSetsCompanion({
    this.id = const Value.absent(),
    this.name = const Value.absent(),
    this.url = const Value.absent(),
    this.icons = const Value.absent(),
    this.lastUpdateTime = const Value.absent(),
    this.order = const Value.absent(),
  });
  IconSetsCompanion.insert({
    this.id = const Value.absent(),
    required String name,
    required String url,
    required List<IconSetIcon> icons,
    this.lastUpdateTime = const Value.absent(),
    this.order = const Value.absent(),
  }) : name = Value(name),
       url = Value(url),
       icons = Value(icons);
  static Insertable<RawIconSet> custom({
    Expression<int>? id,
    Expression<String>? name,
    Expression<String>? url,
    Expression<String>? icons,
    Expression<DateTime>? lastUpdateTime,
    Expression<int>? order,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (name != null) 'name': name,
      if (url != null) 'url': url,
      if (icons != null) 'icons': icons,
      if (lastUpdateTime != null) 'last_update_time': lastUpdateTime,
      if (order != null) 'order': order,
    });
  }

  IconSetsCompanion copyWith({
    Value<int>? id,
    Value<String>? name,
    Value<String>? url,
    Value<List<IconSetIcon>>? icons,
    Value<DateTime?>? lastUpdateTime,
    Value<int?>? order,
  }) {
    return IconSetsCompanion(
      id: id ?? this.id,
      name: name ?? this.name,
      url: url ?? this.url,
      icons: icons ?? this.icons,
      lastUpdateTime: lastUpdateTime ?? this.lastUpdateTime,
      order: order ?? this.order,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (name.present) {
      map['name'] = Variable<String>(name.value);
    }
    if (url.present) {
      map['url'] = Variable<String>(url.value);
    }
    if (icons.present) {
      map['icons'] = Variable<String>(
        $IconSetsTable.$convertericons.toSql(icons.value),
      );
    }
    if (lastUpdateTime.present) {
      map['last_update_time'] = Variable<DateTime>(lastUpdateTime.value);
    }
    if (order.present) {
      map['order'] = Variable<int>(order.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('IconSetsCompanion(')
          ..write('id: $id, ')
          ..write('name: $name, ')
          ..write('url: $url, ')
          ..write('icons: $icons, ')
          ..write('lastUpdateTime: $lastUpdateTime, ')
          ..write('order: $order')
          ..write(')'))
        .toString();
  }
}

class $ClashProvidersTable extends ClashProviders
    with TableInfo<$ClashProvidersTable, RawClashProvider> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $ClashProvidersTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  @override
  late final GeneratedColumnWithTypeConverter<ProviderKind, String> kind =
      GeneratedColumn<String>(
        'kind',
        aliasedName,
        false,
        type: DriftSqlType.string,
        requiredDuringInsert: true,
      ).withConverter<ProviderKind>($ClashProvidersTable.$converterkind);
  static const VerificationMeta _labelMeta = const VerificationMeta('label');
  @override
  late final GeneratedColumn<String> label = GeneratedColumn<String>(
    'label',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _urlMeta = const VerificationMeta('url');
  @override
  late final GeneratedColumn<String> url = GeneratedColumn<String>(
    'url',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  @override
  late final GeneratedColumnWithTypeConverter<RuleProviderBehavior?, String>
  behavior =
      GeneratedColumn<String>(
        'behavior',
        aliasedName,
        true,
        type: DriftSqlType.string,
        requiredDuringInsert: false,
      ).withConverter<RuleProviderBehavior?>(
        $ClashProvidersTable.$converterbehaviorn,
      );
  @override
  late final GeneratedColumnWithTypeConverter<RuleProviderFormat?, String>
  format = GeneratedColumn<String>(
    'format',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  ).withConverter<RuleProviderFormat?>($ClashProvidersTable.$converterformatn);
  static const VerificationMeta _orderMeta = const VerificationMeta('order');
  @override
  late final GeneratedColumn<int> order = GeneratedColumn<int>(
    'order',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    kind,
    label,
    url,
    behavior,
    format,
    order,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'clash_providers';
  @override
  VerificationContext validateIntegrity(
    Insertable<RawClashProvider> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('label')) {
      context.handle(
        _labelMeta,
        label.isAcceptableOrUnknown(data['label']!, _labelMeta),
      );
    } else if (isInserting) {
      context.missing(_labelMeta);
    }
    if (data.containsKey('url')) {
      context.handle(
        _urlMeta,
        url.isAcceptableOrUnknown(data['url']!, _urlMeta),
      );
    } else if (isInserting) {
      context.missing(_urlMeta);
    }
    if (data.containsKey('order')) {
      context.handle(
        _orderMeta,
        order.isAcceptableOrUnknown(data['order']!, _orderMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  RawClashProvider map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return RawClashProvider(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      kind: $ClashProvidersTable.$converterkind.fromSql(
        attachedDatabase.typeMapping.read(
          DriftSqlType.string,
          data['${effectivePrefix}kind'],
        )!,
      ),
      label: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}label'],
      )!,
      url: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}url'],
      )!,
      behavior: $ClashProvidersTable.$converterbehaviorn.fromSql(
        attachedDatabase.typeMapping.read(
          DriftSqlType.string,
          data['${effectivePrefix}behavior'],
        ),
      ),
      format: $ClashProvidersTable.$converterformatn.fromSql(
        attachedDatabase.typeMapping.read(
          DriftSqlType.string,
          data['${effectivePrefix}format'],
        ),
      ),
      order: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}order'],
      ),
    );
  }

  @override
  $ClashProvidersTable createAlias(String alias) {
    return $ClashProvidersTable(attachedDatabase, alias);
  }

  static JsonTypeConverter2<ProviderKind, String, String> $converterkind =
      const EnumNameConverter<ProviderKind>(ProviderKind.values);
  static JsonTypeConverter2<RuleProviderBehavior, String, String>
  $converterbehavior = const EnumNameConverter<RuleProviderBehavior>(
    RuleProviderBehavior.values,
  );
  static JsonTypeConverter2<RuleProviderBehavior?, String?, String?>
  $converterbehaviorn = JsonTypeConverter2.asNullable($converterbehavior);
  static JsonTypeConverter2<RuleProviderFormat, String, String>
  $converterformat = const EnumNameConverter<RuleProviderFormat>(
    RuleProviderFormat.values,
  );
  static JsonTypeConverter2<RuleProviderFormat?, String?, String?>
  $converterformatn = JsonTypeConverter2.asNullable($converterformat);
}

class RawClashProvider extends DataClass
    implements Insertable<RawClashProvider> {
  final int id;
  final ProviderKind kind;
  final String label;
  final String url;
  final RuleProviderBehavior? behavior;
  final RuleProviderFormat? format;
  final int? order;
  const RawClashProvider({
    required this.id,
    required this.kind,
    required this.label,
    required this.url,
    this.behavior,
    this.format,
    this.order,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    {
      map['kind'] = Variable<String>(
        $ClashProvidersTable.$converterkind.toSql(kind),
      );
    }
    map['label'] = Variable<String>(label);
    map['url'] = Variable<String>(url);
    if (!nullToAbsent || behavior != null) {
      map['behavior'] = Variable<String>(
        $ClashProvidersTable.$converterbehaviorn.toSql(behavior),
      );
    }
    if (!nullToAbsent || format != null) {
      map['format'] = Variable<String>(
        $ClashProvidersTable.$converterformatn.toSql(format),
      );
    }
    if (!nullToAbsent || order != null) {
      map['order'] = Variable<int>(order);
    }
    return map;
  }

  ClashProvidersCompanion toCompanion(bool nullToAbsent) {
    return ClashProvidersCompanion(
      id: Value(id),
      kind: Value(kind),
      label: Value(label),
      url: Value(url),
      behavior: behavior == null && nullToAbsent
          ? const Value.absent()
          : Value(behavior),
      format: format == null && nullToAbsent
          ? const Value.absent()
          : Value(format),
      order: order == null && nullToAbsent
          ? const Value.absent()
          : Value(order),
    );
  }

  factory RawClashProvider.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return RawClashProvider(
      id: serializer.fromJson<int>(json['id']),
      kind: $ClashProvidersTable.$converterkind.fromJson(
        serializer.fromJson<String>(json['kind']),
      ),
      label: serializer.fromJson<String>(json['label']),
      url: serializer.fromJson<String>(json['url']),
      behavior: $ClashProvidersTable.$converterbehaviorn.fromJson(
        serializer.fromJson<String?>(json['behavior']),
      ),
      format: $ClashProvidersTable.$converterformatn.fromJson(
        serializer.fromJson<String?>(json['format']),
      ),
      order: serializer.fromJson<int?>(json['order']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'kind': serializer.toJson<String>(
        $ClashProvidersTable.$converterkind.toJson(kind),
      ),
      'label': serializer.toJson<String>(label),
      'url': serializer.toJson<String>(url),
      'behavior': serializer.toJson<String?>(
        $ClashProvidersTable.$converterbehaviorn.toJson(behavior),
      ),
      'format': serializer.toJson<String?>(
        $ClashProvidersTable.$converterformatn.toJson(format),
      ),
      'order': serializer.toJson<int?>(order),
    };
  }

  RawClashProvider copyWith({
    int? id,
    ProviderKind? kind,
    String? label,
    String? url,
    Value<RuleProviderBehavior?> behavior = const Value.absent(),
    Value<RuleProviderFormat?> format = const Value.absent(),
    Value<int?> order = const Value.absent(),
  }) => RawClashProvider(
    id: id ?? this.id,
    kind: kind ?? this.kind,
    label: label ?? this.label,
    url: url ?? this.url,
    behavior: behavior.present ? behavior.value : this.behavior,
    format: format.present ? format.value : this.format,
    order: order.present ? order.value : this.order,
  );
  RawClashProvider copyWithCompanion(ClashProvidersCompanion data) {
    return RawClashProvider(
      id: data.id.present ? data.id.value : this.id,
      kind: data.kind.present ? data.kind.value : this.kind,
      label: data.label.present ? data.label.value : this.label,
      url: data.url.present ? data.url.value : this.url,
      behavior: data.behavior.present ? data.behavior.value : this.behavior,
      format: data.format.present ? data.format.value : this.format,
      order: data.order.present ? data.order.value : this.order,
    );
  }

  @override
  String toString() {
    return (StringBuffer('RawClashProvider(')
          ..write('id: $id, ')
          ..write('kind: $kind, ')
          ..write('label: $label, ')
          ..write('url: $url, ')
          ..write('behavior: $behavior, ')
          ..write('format: $format, ')
          ..write('order: $order')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode =>
      Object.hash(id, kind, label, url, behavior, format, order);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is RawClashProvider &&
          other.id == this.id &&
          other.kind == this.kind &&
          other.label == this.label &&
          other.url == this.url &&
          other.behavior == this.behavior &&
          other.format == this.format &&
          other.order == this.order);
}

class ClashProvidersCompanion extends UpdateCompanion<RawClashProvider> {
  final Value<int> id;
  final Value<ProviderKind> kind;
  final Value<String> label;
  final Value<String> url;
  final Value<RuleProviderBehavior?> behavior;
  final Value<RuleProviderFormat?> format;
  final Value<int?> order;
  const ClashProvidersCompanion({
    this.id = const Value.absent(),
    this.kind = const Value.absent(),
    this.label = const Value.absent(),
    this.url = const Value.absent(),
    this.behavior = const Value.absent(),
    this.format = const Value.absent(),
    this.order = const Value.absent(),
  });
  ClashProvidersCompanion.insert({
    this.id = const Value.absent(),
    required ProviderKind kind,
    required String label,
    required String url,
    this.behavior = const Value.absent(),
    this.format = const Value.absent(),
    this.order = const Value.absent(),
  }) : kind = Value(kind),
       label = Value(label),
       url = Value(url);
  static Insertable<RawClashProvider> custom({
    Expression<int>? id,
    Expression<String>? kind,
    Expression<String>? label,
    Expression<String>? url,
    Expression<String>? behavior,
    Expression<String>? format,
    Expression<int>? order,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (kind != null) 'kind': kind,
      if (label != null) 'label': label,
      if (url != null) 'url': url,
      if (behavior != null) 'behavior': behavior,
      if (format != null) 'format': format,
      if (order != null) 'order': order,
    });
  }

  ClashProvidersCompanion copyWith({
    Value<int>? id,
    Value<ProviderKind>? kind,
    Value<String>? label,
    Value<String>? url,
    Value<RuleProviderBehavior?>? behavior,
    Value<RuleProviderFormat?>? format,
    Value<int?>? order,
  }) {
    return ClashProvidersCompanion(
      id: id ?? this.id,
      kind: kind ?? this.kind,
      label: label ?? this.label,
      url: url ?? this.url,
      behavior: behavior ?? this.behavior,
      format: format ?? this.format,
      order: order ?? this.order,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (kind.present) {
      map['kind'] = Variable<String>(
        $ClashProvidersTable.$converterkind.toSql(kind.value),
      );
    }
    if (label.present) {
      map['label'] = Variable<String>(label.value);
    }
    if (url.present) {
      map['url'] = Variable<String>(url.value);
    }
    if (behavior.present) {
      map['behavior'] = Variable<String>(
        $ClashProvidersTable.$converterbehaviorn.toSql(behavior.value),
      );
    }
    if (format.present) {
      map['format'] = Variable<String>(
        $ClashProvidersTable.$converterformatn.toSql(format.value),
      );
    }
    if (order.present) {
      map['order'] = Variable<int>(order.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('ClashProvidersCompanion(')
          ..write('id: $id, ')
          ..write('kind: $kind, ')
          ..write('label: $label, ')
          ..write('url: $url, ')
          ..write('behavior: $behavior, ')
          ..write('format: $format, ')
          ..write('order: $order')
          ..write(')'))
        .toString();
  }
}

abstract class _$Database extends GeneratedDatabase {
  _$Database(QueryExecutor e) : super(e);
  $DatabaseManager get managers => $DatabaseManager(this);
  late final $ProfilesTable profiles = $ProfilesTable(this);
  late final $IconRecordsTable iconRecords = $IconRecordsTable(this);
  late final $IconSetsTable iconSets = $IconSetsTable(this);
  late final $ClashProvidersTable clashProviders = $ClashProvidersTable(this);
  late final Index lastAccessedUrl = Index(
    'last_accessed_url',
    'CREATE INDEX last_accessed_url ON icon_records (last_accessed, url)',
  );
  late final ProfilesDao profilesDao = ProfilesDao(this as Database);
  late final IconRecordsDao iconRecordsDao = IconRecordsDao(this as Database);
  late final IconSetsDao iconSetsDao = IconSetsDao(this as Database);
  late final ClashProvidersDao clashProvidersDao = ClashProvidersDao(
    this as Database,
  );
  @override
  Iterable<TableInfo<Table, Object?>> get allTables =>
      allSchemaEntities.whereType<TableInfo<Table, Object?>>();
  @override
  List<DatabaseSchemaEntity> get allSchemaEntities => [
    profiles,
    iconRecords,
    iconSets,
    clashProviders,
    lastAccessedUrl,
  ];
}

typedef $$ProfilesTableCreateCompanionBuilder =
    ProfilesCompanion Function({
      Value<int> id,
      required ProfileType type,
      required String label,
      Value<String?> currentGroupName,
      required String url,
      Value<String?> ageSecretKey,
      Value<DateTime?> lastUpdateDate,
      required int autoUpdateDurationMillis,
      Value<SubscriptionInfo?> subscriptionInfo,
      required bool autoUpdate,
      required Map<String, String> selectedMap,
      required Set<String> unfoldSet,
      Value<int?> order,
    });
typedef $$ProfilesTableUpdateCompanionBuilder =
    ProfilesCompanion Function({
      Value<int> id,
      Value<ProfileType> type,
      Value<String> label,
      Value<String?> currentGroupName,
      Value<String> url,
      Value<String?> ageSecretKey,
      Value<DateTime?> lastUpdateDate,
      Value<int> autoUpdateDurationMillis,
      Value<SubscriptionInfo?> subscriptionInfo,
      Value<bool> autoUpdate,
      Value<Map<String, String>> selectedMap,
      Value<Set<String>> unfoldSet,
      Value<int?> order,
    });

class $$ProfilesTableFilterComposer
    extends Composer<_$Database, $ProfilesTable> {
  $$ProfilesTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnWithTypeConverterFilters<ProfileType, ProfileType, String> get type =>
      $composableBuilder(
        column: $table.type,
        builder: (column) => ColumnWithTypeConverterFilters(column),
      );

  ColumnFilters<String> get label => $composableBuilder(
    column: $table.label,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get currentGroupName => $composableBuilder(
    column: $table.currentGroupName,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get url => $composableBuilder(
    column: $table.url,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get ageSecretKey => $composableBuilder(
    column: $table.ageSecretKey,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get lastUpdateDate => $composableBuilder(
    column: $table.lastUpdateDate,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get autoUpdateDurationMillis => $composableBuilder(
    column: $table.autoUpdateDurationMillis,
    builder: (column) => ColumnFilters(column),
  );

  ColumnWithTypeConverterFilters<SubscriptionInfo?, SubscriptionInfo, String>
  get subscriptionInfo => $composableBuilder(
    column: $table.subscriptionInfo,
    builder: (column) => ColumnWithTypeConverterFilters(column),
  );

  ColumnFilters<bool> get autoUpdate => $composableBuilder(
    column: $table.autoUpdate,
    builder: (column) => ColumnFilters(column),
  );

  ColumnWithTypeConverterFilters<
    Map<String, String>,
    Map<String, String>,
    String
  >
  get selectedMap => $composableBuilder(
    column: $table.selectedMap,
    builder: (column) => ColumnWithTypeConverterFilters(column),
  );

  ColumnWithTypeConverterFilters<Set<String>, Set<String>, String>
  get unfoldSet => $composableBuilder(
    column: $table.unfoldSet,
    builder: (column) => ColumnWithTypeConverterFilters(column),
  );

  ColumnFilters<int> get order => $composableBuilder(
    column: $table.order,
    builder: (column) => ColumnFilters(column),
  );
}

class $$ProfilesTableOrderingComposer
    extends Composer<_$Database, $ProfilesTable> {
  $$ProfilesTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get type => $composableBuilder(
    column: $table.type,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get label => $composableBuilder(
    column: $table.label,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get currentGroupName => $composableBuilder(
    column: $table.currentGroupName,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get url => $composableBuilder(
    column: $table.url,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get ageSecretKey => $composableBuilder(
    column: $table.ageSecretKey,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get lastUpdateDate => $composableBuilder(
    column: $table.lastUpdateDate,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get autoUpdateDurationMillis => $composableBuilder(
    column: $table.autoUpdateDurationMillis,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get subscriptionInfo => $composableBuilder(
    column: $table.subscriptionInfo,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get autoUpdate => $composableBuilder(
    column: $table.autoUpdate,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get selectedMap => $composableBuilder(
    column: $table.selectedMap,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get unfoldSet => $composableBuilder(
    column: $table.unfoldSet,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get order => $composableBuilder(
    column: $table.order,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$ProfilesTableAnnotationComposer
    extends Composer<_$Database, $ProfilesTable> {
  $$ProfilesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumnWithTypeConverter<ProfileType, String> get type =>
      $composableBuilder(column: $table.type, builder: (column) => column);

  GeneratedColumn<String> get label =>
      $composableBuilder(column: $table.label, builder: (column) => column);

  GeneratedColumn<String> get currentGroupName => $composableBuilder(
    column: $table.currentGroupName,
    builder: (column) => column,
  );

  GeneratedColumn<String> get url =>
      $composableBuilder(column: $table.url, builder: (column) => column);

  GeneratedColumn<String> get ageSecretKey => $composableBuilder(
    column: $table.ageSecretKey,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get lastUpdateDate => $composableBuilder(
    column: $table.lastUpdateDate,
    builder: (column) => column,
  );

  GeneratedColumn<int> get autoUpdateDurationMillis => $composableBuilder(
    column: $table.autoUpdateDurationMillis,
    builder: (column) => column,
  );

  GeneratedColumnWithTypeConverter<SubscriptionInfo?, String>
  get subscriptionInfo => $composableBuilder(
    column: $table.subscriptionInfo,
    builder: (column) => column,
  );

  GeneratedColumn<bool> get autoUpdate => $composableBuilder(
    column: $table.autoUpdate,
    builder: (column) => column,
  );

  GeneratedColumnWithTypeConverter<Map<String, String>, String>
  get selectedMap => $composableBuilder(
    column: $table.selectedMap,
    builder: (column) => column,
  );

  GeneratedColumnWithTypeConverter<Set<String>, String> get unfoldSet =>
      $composableBuilder(column: $table.unfoldSet, builder: (column) => column);

  GeneratedColumn<int> get order =>
      $composableBuilder(column: $table.order, builder: (column) => column);
}

class $$ProfilesTableTableManager
    extends
        RootTableManager<
          _$Database,
          $ProfilesTable,
          RawProfile,
          $$ProfilesTableFilterComposer,
          $$ProfilesTableOrderingComposer,
          $$ProfilesTableAnnotationComposer,
          $$ProfilesTableCreateCompanionBuilder,
          $$ProfilesTableUpdateCompanionBuilder,
          (RawProfile, BaseReferences<_$Database, $ProfilesTable, RawProfile>),
          RawProfile,
          PrefetchHooks Function()
        > {
  $$ProfilesTableTableManager(_$Database db, $ProfilesTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$ProfilesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$ProfilesTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$ProfilesTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<ProfileType> type = const Value.absent(),
                Value<String> label = const Value.absent(),
                Value<String?> currentGroupName = const Value.absent(),
                Value<String> url = const Value.absent(),
                Value<String?> ageSecretKey = const Value.absent(),
                Value<DateTime?> lastUpdateDate = const Value.absent(),
                Value<int> autoUpdateDurationMillis = const Value.absent(),
                Value<SubscriptionInfo?> subscriptionInfo =
                    const Value.absent(),
                Value<bool> autoUpdate = const Value.absent(),
                Value<Map<String, String>> selectedMap = const Value.absent(),
                Value<Set<String>> unfoldSet = const Value.absent(),
                Value<int?> order = const Value.absent(),
              }) => ProfilesCompanion(
                id: id,
                type: type,
                label: label,
                currentGroupName: currentGroupName,
                url: url,
                ageSecretKey: ageSecretKey,
                lastUpdateDate: lastUpdateDate,
                autoUpdateDurationMillis: autoUpdateDurationMillis,
                subscriptionInfo: subscriptionInfo,
                autoUpdate: autoUpdate,
                selectedMap: selectedMap,
                unfoldSet: unfoldSet,
                order: order,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                required ProfileType type,
                required String label,
                Value<String?> currentGroupName = const Value.absent(),
                required String url,
                Value<String?> ageSecretKey = const Value.absent(),
                Value<DateTime?> lastUpdateDate = const Value.absent(),
                required int autoUpdateDurationMillis,
                Value<SubscriptionInfo?> subscriptionInfo =
                    const Value.absent(),
                required bool autoUpdate,
                required Map<String, String> selectedMap,
                required Set<String> unfoldSet,
                Value<int?> order = const Value.absent(),
              }) => ProfilesCompanion.insert(
                id: id,
                type: type,
                label: label,
                currentGroupName: currentGroupName,
                url: url,
                ageSecretKey: ageSecretKey,
                lastUpdateDate: lastUpdateDate,
                autoUpdateDurationMillis: autoUpdateDurationMillis,
                subscriptionInfo: subscriptionInfo,
                autoUpdate: autoUpdate,
                selectedMap: selectedMap,
                unfoldSet: unfoldSet,
                order: order,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$ProfilesTable, RawProfile>(table),
                  BaseReferences<_$Database, $ProfilesTable, RawProfile>(
                    db,
                    table,
                    e,
                  ),
                ),
              )
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$ProfilesTableProcessedTableManager =
    ProcessedTableManager<
      _$Database,
      $ProfilesTable,
      RawProfile,
      $$ProfilesTableFilterComposer,
      $$ProfilesTableOrderingComposer,
      $$ProfilesTableAnnotationComposer,
      $$ProfilesTableCreateCompanionBuilder,
      $$ProfilesTableUpdateCompanionBuilder,
      (RawProfile, BaseReferences<_$Database, $ProfilesTable, RawProfile>),
      RawProfile,
      PrefetchHooks Function()
    >;
typedef $$IconRecordsTableCreateCompanionBuilder =
    IconRecordsCompanion Function({
      required String url,
      required int lastAccessed,
      Value<int> rowid,
    });
typedef $$IconRecordsTableUpdateCompanionBuilder =
    IconRecordsCompanion Function({
      Value<String> url,
      Value<int> lastAccessed,
      Value<int> rowid,
    });

class $$IconRecordsTableFilterComposer
    extends Composer<_$Database, $IconRecordsTable> {
  $$IconRecordsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get url => $composableBuilder(
    column: $table.url,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get lastAccessed => $composableBuilder(
    column: $table.lastAccessed,
    builder: (column) => ColumnFilters(column),
  );
}

class $$IconRecordsTableOrderingComposer
    extends Composer<_$Database, $IconRecordsTable> {
  $$IconRecordsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get url => $composableBuilder(
    column: $table.url,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get lastAccessed => $composableBuilder(
    column: $table.lastAccessed,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$IconRecordsTableAnnotationComposer
    extends Composer<_$Database, $IconRecordsTable> {
  $$IconRecordsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get url =>
      $composableBuilder(column: $table.url, builder: (column) => column);

  GeneratedColumn<int> get lastAccessed => $composableBuilder(
    column: $table.lastAccessed,
    builder: (column) => column,
  );
}

class $$IconRecordsTableTableManager
    extends
        RootTableManager<
          _$Database,
          $IconRecordsTable,
          IconRecord,
          $$IconRecordsTableFilterComposer,
          $$IconRecordsTableOrderingComposer,
          $$IconRecordsTableAnnotationComposer,
          $$IconRecordsTableCreateCompanionBuilder,
          $$IconRecordsTableUpdateCompanionBuilder,
          (
            IconRecord,
            BaseReferences<_$Database, $IconRecordsTable, IconRecord>,
          ),
          IconRecord,
          PrefetchHooks Function()
        > {
  $$IconRecordsTableTableManager(_$Database db, $IconRecordsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$IconRecordsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$IconRecordsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$IconRecordsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> url = const Value.absent(),
                Value<int> lastAccessed = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => IconRecordsCompanion(
                url: url,
                lastAccessed: lastAccessed,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String url,
                required int lastAccessed,
                Value<int> rowid = const Value.absent(),
              }) => IconRecordsCompanion.insert(
                url: url,
                lastAccessed: lastAccessed,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$IconRecordsTable, IconRecord>(table),
                  BaseReferences<_$Database, $IconRecordsTable, IconRecord>(
                    db,
                    table,
                    e,
                  ),
                ),
              )
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$IconRecordsTableProcessedTableManager =
    ProcessedTableManager<
      _$Database,
      $IconRecordsTable,
      IconRecord,
      $$IconRecordsTableFilterComposer,
      $$IconRecordsTableOrderingComposer,
      $$IconRecordsTableAnnotationComposer,
      $$IconRecordsTableCreateCompanionBuilder,
      $$IconRecordsTableUpdateCompanionBuilder,
      (IconRecord, BaseReferences<_$Database, $IconRecordsTable, IconRecord>),
      IconRecord,
      PrefetchHooks Function()
    >;
typedef $$IconSetsTableCreateCompanionBuilder =
    IconSetsCompanion Function({
      Value<int> id,
      required String name,
      required String url,
      required List<IconSetIcon> icons,
      Value<DateTime?> lastUpdateTime,
      Value<int?> order,
    });
typedef $$IconSetsTableUpdateCompanionBuilder =
    IconSetsCompanion Function({
      Value<int> id,
      Value<String> name,
      Value<String> url,
      Value<List<IconSetIcon>> icons,
      Value<DateTime?> lastUpdateTime,
      Value<int?> order,
    });

class $$IconSetsTableFilterComposer
    extends Composer<_$Database, $IconSetsTable> {
  $$IconSetsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get url => $composableBuilder(
    column: $table.url,
    builder: (column) => ColumnFilters(column),
  );

  ColumnWithTypeConverterFilters<List<IconSetIcon>, List<IconSetIcon>, String>
  get icons => $composableBuilder(
    column: $table.icons,
    builder: (column) => ColumnWithTypeConverterFilters(column),
  );

  ColumnFilters<DateTime> get lastUpdateTime => $composableBuilder(
    column: $table.lastUpdateTime,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get order => $composableBuilder(
    column: $table.order,
    builder: (column) => ColumnFilters(column),
  );
}

class $$IconSetsTableOrderingComposer
    extends Composer<_$Database, $IconSetsTable> {
  $$IconSetsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get url => $composableBuilder(
    column: $table.url,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get icons => $composableBuilder(
    column: $table.icons,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get lastUpdateTime => $composableBuilder(
    column: $table.lastUpdateTime,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get order => $composableBuilder(
    column: $table.order,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$IconSetsTableAnnotationComposer
    extends Composer<_$Database, $IconSetsTable> {
  $$IconSetsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get name =>
      $composableBuilder(column: $table.name, builder: (column) => column);

  GeneratedColumn<String> get url =>
      $composableBuilder(column: $table.url, builder: (column) => column);

  GeneratedColumnWithTypeConverter<List<IconSetIcon>, String> get icons =>
      $composableBuilder(column: $table.icons, builder: (column) => column);

  GeneratedColumn<DateTime> get lastUpdateTime => $composableBuilder(
    column: $table.lastUpdateTime,
    builder: (column) => column,
  );

  GeneratedColumn<int> get order =>
      $composableBuilder(column: $table.order, builder: (column) => column);
}

class $$IconSetsTableTableManager
    extends
        RootTableManager<
          _$Database,
          $IconSetsTable,
          RawIconSet,
          $$IconSetsTableFilterComposer,
          $$IconSetsTableOrderingComposer,
          $$IconSetsTableAnnotationComposer,
          $$IconSetsTableCreateCompanionBuilder,
          $$IconSetsTableUpdateCompanionBuilder,
          (RawIconSet, BaseReferences<_$Database, $IconSetsTable, RawIconSet>),
          RawIconSet,
          PrefetchHooks Function()
        > {
  $$IconSetsTableTableManager(_$Database db, $IconSetsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$IconSetsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$IconSetsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$IconSetsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<String> name = const Value.absent(),
                Value<String> url = const Value.absent(),
                Value<List<IconSetIcon>> icons = const Value.absent(),
                Value<DateTime?> lastUpdateTime = const Value.absent(),
                Value<int?> order = const Value.absent(),
              }) => IconSetsCompanion(
                id: id,
                name: name,
                url: url,
                icons: icons,
                lastUpdateTime: lastUpdateTime,
                order: order,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                required String name,
                required String url,
                required List<IconSetIcon> icons,
                Value<DateTime?> lastUpdateTime = const Value.absent(),
                Value<int?> order = const Value.absent(),
              }) => IconSetsCompanion.insert(
                id: id,
                name: name,
                url: url,
                icons: icons,
                lastUpdateTime: lastUpdateTime,
                order: order,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$IconSetsTable, RawIconSet>(table),
                  BaseReferences<_$Database, $IconSetsTable, RawIconSet>(
                    db,
                    table,
                    e,
                  ),
                ),
              )
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$IconSetsTableProcessedTableManager =
    ProcessedTableManager<
      _$Database,
      $IconSetsTable,
      RawIconSet,
      $$IconSetsTableFilterComposer,
      $$IconSetsTableOrderingComposer,
      $$IconSetsTableAnnotationComposer,
      $$IconSetsTableCreateCompanionBuilder,
      $$IconSetsTableUpdateCompanionBuilder,
      (RawIconSet, BaseReferences<_$Database, $IconSetsTable, RawIconSet>),
      RawIconSet,
      PrefetchHooks Function()
    >;
typedef $$ClashProvidersTableCreateCompanionBuilder =
    ClashProvidersCompanion Function({
      Value<int> id,
      required ProviderKind kind,
      required String label,
      required String url,
      Value<RuleProviderBehavior?> behavior,
      Value<RuleProviderFormat?> format,
      Value<int?> order,
    });
typedef $$ClashProvidersTableUpdateCompanionBuilder =
    ClashProvidersCompanion Function({
      Value<int> id,
      Value<ProviderKind> kind,
      Value<String> label,
      Value<String> url,
      Value<RuleProviderBehavior?> behavior,
      Value<RuleProviderFormat?> format,
      Value<int?> order,
    });

class $$ClashProvidersTableFilterComposer
    extends Composer<_$Database, $ClashProvidersTable> {
  $$ClashProvidersTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnWithTypeConverterFilters<ProviderKind, ProviderKind, String> get kind =>
      $composableBuilder(
        column: $table.kind,
        builder: (column) => ColumnWithTypeConverterFilters(column),
      );

  ColumnFilters<String> get label => $composableBuilder(
    column: $table.label,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get url => $composableBuilder(
    column: $table.url,
    builder: (column) => ColumnFilters(column),
  );

  ColumnWithTypeConverterFilters<
    RuleProviderBehavior?,
    RuleProviderBehavior,
    String
  >
  get behavior => $composableBuilder(
    column: $table.behavior,
    builder: (column) => ColumnWithTypeConverterFilters(column),
  );

  ColumnWithTypeConverterFilters<
    RuleProviderFormat?,
    RuleProviderFormat,
    String
  >
  get format => $composableBuilder(
    column: $table.format,
    builder: (column) => ColumnWithTypeConverterFilters(column),
  );

  ColumnFilters<int> get order => $composableBuilder(
    column: $table.order,
    builder: (column) => ColumnFilters(column),
  );
}

class $$ClashProvidersTableOrderingComposer
    extends Composer<_$Database, $ClashProvidersTable> {
  $$ClashProvidersTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get kind => $composableBuilder(
    column: $table.kind,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get label => $composableBuilder(
    column: $table.label,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get url => $composableBuilder(
    column: $table.url,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get behavior => $composableBuilder(
    column: $table.behavior,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get format => $composableBuilder(
    column: $table.format,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get order => $composableBuilder(
    column: $table.order,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$ClashProvidersTableAnnotationComposer
    extends Composer<_$Database, $ClashProvidersTable> {
  $$ClashProvidersTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumnWithTypeConverter<ProviderKind, String> get kind =>
      $composableBuilder(column: $table.kind, builder: (column) => column);

  GeneratedColumn<String> get label =>
      $composableBuilder(column: $table.label, builder: (column) => column);

  GeneratedColumn<String> get url =>
      $composableBuilder(column: $table.url, builder: (column) => column);

  GeneratedColumnWithTypeConverter<RuleProviderBehavior?, String>
  get behavior =>
      $composableBuilder(column: $table.behavior, builder: (column) => column);

  GeneratedColumnWithTypeConverter<RuleProviderFormat?, String> get format =>
      $composableBuilder(column: $table.format, builder: (column) => column);

  GeneratedColumn<int> get order =>
      $composableBuilder(column: $table.order, builder: (column) => column);
}

class $$ClashProvidersTableTableManager
    extends
        RootTableManager<
          _$Database,
          $ClashProvidersTable,
          RawClashProvider,
          $$ClashProvidersTableFilterComposer,
          $$ClashProvidersTableOrderingComposer,
          $$ClashProvidersTableAnnotationComposer,
          $$ClashProvidersTableCreateCompanionBuilder,
          $$ClashProvidersTableUpdateCompanionBuilder,
          (
            RawClashProvider,
            BaseReferences<_$Database, $ClashProvidersTable, RawClashProvider>,
          ),
          RawClashProvider,
          PrefetchHooks Function()
        > {
  $$ClashProvidersTableTableManager(_$Database db, $ClashProvidersTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$ClashProvidersTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$ClashProvidersTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$ClashProvidersTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<ProviderKind> kind = const Value.absent(),
                Value<String> label = const Value.absent(),
                Value<String> url = const Value.absent(),
                Value<RuleProviderBehavior?> behavior = const Value.absent(),
                Value<RuleProviderFormat?> format = const Value.absent(),
                Value<int?> order = const Value.absent(),
              }) => ClashProvidersCompanion(
                id: id,
                kind: kind,
                label: label,
                url: url,
                behavior: behavior,
                format: format,
                order: order,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                required ProviderKind kind,
                required String label,
                required String url,
                Value<RuleProviderBehavior?> behavior = const Value.absent(),
                Value<RuleProviderFormat?> format = const Value.absent(),
                Value<int?> order = const Value.absent(),
              }) => ClashProvidersCompanion.insert(
                id: id,
                kind: kind,
                label: label,
                url: url,
                behavior: behavior,
                format: format,
                order: order,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$ClashProvidersTable, RawClashProvider>(table),
                  BaseReferences<
                    _$Database,
                    $ClashProvidersTable,
                    RawClashProvider
                  >(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$ClashProvidersTableProcessedTableManager =
    ProcessedTableManager<
      _$Database,
      $ClashProvidersTable,
      RawClashProvider,
      $$ClashProvidersTableFilterComposer,
      $$ClashProvidersTableOrderingComposer,
      $$ClashProvidersTableAnnotationComposer,
      $$ClashProvidersTableCreateCompanionBuilder,
      $$ClashProvidersTableUpdateCompanionBuilder,
      (
        RawClashProvider,
        BaseReferences<_$Database, $ClashProvidersTable, RawClashProvider>,
      ),
      RawClashProvider,
      PrefetchHooks Function()
    >;

class $DatabaseManager {
  final _$Database _db;
  $DatabaseManager(this._db);
  $$ProfilesTableTableManager get profiles =>
      $$ProfilesTableTableManager(_db, _db.profiles);
  $$IconRecordsTableTableManager get iconRecords =>
      $$IconRecordsTableTableManager(_db, _db.iconRecords);
  $$IconSetsTableTableManager get iconSets =>
      $$IconSetsTableTableManager(_db, _db.iconSets);
  $$ClashProvidersTableTableManager get clashProviders =>
      $$ClashProvidersTableTableManager(_db, _db.clashProviders);
}

mixin _$ProfilesDaoMixin on DatabaseAccessor<Database> {
  $ProfilesTable get profiles => attachedDatabase.profiles;
  ProfilesDaoManager get managers => ProfilesDaoManager(this);
}

class ProfilesDaoManager {
  final _$ProfilesDaoMixin _db;
  ProfilesDaoManager(this._db);
  $$ProfilesTableTableManager get profiles =>
      $$ProfilesTableTableManager(_db.attachedDatabase, _db.profiles);
}

mixin _$IconRecordsDaoMixin on DatabaseAccessor<Database> {
  $IconRecordsTable get iconRecords => attachedDatabase.iconRecords;
  IconRecordsDaoManager get managers => IconRecordsDaoManager(this);
}

class IconRecordsDaoManager {
  final _$IconRecordsDaoMixin _db;
  IconRecordsDaoManager(this._db);
  $$IconRecordsTableTableManager get iconRecords =>
      $$IconRecordsTableTableManager(_db.attachedDatabase, _db.iconRecords);
}

mixin _$IconSetsDaoMixin on DatabaseAccessor<Database> {
  $IconSetsTable get iconSets => attachedDatabase.iconSets;
  IconSetsDaoManager get managers => IconSetsDaoManager(this);
}

class IconSetsDaoManager {
  final _$IconSetsDaoMixin _db;
  IconSetsDaoManager(this._db);
  $$IconSetsTableTableManager get iconSets =>
      $$IconSetsTableTableManager(_db.attachedDatabase, _db.iconSets);
}

mixin _$ClashProvidersDaoMixin on DatabaseAccessor<Database> {
  $ClashProvidersTable get clashProviders => attachedDatabase.clashProviders;
  ClashProvidersDaoManager get managers => ClashProvidersDaoManager(this);
}

class ClashProvidersDaoManager {
  final _$ClashProvidersDaoMixin _db;
  ClashProvidersDaoManager(this._db);
  $$ClashProvidersTableTableManager get clashProviders =>
      $$ClashProvidersTableTableManager(
        _db.attachedDatabase,
        _db.clashProviders,
      );
}
