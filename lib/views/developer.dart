import 'dart:math';

import 'package:kfusion/common/common.dart';
import 'package:kfusion/providers/action.dart';
import 'package:kfusion/widgets/widgets.dart';
import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class DeveloperView extends ConsumerWidget {
  const DeveloperView({super.key});

  List<Widget> _getDeveloperRows(BuildContext context, WidgetRef ref) {
    final appLocalizations = context.appLocalizations;
    return [
      HaraRow(
        onTap: () async {
          final storeAction = ref.read(storeActionProvider.notifier);
          final res = await dialogs.showMessage(
            message: TextSpan(text: appLocalizations.confirmClearAllData),
            destructive: true,
            confirmText: appLocalizations.clearData,
          );
          if (res != true) {
            return;
          }
          await storeAction.handleClear();
        },
        child: Text(
          appLocalizations.clearData,
          style: HaraText.nodeName(
            context,
            context.haraPalette.ink,
            current: false,
          ),
        ),
      ),
      HaraRow(
        onTap: () async {
          await ref.read(storeActionProvider.notifier).shakingStore();
        },
        child: Text(
          appLocalizations.pruneCache,
          style: HaraText.nodeName(
            context,
            context.haraPalette.ink,
            current: false,
          ),
        ),
      ),
    ];
  }

  @override
  Widget build(BuildContext context, ref) {
    final palette = context.haraPalette;
    final appLocalizations = context.appLocalizations;
    return BaseScaffold(
      title: appLocalizations.developerMode,
      body: Material(
        color: palette.bg,
        child: LayoutBuilder(
          builder: (context, constraints) {
            final side = max(
              HaraSpace.pageInset,
              (constraints.maxWidth - HaraSpace.contentMaxWidth) / 2,
            );
            return ListView(
              padding: EdgeInsets.fromLTRB(side, context.appBarInset, side, 48),
              children: [
                HaraSection(
                  title: appLocalizations.options,
                  rows: _getDeveloperRows(context, ref),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}
