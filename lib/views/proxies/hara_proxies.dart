import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kfusion/common/common.dart';
import 'package:kfusion/enum/enum.dart';
import 'package:kfusion/features/config_hub/singbox_action.dart';
import 'package:kfusion/models/models.dart';
import 'package:kfusion/providers/providers.dart';
import 'package:kfusion/ui/icons/icons.dart';
import 'package:kfusion/ui/ui.dart';
import 'package:kfusion/views/proxies/card.dart';
import 'package:material_ui/material_ui.dart';

/// The main screen labels the exit leaf while connected (the status row owns the dot then); the proxies page always dots it.
enum HaraExitMarker { dot, label }

class HaraProxyGroupSection extends ConsumerWidget {
  const HaraProxyGroupSection({
    super.key,
    required this.group,
    required this.exitName,
    required this.first,
    required this.exitMarker,
    this.expanded = true,
    this.onToggleFold,
    this.pinExit = false,
    this.headerCount,
  });

  final Group group;
  final String? exitName;
  final bool first;
  final HaraExitMarker exitMarker;

  /// Whether the member rows are shown. A collapsed section renders only
  /// its header, which then carries the group's current pick, member
  /// count and best delay so the group stays readable while folded.
  final bool expanded;

  /// Toggles [expanded]; when null the header is not a fold control.
  final VoidCallback? onToggleFold;

  /// Renders the exit member first in its group, ahead of the configured
  /// order. Only the plain order reading passes this; a delay-sorted
  /// presentation keeps its own order.
  final bool pinExit;

  /// A count rendered in the expanded header, used by the search reading
  /// to carry the group's hit count.
  final int? headerCount;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final palette = context.haraPalette;
    // Reconciliation runs only against a live panel table: without a
    // sing-box bearer, and before the first successful fetch lands, the
    // section keeps its legacy presentation.
    final panelAsync = ref.watch(singBoxPanelGroupsProvider);
    final bearing =
        ref.watch(singBoxActionProvider).value?.state == SingBoxState.running &&
        ref.read(singBoxActionProvider.notifier).api != null;
    final table = bearing ? panelAsync.value : null;
    final panel = table ?? const <String, SingBoxPanelGroup>{};
    final panelGroup = panel[group.name];
    final absent = table != null && panelGroup == null;
    final panelType = panelGroup?.type;
    final indicator =
        panelType != null && panelType != 'Selector' && panelType != 'URLTest';
    final indicatorNow = indicator ? panelGroup?.now ?? '' : '';
    final autoChild = panelGroup == null
        ? null
        : singBoxPanelAutoChild(panel, group.name);
    final nativeAuto = panelGroup?.type == 'URLTest';
    final saved = ref.watch(proxyNameProvider(group.name));
    final childNow = autoChild == null ? '' : panel[autoChild]?.now ?? '';
    final autoMarked =
        autoChild != null &&
        saved == autoChild &&
        exitName != null &&
        (exitName == autoChild || exitName == childNow);
    var members = group.all;
    if (expanded && pinExit && exitName != null) {
      final exitIndex = members.indexWhere((proxy) => proxy.name == exitName);
      if (exitIndex > 0) {
        members = [
          members[exitIndex],
          ...members.sublist(0, exitIndex),
          ...members.sublist(exitIndex + 1),
        ];
      }
    }
    return SliverMainAxisGroup(
      slivers: [
        SliverToBoxAdapter(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              SizedBox(
                height: first
                    ? HaraSpace.titleToFirstGroup
                    : HaraSpace.groupGap,
              ),
              _header(
                context,
                ref,
                palette,
                nativeAuto: nativeAuto,
                absent: absent,
                indicator: indicator,
                indicatorNow: indicatorNow,
                autoChild: autoChild,
                childNow: childNow,
              ),
              const SizedBox(height: HaraSpace.sectionTitleGap),
              HaraHairline(color: palette.line),
            ],
          ),
        ),
        if (expanded)
          SliverList.builder(
            itemCount: members.length + (autoChild != null ? 1 : 0),
            itemBuilder: (context, index) {
              if (autoChild != null && index == 0) {
                return _HaraAutoRow(
                  group: group,
                  childTag: autoChild,
                  childNow: childNow,
                  isExit: exitName == autoChild || exitName == childNow,
                  exitMarker: exitMarker,
                );
              }
              final proxy = members[autoChild != null ? index - 1 : index];
              return _HaraProxyRow(
                group: group,
                proxy: proxy,
                isExit: indicator
                    ? proxy.name == indicatorNow
                    : !absent && proxy.name == exitName && !autoMarked,
                exitMarker: exitMarker,
                locked: nativeAuto || absent || indicator,
                forceSelected: indicator
                    ? proxy.name == indicatorNow
                    : nativeAuto && proxy.name == panelGroup?.now,
              );
            },
          ),
      ],
    );
  }

  Widget _header(
    BuildContext context,
    WidgetRef ref,
    HaraPalette palette, {
    required bool nativeAuto,
    required bool absent,
    required bool indicator,
    required String indicatorNow,
    required String? autoChild,
    required String childNow,
  }) {
    final name = Flexible(
      child: EmojiText(
        group.name,
        style: HaraText.sectionTitle(context, palette.dim),
        maxLines: 1,
      ),
    );
    final List<Widget> middle;
    if (!expanded) {
      middle = _foldedMeta(
        context,
        ref,
        palette,
        nativeAuto: nativeAuto,
        absent: absent,
        indicator: indicator,
        indicatorNow: indicatorNow,
        autoChild: autoChild,
        childNow: childNow,
      );
    } else if (nativeAuto) {
      middle = [
        const SizedBox(width: HaraSpace.dotNameGap),
        Text(
          context.appLocalizations.auto,
          style: HaraText.inUse(context, palette.dim),
        ),
      ];
    } else if (absent) {
      middle = [
        const SizedBox(width: HaraSpace.dotNameGap),
        Text(
          context.appLocalizations.unavailableUnderSingBox,
          style: HaraText.inUse(context, palette.dim),
        ),
      ];
    } else if (indicator) {
      middle = [
        if (indicatorNow.isNotEmpty) ...[
          const SizedBox(width: HaraSpace.dotNameGap),
          Flexible(
            child: EmojiText(
              '→ $indicatorNow',
              style: HaraText.statusNode(context, palette.sub),
              maxLines: 1,
            ),
          ),
        ],
      ];
    } else {
      middle = const [];
    }
    final row = Row(
      children: [
        name,
        ...middle,
        if (expanded && headerCount != null) ...[
          const Spacer(),
          Text('$headerCount', style: HaraText.inUse(context, palette.dim)),
        ],
        if (onToggleFold != null) ...[
          const SizedBox(width: HaraSpace.dotNameGap),
          GlyphIcon(
            expanded ? AppGlyphs.chevronUp : AppGlyphs.chevronDown,
            size: 18,
            color: palette.dim,
          ),
        ],
      ],
    );
    if (onToggleFold == null) return row;
    return InkWell(
      customBorder: AppShape.hara,
      onTap: onToggleFold,
      child: row,
    );
  }

  /// The folded header's reading: the group's current pick resolved to
  /// its exit leaf, the member count, and the best delay on record. An
  /// absent or indicator group keeps the mark its expanded header has.
  List<Widget> _foldedMeta(
    BuildContext context,
    WidgetRef ref,
    HaraPalette palette, {
    required bool nativeAuto,
    required bool absent,
    required bool indicator,
    required String indicatorNow,
    required String? autoChild,
    required String childNow,
  }) {
    if (absent) {
      return [
        const SizedBox(width: HaraSpace.dotNameGap),
        Text(
          context.appLocalizations.unavailableUnderSingBox,
          style: HaraText.inUse(context, palette.dim),
        ),
      ];
    }
    if (indicator) {
      return [
        if (indicatorNow.isNotEmpty) ...[
          const SizedBox(width: HaraSpace.dotNameGap),
          Flexible(
            child: EmojiText(
              '→ $indicatorNow',
              style: HaraText.statusNode(context, palette.sub),
              maxLines: 1,
            ),
          ),
        ],
      ];
    }
    String? pick;
    if (nativeAuto) {
      final now = ref.watch(singBoxPanelGroupsProvider).value?[group.name]?.now;
      pick = (now == null || now.isEmpty) ? group.now : now;
    } else {
      final selected = ref.watch(selectedProxyNameProvider(group.name));
      if (selected != null && selected.isNotEmpty) {
        final resolved = ref
            .watch(realSelectedProxyStateProvider(selected))
            .proxyName;
        pick = resolved.isEmpty ? selected : resolved;
      }
    }
    int? best;
    for (final proxy in group.all) {
      final delay = ref.watch(
        delayProvider(proxyName: proxy.name, testUrl: group.testUrl),
      );
      if (delay != null && delay > 0 && (best == null || delay < best)) {
        best = delay;
      }
    }
    if (autoChild != null && childNow.isNotEmpty) {
      final delay = ref.watch(
        delayProvider(proxyName: childNow, testUrl: group.testUrl),
      );
      if (delay != null && delay > 0 && (best == null || delay < best)) {
        best = delay;
      }
    }
    return [
      if (pick != null && pick.isNotEmpty) ...[
        const SizedBox(width: HaraSpace.dotNameGap),
        Flexible(
          child: EmojiText(
            '→ $pick',
            style: HaraText.statusNode(context, palette.sub),
            maxLines: 1,
          ),
        ),
      ],
      const Spacer(),
      Text('${group.all.length}', style: HaraText.inUse(context, palette.dim)),
      if (best != null) ...[
        const SizedBox(width: 16),
        Text.rich(
          TextSpan(
            children: [
              TextSpan(
                text: '$best',
                style: HaraText.delay(context, palette.sub),
              ),
              TextSpan(
                text: ' ms',
                style: HaraText.delayUnit(context, palette.sub),
              ),
            ],
          ),
        ),
      ],
    ];
  }
}

class _HaraAutoRow extends ConsumerWidget {
  const _HaraAutoRow({
    required this.group,
    required this.childTag,
    required this.childNow,
    required this.isExit,
    required this.exitMarker,
  });

  final Group group;
  final String childTag;
  final String childNow;
  final bool isExit;
  final HaraExitMarker exitMarker;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final palette = context.haraPalette;
    final selected = ref.watch(
      proxyNameProvider(group.name).select((name) => name == childTag),
    );
    final marked = isExit && selected;
    return InkWell(
      customBorder: AppShape.hara,
      onTap: () => ref
          .read(proxiesActionProvider.notifier)
          .changeProxyDebounce(group.name, childTag),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(
              vertical: HaraSpace.nodeRowVertical,
            ),
            child: Row(
              children: [
                if (marked && exitMarker == HaraExitMarker.dot) ...[
                  const HaraDot(size: HaraSpace.dotRow),
                  const SizedBox(width: HaraSpace.dotNameGap),
                ],
                Expanded(
                  child: Text(
                    context.appLocalizations.auto,
                    style: HaraText.nodeName(
                      context,
                      palette.ink,
                      current: selected,
                    ),
                    maxLines: 1,
                  ),
                ),
                if (marked && exitMarker == HaraExitMarker.label) ...[
                  Text(
                    context.appLocalizations.currentExit,
                    style: HaraText.inUse(context, palette.dim),
                  ),
                  const SizedBox(width: 16),
                ],
                if (childNow.isNotEmpty)
                  _HaraDelay(
                    group: group,
                    proxy: Proxy(name: childNow, type: 'URLTest'),
                  )
                else
                  Text('—', style: HaraText.untested(context, palette.dim)),
              ],
            ),
          ),
          HaraHairline(color: palette.line),
        ],
      ),
    );
  }
}

class _HaraProxyRow extends ConsumerWidget {
  const _HaraProxyRow({
    required this.group,
    required this.proxy,
    required this.isExit,
    required this.exitMarker,
    this.locked = false,
    this.forceSelected = false,
  });

  final Group group;
  final Proxy proxy;
  final bool isExit;
  final HaraExitMarker exitMarker;
  final bool locked;
  final bool forceSelected;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final palette = context.haraPalette;
    final selected =
        forceSelected ||
        ref.watch(
          selectedProxyNameProvider(
            group.name,
          ).select((name) => name == proxy.name),
        );
    final isGroup = GroupType.values.any((type) => type.name == proxy.type);
    final marked = isExit && selected;
    return InkWell(
      customBorder: AppShape.hara,
      onTap: locked
          ? null
          : () => selectGroupProxy(
              ref,
              groupName: group.name,
              groupType: group.type,
              proxyName: proxy.name,
            ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(
              vertical: HaraSpace.nodeRowVertical,
            ),
            child: Row(
              children: [
                if (marked && exitMarker == HaraExitMarker.dot) ...[
                  const HaraDot(size: HaraSpace.dotRow),
                  const SizedBox(width: HaraSpace.dotNameGap),
                ],
                Expanded(
                  child: EmojiText(
                    proxy.name,
                    style: HaraText.nodeName(
                      context,
                      palette.ink,
                      current: selected,
                    ),
                    maxLines: 1,
                  ),
                ),
                if (marked && exitMarker == HaraExitMarker.label) ...[
                  Text(
                    context.appLocalizations.currentExit,
                    style: HaraText.inUse(context, palette.dim),
                  ),
                  const SizedBox(width: 16),
                ],
                if (isGroup)
                  _HaraRealSelected(group: group, proxy: proxy)
                else
                  _HaraDelay(group: group, proxy: proxy),
              ],
            ),
          ),
          HaraHairline(color: palette.line),
        ],
      ),
    );
  }
}

class _HaraRealSelected extends ConsumerWidget {
  const _HaraRealSelected({required this.group, required this.proxy});

  final Group group;
  final Proxy proxy;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final palette = context.haraPalette;
    final real = ref.watch(realSelectedProxyStateProvider(proxy.name));
    if (real.proxyName.isEmpty || real.proxyName == proxy.name) {
      return const SizedBox.shrink();
    }

    return Flexible(
      child: EmojiText(
        '→ ${real.proxyName}',
        style: HaraText.statusNode(context, palette.sub),
        maxLines: 1,
      ),
    );
  }
}

class _HaraDelay extends ConsumerWidget {
  const _HaraDelay({required this.group, required this.proxy});

  final Group group;
  final Proxy proxy;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final palette = context.haraPalette;
    final delay = ref.watch(
      delayProvider(proxyName: proxy.name, testUrl: group.testUrl),
    );
    // Watched so the slot rebuilds when a test starts and lands.
    ref.watch(
      delayTestPhaseProvider(proxyName: proxy.name, testUrl: group.testUrl),
    );
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => ref
          .read(proxiesActionProvider.notifier)
          .proxyDelayTest(proxy, group.testUrl),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
        child: _content(context, palette, delay),
      ),
    );
  }

  Widget _content(BuildContext context, HaraPalette palette, int? delay) {
    if (delay == null) {
      return Text('—', style: HaraText.untested(context, palette.dim));
    }
    if (delay <= 0) {
      return Text(
        delayFailureText(delay, context.appLocalizations),
        style: HaraText.delay(context, palette.sub),
      );
    }
    return Text.rich(
      TextSpan(
        children: [
          TextSpan(text: '$delay', style: HaraText.delay(context, palette.sub)),
          TextSpan(
            text: ' ms',
            style: HaraText.delayUnit(context, palette.sub),
          ),
        ],
      ),
    );
  }
}
