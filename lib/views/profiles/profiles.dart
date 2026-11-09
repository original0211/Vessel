import 'dart:async';

import 'package:kfusion/common/common.dart';
import 'package:kfusion/enum/enum.dart';
import 'package:kfusion/models/models.dart';
import 'package:kfusion/providers/providers.dart';
import 'package:kfusion/state.dart';
import 'package:kfusion/ui/icons/icons.dart';
import 'package:kfusion/widgets/widgets.dart';
import 'package:material_ui/material_ui.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'edit.dart';
import 'preview.dart';

/// Updates every url profile in [profiles] and returns the failures, the
/// same run the profiles pages' update action performs.
Future<List<UpdatingMessage>> updateUrlProfiles(
  BuildContext context,
  WidgetRef ref,
  List<Profile> profiles,
) async {
  final appLocalizations = context.appLocalizations;
  final profilesAction = ref.read(profilesActionProvider.notifier);
  final List<UpdatingMessage> messages = [];
  final updates = profiles.map<Future>((profile) async {
    if (profile.type != ProfileType.url) return;
    try {
      await profilesAction.updateProfile(profile, showLoading: true);
    } catch (e) {
      messages.add(
        UpdatingMessage(
          label: profile.realLabel,
          message: userFacingErrorMessage(e, appLocalizations),
        ),
      );
    }
  });
  await Future.wait(updates);
  return messages;
}

/// The profile row actions for the Hara A profiles list.
Future<void> confirmDeleteProfile(
  BuildContext context,
  WidgetRef ref,
  Profile profile,
) async {
  final profilesAction = ref.read(profilesActionProvider.notifier);
  final appLocalizations = context.appLocalizations;
  final res = await dialogs.showMessage(
    title: appLocalizations.tip,
    message: TextSpan(
      text: appLocalizations.deleteTip(appLocalizations.profile),
    ),
    destructive: true,
    confirmText: appLocalizations.delete,
  );
  if (res != true) {
    return;
  }
  await profilesAction.deleteProfile(profile.id);
}

void previewProfile(BuildContext context, Profile profile) {
  unawaited(
    BaseNavigator.push<String>(context, PreviewProfileView(profile: profile)),
  );
}

Future<void> syncProfile(WidgetRef ref, Profile profile) async {
  if (profile.type != ProfileType.url) return;
  await globalState.loadingRun(() async {
    await ref
        .read(profilesActionProvider.notifier)
        .updateProfile(profile, showLoading: true);
  }, tag: LoadingTag.profiles);
}

void editProfileEntry(BuildContext context, Profile profile) {
  showExtend(context, builder: (context) => EditProfileView(profile: profile));
}

Future<void> copyProfileLink(BuildContext context, Profile profile) async {
  await Clipboard.setData(ClipboardData(text: profile.url));
  if (context.mounted) {
    context.showNotifier(
      context.appLocalizations.copySuccess,
      level: MessageLevel.success,
    );
  }
}

Future<void> exportProfileFile(BuildContext context, Profile profile) async {
  final appLocalizations = context.appLocalizations;
  final res = await globalState.safeRun<bool>(() async {
    final mFile = await profile.file;
    final value = await picker.saveFile(
      profile.exportFileName,
      mFile.readAsBytesSync(),
    );
    if (value == null) return false;
    return true;
  }, title: appLocalizations.tip);
  if (res == true && context.mounted) {
    context.showNotifier(
      appLocalizations.exportSuccess,
      level: MessageLevel.success,
    );
  }
}

List<CommonPopupMenuItem> profileMenuItems(
  BuildContext context,
  WidgetRef ref,
  Profile profile,
) {
  final appLocalizations = context.appLocalizations;
  final isUrl = profile.type == ProfileType.url;
  final isCustom = profile.type == ProfileType.custom;
  return [
    if (!isCustom)
      CommonPopupMenuItem(
        glyph: AppGlyphs.edit,
        label: appLocalizations.edit,
        onPressed: () => editProfileEntry(context, profile),
      ),
    if (isCustom) ...[
      CommonPopupMenuItem(
        glyph: AppGlyphs.textShort,
        label: appLocalizations.rename,
        onPressed: () {
          renameProfile(context, ref, profile);
        },
      ),
      CommonPopupMenuItem(
        glyph: AppGlyphs.eye,
        label: appLocalizations.runtimeConfig,
        onPressed: () {
          previewProfile(context, profile);
        },
      ),
    ],
    if (isUrl)
      CommonPopupMenuItem(
        glyph: AppGlyphs.sync,
        label: appLocalizations.sync,
        onPressed: () {
          syncProfile(ref, profile);
        },
      ),
    if (!isCustom) ...[
      CommonPopupMenuItem(
        glyph: AppGlyphs.eye,
        label: appLocalizations.runtimeConfig,
        onPressed: () {
          previewProfile(context, profile);
        },
      ),
      CommonPopupMenuItem(
        glyph: AppGlyphs.moreCircle,
        label: appLocalizations.more,
        subItems: [
          if (isUrl)
            CommonPopupMenuItem(
              glyph: AppGlyphs.copy,
              label: appLocalizations.copyLink,
              onPressed: () {
                copyProfileLink(context, profile);
              },
            ),
          CommonPopupMenuItem(
            glyph: AppGlyphs.export,
            label: appLocalizations.exportFile,
            onPressed: () {
              exportProfileFile(context, profile);
            },
          ),
        ],
      ),
    ],
    CommonPopupMenuItem(
      danger: true,
      glyph: AppGlyphs.delete,
      label: appLocalizations.delete,
      onPressed: () {
        confirmDeleteProfile(context, ref, profile);
      },
    ),
  ];
}

class ReorderableProfilesSheet extends ConsumerStatefulWidget {
  final List<Profile> profiles;

  const ReorderableProfilesSheet({super.key, required this.profiles});

  @override
  ConsumerState<ReorderableProfilesSheet> createState() =>
      _ReorderableProfilesSheetState();
}

class _ReorderableProfilesSheetState
    extends ConsumerState<ReorderableProfilesSheet> {
  late List<Profile> profiles;

  @override
  void initState() {
    super.initState();
    profiles = List.from(widget.profiles);
  }

  Widget _buildItem(int index) {
    final position = ItemPosition.get(index, profiles.length);
    final profile = profiles[index];
    return ItemPositionProvider(
      key: Key(profile.id.toString()),
      position: position,
      child: DecorationListItem(
        contentPadding: const EdgeInsets.only(left: 16),
        trailing: SortHandle(index: index),
        title: Text(profile.realLabel),
      ),
    );
  }

  void _handleSave() {
    Navigator.of(context).pop();
    final latest = ref.read(profilesProvider);
    final ids = {for (final profile in profiles) profile.id};
    ref.read(profilesProvider.notifier).reorder([
      for (final profile in profiles) ?latest.getProfile(profile.id),
      for (final profile in latest)
        if (!ids.contains(profile.id)) profile,
    ]);
  }

  @override
  Widget build(BuildContext context) {
    final appLocalizations = context.appLocalizations;
    return CommonScaffold(
      confirmationAction: IconButtonData(
        glyph: AppGlyphs.check,
        onPressed: _handleSave,
        tooltip: appLocalizations.save,
      ),
      body: Padding(
        padding: const EdgeInsets.only(bottom: 32),
        child: ReorderableListView.builder(
          buildDefaultDragHandles: false,
          padding: const EdgeInsets.symmetric(
            horizontal: 16,
          ).copyWith(top: context.contentTopPadding),
          proxyDecorator: (child, index, animation) {
            return commonProxyDecorator(_buildItem(index), index, animation);
          },
          onReorderItem: (oldIndex, newIndex) {
            setState(() {
              profiles = profiles.copyAndReorder(oldIndex, newIndex);
            });
          },
          itemBuilder: (_, index) {
            return _buildItem(index);
          },
          itemCount: profiles.length,
        ),
      ),
      title: appLocalizations.profilesSort,
    );
  }
}
