import 'package:drift/drift.dart';
import 'package:kfusion/database/database.dart';
import 'package:kfusion/enum/enum.dart';
import 'package:kfusion/models/models.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('profile generated data classes preserve all fields', () {
    final date = DateTime.utc(2026, 7, 26);
    final profile = RawProfile(
      id: 1,
      type: ProfileType.url,
      label: 'Profile',
      currentGroupName: 'Select',
      url: 'https://example.com/profile.yaml',
      ageSecretKey: 'AGE-SECRET-KEY-1',
      lastUpdateDate: date,
      autoUpdateDurationMillis: 3600000,
      subscriptionInfo: const SubscriptionInfo(
        upload: 1,
        download: 2,
        total: 3,
        expire: 4,
      ),
      autoUpdate: true,
      selectedMap: const {'Select': 'DIRECT'},
      unfoldSet: const {'Select'},
      order: 3,
    );

    expect(profile.toColumns(true), hasLength(13));
    expect(profile.toCompanion(true).toColumns(true), hasLength(13));
    expect(RawProfile.fromJson(profile.toJson()).toJson(), profile.toJson());
    expect(profile.copyWith(label: 'Next').label, 'Next');
    expect(
      profile
          .copyWithCompanion(
            const ProfilesCompanion(
              currentGroupName: Value(null),
              order: Value(9),
            ),
          )
          .order,
      9,
    );
    expect(profile.copyWith(), profile);
    expect(profile.hashCode, isNonZero);
    expect(profile.toString(), contains('Profile'));

    const emptyProfile = RawProfile(
      id: 2,
      type: ProfileType.custom,
      label: 'Empty',
      url: '',
      autoUpdateDurationMillis: 0,
      autoUpdate: false,
      selectedMap: {},
      unfoldSet: {},
    );
    expect(emptyProfile.toColumns(true), hasLength(8));
    expect(emptyProfile.toColumns(false), hasLength(13));
    expect(emptyProfile.toCompanion(true).toColumns(true), hasLength(8));

    final insertedProfile = ProfilesCompanion.insert(
      type: ProfileType.file,
      label: 'Inserted',
      url: 'url',
      autoUpdateDurationMillis: 60,
      autoUpdate: true,
      selectedMap: const {},
      unfoldSet: const {},
    ).copyWith(id: const Value(8), order: const Value(1));
    expect(insertedProfile.toColumns(true), hasLength(9));
    expect(insertedProfile.toString(), contains('Inserted'));
    expect(
      ProfilesCompanion.custom(
        id: const Variable(1),
        type: const Variable('custom'),
        label: const Variable('custom'),
        currentGroupName: const Variable('group'),
        url: const Variable('url'),
        ageSecretKey: const Variable('AGE-SECRET-KEY-1'),
        lastUpdateDate: Variable(date),
        autoUpdateDurationMillis: const Variable(60),
        subscriptionInfo: const Variable('{}'),
        autoUpdate: const Variable(true),
        selectedMap: const Variable('{}'),
        unfoldSet: const Variable('[]'),
        order: const Variable(1),
      ).toColumns(false),
      hasLength(13),
    );
  });

  test('icon generated classes preserve every field', () {
    const icon = IconRecord(
      url: 'https://example.com/icon.png',
      lastAccessed: 1,
    );
    expect(icon.toColumns(true), hasLength(2));
    expect(icon.toCompanion(true).toColumns(true), hasLength(2));
    expect(IconRecord.fromJson(icon.toJson()), icon);
    expect(icon.copyWith(lastAccessed: 2).lastAccessed, 2);
    expect(
      icon
          .copyWithCompanion(const IconRecordsCompanion(lastAccessed: Value(3)))
          .lastAccessed,
      3,
    );
    expect(icon.toString(), contains('icon.png'));
    expect(icon.hashCode, isNonZero);

    final iconCompanion = IconRecordsCompanion.insert(
      url: 'url',
      lastAccessed: 4,
    ).copyWith(rowid: const Value(1));
    expect(iconCompanion.toColumns(true), hasLength(3));
    expect(iconCompanion.toString(), contains('url'));
    expect(
      IconRecordsCompanion.custom(
        url: const Variable('url'),
        lastAccessed: const Variable(1),
        rowid: const Variable(2),
      ).toColumns(false),
      hasLength(3),
    );
  });
}
