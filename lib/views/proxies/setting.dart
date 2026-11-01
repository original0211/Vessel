import 'dart:math';

import 'package:kfusion/common/common.dart';
import 'package:kfusion/enum/enum.dart';
import 'package:kfusion/models/models.dart';
import 'package:kfusion/providers/config.dart';
import 'package:kfusion/widgets/widgets.dart';
import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class ProxiesSetting extends ConsumerWidget {
  const ProxiesSetting({super.key});

  static ConfigWriter<T> _writer<T>(
    ProxiesStyleProps Function(ProxiesStyleProps state, T value) update,
  ) {
    return (ref, value) => ref
        .read(proxiesStyleSettingProvider.notifier)
        .update((state) => update(state, value));
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final palette = context.haraPalette;
    final appLocalizations = context.appLocalizations;
    final sections = <Widget>[
      HaraSection(
        title: appLocalizations.proxySettings,
        rows: [
          const TestUrlItem(),
          HaraOptions<ProxiesSortType>(
            ConfigOptionsItem<ProxiesSortType>(
              title: (l) => l.sort,
              options: ProxiesSortType.values,
              textBuilder: (type) => switch (type) {
                ProxiesSortType.none => appLocalizations.defaultText,
                ProxiesSortType.delay => appLocalizations.delay,
                ProxiesSortType.name => appLocalizations.name,
              },
              selector: proxiesStyleSettingProvider.select(
                (state) => state.sortType,
              ),
              onChanged: _writer(
                (state, value) => state.copyWith(sortType: value),
              ),
            ),
          ),
        ],
      ),
      HaraSection(
        title: appLocalizations.filter,
        footer: appLocalizations.hideTimeoutProxiesDesc,
        rows: [
          HaraToggle(
            ConfigToggleItem(
              title: (l) => l.hideTimeoutProxies,
              selector: proxiesStyleSettingProvider.select(
                (state) => state.hideTimeoutProxies,
              ),
              onChanged: _writer(
                (state, value) => state.copyWith(hideTimeoutProxies: value),
              ),
            ),
          ),
        ],
      ),
    ];
    return Material(
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
              for (var i = 0; i < sections.length; i++) ...[
                if (i > 0) const SizedBox(height: HaraSpace.groupGap),
                sections[i],
              ],
            ],
          );
        },
      ),
    );
  }
}

class TestUrlItem extends ConsumerWidget {
  const TestUrlItem({super.key});

  @override
  Widget build(BuildContext context, ref) {
    final appLocalizations = context.appLocalizations;
    final testUrl = ref.watch(
      appSettingProvider.select((state) => state.testUrl),
    );
    return HaraInputRow(
      label: appLocalizations.testUrl,
      value: testUrl,
      note: appLocalizations.testUrlApplyNote,
      onTap: () {
        showConfigInputDialog(
          context: context,
          title: appLocalizations.testUrl,
          value: testUrl,
          resetValue: defaultTestUrl,
          maxLength: TextInputLimits.url,
          validator: (String? value) {
            if (value == null || value.isEmpty) {
              return appLocalizations.emptyTip(appLocalizations.testUrl);
            }
            if (!value.isUrl) {
              return appLocalizations.urlTip(appLocalizations.testUrl);
            }
            return null;
          },
          onChanged: (String? value) {
            if (value == null) {
              return;
            }
            ref
                .read(appSettingProvider.notifier)
                .update((state) => state.copyWith(testUrl: value));
          },
        );
      },
    );
  }
}
