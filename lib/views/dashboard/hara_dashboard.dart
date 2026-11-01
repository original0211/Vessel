import 'dart:async';
import 'dart:math' as math;

import 'package:kfusion/common/common.dart';
import 'package:kfusion/common/service_probe.dart';
import 'package:kfusion/core/core.dart';
import 'package:kfusion/enum/enum.dart';
import 'package:kfusion/features/config_hub/core_kind.dart';
import 'package:kfusion/features/config_hub/singbox_action.dart';
import 'package:kfusion/features/ip_quality/labels.dart';
import 'package:kfusion/models/models.dart';
import 'package:kfusion/providers/ip_quality.dart';
import 'package:kfusion/providers/outbound_ip.dart';
import 'package:kfusion/providers/providers.dart';
import 'package:kfusion/providers/routed_probe.dart';
import 'package:kfusion/ui/icons/icons.dart';
import 'package:kfusion/ui/ui.dart';
import 'package:kfusion/views/profiles/universal_import.dart';
import 'package:kfusion/views/proxies/hara_proxies.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import 'probe_start_hold.dart';
import 'widgets/core_status_button.dart';

const _pendingBudget = Duration(seconds: 45);
const _stickyExtent = 48.0;
const _chipRailExtent = 40.0;

String _coreName(CoreKind kind) {
  return switch (kind) {
    CoreKind.mihomo => 'mihomo',
    CoreKind.singbox => 'sing-box',
  };
}

/// The main screen in the Hara A reading: the ring, status row, figures
/// and mode row over the proxies reading's grouped node list, on one
/// scroll surface. The ring stops whichever core is running.
class HaraDashboard extends ConsumerStatefulWidget {
  const HaraDashboard({super.key});

  @override
  ConsumerState<HaraDashboard> createState() => _HaraDashboardState();
}

enum _Phase {
  noProfile,
  disconnected,
  connecting,
  connected,
  disconnecting,
  suspended,
  error,
}

class _HaraDashboardState extends ConsumerState<HaraDashboard>
    with ProbeStartHold<HaraDashboard> {
  late final OutboundIpProbe _probe;
  bool? _pending;
  bool _sortByDelay = false;
  Timer? _pendingTimer;
  late final ScrollController _scrollController;
  final _sticky = ValueNotifier<({bool status, bool chips})>((
    status: false,
    chips: false,
  ));
  final _heroKey = GlobalKey();
  double? _heroExtent;
  final _searchController = TextEditingController();
  final _railKey = GlobalKey();
  double? _railOffset;
  double? _railExtent;
  final _sectionKeys = <String, GlobalKey>{};
  Map<String, bool> _foldToggles = {};
  int? _foldSeededProfileId;
  bool _pinAllowedCache = false;
  double _safeTopCache = 0;
  String? _exitGroupCache;
  List<Group> _groupsCache = const [];
  bool _searchingCache = false;

  @override
  void initState() {
    super.initState();
    _scrollController = sheetScrollController(context);
    _probe = ref.read(outboundIpProbeProvider.notifier)..watch(routedOutbound);
    ref.listenManual(isStartProvider, (previous, next) {
      if (!mounted) return;
      if (previous != next && _pending == next) {
        setState(() {
          _pending = null;
          _pendingTimer?.cancel();
        });
      }
    });
    // The post-test delay order is handed back when its profile or the sort setting changes.
    ref.listenManual(currentProfileIdProvider, (previous, next) {
      if (mounted && previous != next && _sortByDelay) {
        setState(() => _sortByDelay = false);
      }
      if (previous != next) {
        _foldSeededProfileId = null;
        _foldToggles = {};
      }
    });
    ref.listenManual(
      proxiesStyleSettingProvider.select((state) => state.sortType),
      (previous, next) {
        if (mounted && previous != next && _sortByDelay) {
          setState(() => _sortByDelay = false);
        }
      },
    );
    _scrollController.addListener(_updateSticky);
  }

  @override
  void dispose() {
    _pendingTimer?.cancel();
    _probe.unwatch(routedOutbound);
    _scrollController.dispose();
    _sticky.dispose();
    _searchController.dispose();
    super.dispose();
  }

  void _toggle() {
    setState(() => _pending = !ref.read(isStartProvider));
    _pendingTimer?.cancel();
    _pendingTimer = Timer(_pendingBudget, () {
      if (mounted) setState(() => _pending = null);
    });
    ref.read(commonActionProvider.notifier).toggleRunning();
  }

  void _toggleSingBox() {
    ref.read(singBoxActionProvider.notifier).stop();
  }

  Future<void> _testAll() async {
    final groups = ref.read(proxiesListStateProvider).groups;
    final action = ref.read(proxiesActionProvider.notifier);
    await Future.wait([
      for (final group in groups) action.delayTestPageGroup(group.name),
    ]);
    if (mounted) {
      setState(() => _sortByDelay = true);
    }
  }

  void _updateSticky() {
    if (!_scrollController.hasClients) return;
    final offset = _scrollController.offset;
    final extent = _heroExtent;
    final status = extent != null && offset >= extent - _stickyExtent;
    var chips = false;
    final rail = _railOffset;
    if (rail != null) {
      // The chip rail takes over exactly where its in-flow copy slides
      // under the status row, so the inset counts the status row only
      // when that row is actually on screen.
      final inset = status && _pinAllowedCache
          ? _safeTopCache + _stickyExtent
          : 0.0;
      chips = offset >= rail - inset;
    }
    final next = (status: status, chips: chips);
    if (next != _sticky.value) _sticky.value = next;
  }

  bool _expandedFor(String groupName) {
    if (_searchingCache) return true;
    return _foldToggles[groupName] ?? (groupName == _exitGroupCache);
  }

  void _setFold(String groupName, bool expanded) {
    setState(() => _foldToggles[groupName] = expanded);
    final effective = <String>{
      for (final group in _groupsCache)
        if (_foldToggles[group.name] ?? (group.name == _exitGroupCache))
          group.name,
    };
    ref.read(proxiesActionProvider.notifier).updateCurrentUnfoldSet(effective);
  }

  GlobalKey _sectionKeyFor(String groupName) {
    return _sectionKeys.putIfAbsent(groupName, () => GlobalKey());
  }

  double? _contentOffsetOf(GlobalKey key) {
    final box = key.currentContext?.findRenderObject() as RenderBox?;
    if (box == null || !box.hasSize || !_scrollController.hasClients) {
      return null;
    }
    final self = context.findRenderObject() as RenderBox?;
    final top = self?.localToGlobal(Offset.zero).dy ?? 0;
    return _scrollController.offset + (box.localToGlobal(Offset.zero).dy - top);
  }

  double _overlayAlignment() {
    if (!_scrollController.hasClients) return 0;
    final viewport = _scrollController.position.viewportDimension;
    if (viewport <= 0) return 0;
    var overlay = _chipRailExtent;
    if (_pinAllowedCache) overlay += _safeTopCache + _stickyExtent;
    return (overlay / viewport).clamp(0.0, 0.6);
  }

  /// Section heights from the settled type scale; the scroll that follows
  /// an estimate corrects against the laid-out section, so this only has
  /// to land within the viewport's reach.
  double? _estimateGroupOffset(String groupName) {
    final rail = _railOffset;
    final railExtent = _railExtent;
    if (rail == null || railExtent == null) return null;
    final textScale = MediaQuery.textScalerOf(context).scale(1);
    final titleBlock =
        HaraSpace.groupGap +
        11 * 1.5 * textScale +
        HaraSpace.sectionTitleGap +
        HaraSpace.hairline;
    final rowHeight =
        HaraSpace.nodeRowVertical * 2 +
        15 * 1.4 * textScale +
        HaraSpace.hairline;
    var y = rail + railExtent;
    for (final group in _groupsCache) {
      if (group.name == groupName) return y;
      y += titleBlock;
      if (_expandedFor(group.name)) y += group.all.length * rowHeight;
    }
    return null;
  }

  Future<void> _scrollToGroup(String groupName) async {
    if (!_expandedFor(groupName)) _setFold(groupName, true);
    await WidgetsBinding.instance.endOfFrame;
    if (!mounted || !_scrollController.hasClients) return;
    final alignment = _overlayAlignment();
    final target = _sectionKeys[groupName]?.currentContext;
    if (target != null && target.mounted) {
      await Scrollable.ensureVisible(
        target,
        alignment: alignment,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
      return;
    }
    final estimate = _estimateGroupOffset(groupName);
    if (estimate == null) return;
    final maxExtent = _scrollController.position.maxScrollExtent;
    await _scrollController.animateTo(
      estimate.clamp(0.0, maxExtent),
      duration: const Duration(milliseconds: 320),
      curve: Curves.easeOut,
    );
    if (!mounted) return;
    final landed = _sectionKeys[groupName]?.currentContext;
    if (landed != null && landed.mounted) {
      await Scrollable.ensureVisible(
        landed,
        alignment: alignment,
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeOut,
      );
    }
  }

  _Phase _phase({
    required bool hasProfile,
    required bool isStart,
    required bool singBoxRunning,
    required bool suspended,
    required ProbeEntry<IpInfo> entry,
  }) {
    if (!hasProfile) return _Phase.noProfile;
    if (_pending == true && !isStart) return _Phase.connecting;
    if (_pending == false && isStart) return _Phase.disconnecting;
    if (singBoxRunning && !isStart) return _Phase.connected;
    if (!isStart) return _Phase.disconnected;
    if (suspended) return _Phase.suspended;
    if (shownPhase(entry) == ProbePhase.failed && entry.value == null) {
      return _Phase.error;
    }
    return _Phase.connected;
  }

  // The exit chain: follow group selections from GLOBAL (or the first
  // group) down to the leaf that actually carries the traffic.
  ({String group, String leaf})? _exitLeaf(List<Group> groups) {
    if (groups.isEmpty) return null;
    final byName = {for (final group in groups) group.name: group};
    var current = byName['GLOBAL'] ?? groups.first;
    final visited = <String>{};
    while (visited.add(current.name)) {
      final selected = ref.watch(selectedProxyNameProvider(current.name));
      if (selected == null || selected.isEmpty) return null;
      final next = byName[selected];
      if (next == null) {
        return (group: current.name, leaf: selected);
      }
      current = next;
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.haraPalette;
    final hasProfile = ref.watch(
      profilesProvider.select((state) => state.isNotEmpty),
    );
    final isStart = ref.watch(isStartProvider);
    final suspended = isStart && ref.watch(suspendProvider);
    final entry = ref.watch(
      outboundIpProbeProvider.select((state) => state.entryOf(routedOutbound)),
    );
    final singBoxRunning =
        ref.watch(singBoxActionProvider).value?.state == SingBoxState.running;
    final runningCore = singBoxRunning
        ? CoreKind.singbox
        : (isStart ? CoreKind.mihomo : null);
    final activeKind =
        ref.watch(activeCoreKindProvider).value ?? CoreKind.mihomo;
    final phase = _phase(
      hasProfile: hasProfile,
      isStart: isStart,
      singBoxRunning: singBoxRunning,
      suspended: suspended,
      entry: entry,
    );
    final profile = ref.watch(currentProfileProvider);
    final ipInfo = entry.value;
    final nodeName = ipInfo == null ? null : entry.stamp?.chains.firstOrNull;
    final delay = nodeName == null
        ? null
        : ref.watch(delayProvider(proxyName: nodeName));
    final listedGroups = ref.watch(
      proxiesListStateProvider.select((state) => state.groups),
    );
    final delaySnapshot = ref.watch(delaysAtLastTestBatchProvider);
    final selectedMap = ref.watch(selectedMapProvider);
    final defaultTestUrl = ref.watch(realTestUrlProvider());
    final groups = _sortByDelay
        ? computeSort(
            groups: listedGroups,
            sortType: ProxiesSortType.delay,
            delayMap: delaySnapshot,
            selectedMap: selectedMap,
            defaultTestUrl: defaultTestUrl,
          )
        : listedGroups;
    final exit = _exitLeaf(groups);
    final pinAllowed = phase == _Phase.connected || phase == _Phase.suspended;
    final query = ref.watch(queryProvider(QueryTag.proxies));
    final searching = query.isNotEmpty;
    _pinAllowedCache = pinAllowed;
    _safeTopCache = MediaQuery.paddingOf(context).top;
    _exitGroupCache = exit?.group;
    _groupsCache = groups;
    _searchingCache = searching;
    final profileId = profile?.id;
    if (profileId != null && profileId != _foldSeededProfileId) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted || _foldSeededProfileId == profileId) return;
        _foldSeededProfileId = profileId;
        final stored = ref.read(unfoldSetProvider);
        if (stored.isEmpty) return;
        final names = ref
            .read(groupsProvider)
            .map((group) => group.name)
            .toSet();
        setState(() {
          _foldToggles = {
            for (final name in names) name: stored.contains(name),
          };
        });
      });
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final box = _heroKey.currentContext?.findRenderObject() as RenderBox?;
      if (box != null && box.hasSize) _heroExtent = box.size.height;
      final railBox = _railKey.currentContext?.findRenderObject() as RenderBox?;
      if (railBox != null && railBox.hasSize) {
        _railExtent = railBox.size.height;
        _railOffset = _contentOffsetOf(_railKey);
      }
      _updateSticky();
    });
    return Material(
      color: palette.bg,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final side = math.max(
            HaraSpace.pageInset,
            (constraints.maxWidth - HaraSpace.contentMaxWidth) / 2,
          );
          return Stack(
            children: [
              CustomScrollView(
                controller: _scrollController,
                slivers: [
                  SliverPadding(
                    padding: EdgeInsets.symmetric(horizontal: side),
                    sliver: SliverMainAxisGroup(
                      slivers: [
                        SliverToBoxAdapter(
                          child: KeyedSubtree(
                            key: _heroKey,
                            child: _hero(
                              context,
                              phase: phase,
                              palette: palette,
                              profile: profile,
                              nodeName: nodeName,
                              runningCore: runningCore,
                            ),
                          ),
                        ),
                        if (phase != _Phase.noProfile) ...[
                          SliverToBoxAdapter(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                _dataList(
                                  context,
                                  phase: phase,
                                  palette: palette,
                                  ipInfo: ipInfo,
                                  delay: delay,
                                  runningCore: runningCore,
                                  activeKind: activeKind,
                                ),
                                const SizedBox(height: HaraSpace.listToModeGap),
                                _modeRow(context, palette),
                              ],
                            ),
                          ),
                          if (groups.isNotEmpty || searching)
                            SliverToBoxAdapter(
                              child: _searchRow(context, palette),
                            ),
                          if (groups.isNotEmpty)
                            SliverToBoxAdapter(
                              child: _testAllHead(context, palette),
                            ),
                          if (groups.isNotEmpty)
                            SliverToBoxAdapter(
                              child: KeyedSubtree(
                                key: _railKey,
                                child: _chipRailBlock(
                                  context,
                                  palette,
                                  groups,
                                  exit?.group,
                                ),
                              ),
                            ),
                          for (final group in groups)
                            HaraProxyGroupSection(
                              key: _sectionKeyFor(group.name),
                              group: group,
                              exitName: exit != null && exit.group == group.name
                                  ? exit.leaf
                                  : null,
                              first: false,
                              exitMarker: pinAllowed
                                  ? HaraExitMarker.label
                                  : HaraExitMarker.dot,
                              expanded: _expandedFor(group.name),
                              onToggleFold: searching
                                  ? null
                                  : () => _setFold(
                                      group.name,
                                      !_expandedFor(group.name),
                                    ),
                              pinExit: !searching && !_sortByDelay,
                              headerCount: searching ? group.all.length : null,
                            ),
                          const SliverToBoxAdapter(
                            child: SizedBox(height: HaraSpace.modeToNavGap),
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
              Positioned(
                top: 0,
                left: 0,
                right: 0,
                child: ValueListenableBuilder<({bool status, bool chips})>(
                  valueListenable: _sticky,
                  builder: (context, view, _) {
                    final showStatus = view.status && pinAllowed;
                    if (!showStatus && !view.chips) {
                      return const SizedBox.shrink();
                    }
                    return Material(
                      color: palette.bg,
                      child: SafeArea(
                        bottom: false,
                        child: Padding(
                          padding: EdgeInsets.symmetric(horizontal: side),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              if (showStatus)
                                _stickyBar(
                                  context,
                                  phase: phase,
                                  palette: palette,
                                  nodeName: nodeName,
                                ),
                              if (view.chips) ...[
                                KeyedSubtree(
                                  key: const ValueKey('stickyNodeChips'),
                                  child: _chipRail(
                                    context,
                                    palette,
                                    groups,
                                    exit?.group,
                                  ),
                                ),
                                const HaraHairline(),
                              ],
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _hero(
    BuildContext context, {
    required _Phase phase,
    required HaraPalette palette,
    required Profile? profile,
    required String? nodeName,
    required CoreKind? runningCore,
  }) {
    final appLocalizations = context.appLocalizations;
    final ringColor = switch (phase) {
      _Phase.noProfile || _Phase.disconnected => palette.dim,
      _Phase.connected ||
      _Phase.suspended => palette.ink.withValues(alpha: 0.78),
      _ => palette.ink,
    };
    final statusText = switch (phase) {
      _Phase.noProfile => appLocalizations.addProfile,
      _Phase.disconnected => appLocalizations.disconnected,
      _Phase.connecting => appLocalizations.connecting,
      _Phase.connected => appLocalizations.connected,
      _Phase.disconnecting => appLocalizations.disconnecting,
      _Phase.suspended => appLocalizations.suspended,
      _Phase.error => appLocalizations.connectionFailed,
    };
    final statusColor = switch (phase) {
      _Phase.error => context.colorScheme.error,
      _Phase.disconnected || _Phase.disconnecting => palette.sub,
      _Phase.noProfile => palette.sub,
      _ => palette.ink,
    };
    final shownNode = switch (phase) {
      _Phase.disconnected || _Phase.noProfile => profile?.realLabel,
      _ => nodeName ?? profile?.realLabel,
    };
    final idleCore = switch (runningCore) {
      CoreKind.mihomo => CoreKind.singbox,
      CoreKind.singbox => CoreKind.mihomo,
      null => null,
    };
    return SafeArea(
      bottom: false,
      child: Column(
        children: [
          const SizedBox(height: HaraSpace.brandTopGap),
          Row(
            children: [
              Text(appName, style: HaraText.brand(context, palette.dim)),
              Expanded(
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    if (idleCore != null) ...[
                      Flexible(
                        child: Text(
                          appLocalizations.coreNotRunning(_coreName(idleCore)),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: HaraText.statusNode(context, palette.dim),
                        ),
                      ),
                      if (coreLib == null) const SizedBox(width: 12),
                    ],
                    if (coreLib == null) const CoreStatusButton(),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: HaraSpace.ringTopGap),
          Semantics(
            button: true,
            label: statusText,
            child: InkWell(
              customBorder: AppShape.circle,
              onTap: phase == _Phase.noProfile
                  ? () =>
                        BaseNavigator.push(context, const UniversalImportView())
                  : (runningCore == CoreKind.singbox
                        ? _toggleSingBox
                        : _toggle),
              child: DiscRingMotif(
                size: HaraSpace.ringSize,
                color: ringColor,
                strokeWidth: HaraSpace.ringStroke,
                lit: phase == _Phase.connected || phase == _Phase.suspended,
              ),
            ),
          ),
          const SizedBox(height: HaraSpace.statusTopGap),
          if (phase == _Phase.noProfile)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: Text(
                statusText,
                textAlign: TextAlign.center,
                style: HaraText.statusNode(context, palette.sub),
              ),
            )
          else
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Flexible(
                  child: Text(
                    statusText,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: HaraText.status(context, statusColor),
                  ),
                ),
              ],
            ),
          if (phase == _Phase.error) ...[
            const SizedBox(height: 8),
            Text(
              appLocalizations.serviceFailed,
              textAlign: TextAlign.center,
              style: HaraText.statusNode(context, palette.sub),
            ),
          ],
          if (phase != _Phase.noProfile) ...[
            const SizedBox(height: HaraSpace.nodeTopGap),
            Text(
              shownNode ?? '',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: HaraText.statusNode(context, palette.sub),
            ),
          ],
          if (phase == _Phase.noProfile) ...[
            const SizedBox(height: 34),
            _importRow(context, palette),
          ],
        ],
      ),
    );
  }

  Widget _importRow(BuildContext context, HaraPalette palette) {
    final appLocalizations = context.appLocalizations;
    return InkWell(
      customBorder: AppShape.hara,
      onTap: () => BaseNavigator.push(context, const UniversalImportView()),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 15),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              appLocalizations.addProfile,
              style: HaraText.addRow(context, palette.sub),
            ),
            const SizedBox(width: 8),
            Text('→', style: HaraText.addRowArrow(context, palette.sub)),
          ],
        ),
      ),
    );
  }

  Widget _testAllHead(BuildContext context, HaraPalette palette) {
    final appLocalizations = context.appLocalizations;
    final testing = ref.watch(delayTestingGroupsProvider).isNotEmpty;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SizedBox(height: HaraSpace.groupGap),
        InkWell(
          customBorder: AppShape.hara,
          onTap: _testAll,
          child: Padding(
            padding: const EdgeInsets.symmetric(
              vertical: HaraSpace.addRowVertical,
            ),
            child: Text(
              testing
                  ? appLocalizations.actionDelayTesting
                  : appLocalizations.actionDelayTest,
              style: HaraText.pageAction(context, palette.dim),
            ),
          ),
        ),
        HaraHairline(color: palette.line),
      ],
    );
  }

  Widget _stickyBar(
    BuildContext context, {
    required _Phase phase,
    required HaraPalette palette,
    required String? nodeName,
  }) {
    final appLocalizations = context.appLocalizations;
    final statusText = phase == _Phase.suspended
        ? appLocalizations.suspended
        : appLocalizations.connected;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          height: _stickyExtent - HaraSpace.hairline,
          child: Row(
            children: [
              DiscRingMotif(
                size: HaraSpace.ringCompact,
                color: palette.ink.withValues(alpha: 0.78),
                strokeWidth: HaraSpace.ringStroke,
                lit: true,
              ),
              const SizedBox(width: 10),
              Text(
                statusText,
                style: HaraText.statusNode(context, palette.ink),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  nodeName ?? '',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: HaraText.statusNode(context, palette.sub),
                ),
              ),
            ],
          ),
        ),
        const HaraHairline(),
      ],
    );
  }

  Widget _searchRow(BuildContext context, HaraPalette palette) {
    final appLocalizations = context.appLocalizations;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SizedBox(height: HaraSpace.groupGap),
        Padding(
          padding: const EdgeInsets.symmetric(
            vertical: HaraSpace.nodeRowVertical,
          ),
          child: Row(
            children: [
              GlyphIcon(AppGlyphs.search, color: palette.sub),
              const SizedBox(width: 8),
              Expanded(
                child: TextField(
                  controller: _searchController,
                  style: HaraText.nodeName(
                    context,
                    palette.ink,
                    current: false,
                  ),
                  cursorColor: palette.ink,
                  textInputAction: TextInputAction.search,
                  onChanged: (value) {
                    ref.read(queryProvider(QueryTag.proxies).notifier).value =
                        value;
                  },
                  decoration: InputDecoration(
                    isCollapsed: true,
                    border: InputBorder.none,
                    hintText: appLocalizations.search,
                    hintStyle: HaraText.nodeName(
                      context,
                      palette.dim,
                      current: false,
                    ),
                  ),
                ),
              ),
              if (_searchController.text.isNotEmpty)
                InkWell(
                  customBorder: AppShape.hara,
                  onTap: () {
                    _searchController.clear();
                    ref.read(queryProvider(QueryTag.proxies).notifier).value =
                        '';
                  },
                  child: GlyphIcon(AppGlyphs.close, color: palette.sub),
                ),
            ],
          ),
        ),
        HaraHairline(color: palette.line),
      ],
    );
  }

  /// The group rail in its in-flow place above the sections; the sticky
  /// overlay re-renders the same rail once this copy scrolls under it.
  Widget _chipRailBlock(
    BuildContext context,
    HaraPalette palette,
    List<Group> groups,
    String? exitGroupName,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SizedBox(height: 16),
        _chipRail(context, palette, groups, exitGroupName),
        const SizedBox(height: 16),
        HaraHairline(color: palette.line),
      ],
    );
  }

  Widget _chipRail(
    BuildContext context,
    HaraPalette palette,
    List<Group> groups,
    String? exitGroupName,
  ) {
    return SizedBox(
      height: _chipRailExtent,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: groups.length,
        separatorBuilder: (_, _) => const SizedBox(width: 24),
        itemBuilder: (context, index) {
          final group = groups[index];
          final isExit = group.name == exitGroupName;
          return InkWell(
            customBorder: AppShape.hara,
            onTap: () => _scrollToGroup(group.name),
            child: IntrinsicWidth(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  EmojiText(
                    group.name,
                    maxLines: 1,
                    style: HaraText.mode(
                      context,
                      isExit ? palette.ink : palette.dim,
                      selected: isExit,
                    ),
                  ),
                  const SizedBox(height: HaraSpace.modeUnderlineGap),
                  Container(
                    height: HaraSpace.modeUnderline,
                    color: isExit ? palette.ink : HaraPalette.transparent,
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _dataList(
    BuildContext context, {
    required _Phase phase,
    required HaraPalette palette,
    required IpInfo? ipInfo,
    required int? delay,
    required CoreKind? runningCore,
    required CoreKind activeKind,
  }) {
    final appLocalizations = context.appLocalizations;
    final showValues =
        phase == _Phase.connected ||
        phase == _Phase.suspended ||
        phase == _Phase.disconnecting;
    final hideIp = ref.watch(
      appSettingProvider.select((state) => state.hideIp),
    );
    final total = ref.watch(totalTrafficProvider);
    final dash = ('—', palette.dim, null as String?);
    (String, Color, String?) valueOf(bool ok, String value, [String? unit]) {
      return ok ? (value, palette.ink, unit) : dash;
    }

    final delayRow = valueOf(
      showValues && delay != null && delay > 0,
      '$delay',
      'ms',
    );
    final exitIp = showValues && !hideIp ? ipInfo?.ip : null;
    final exitType = exitIp == null
        ? null
        : ref.watch(ipQualityProvider(exitIp)).value?.type;
    // The country rides the same probe answer as the address itself, so
    // it resolves locally and lands with the IP, unlike the type.
    final exitCountry = exitIp == null
        ? null
        : countryName(ipInfo!.countryCode, Localizations.localeOf(context));
    final exitParts = [
      ?exitCountry,
      if (exitType != null) exitType.label(context),
    ];
    final exitRow = hideIp
        ? valueOf(showValues && ipInfo != null, '*****')
        : valueOf(
            showValues && ipInfo != null && exitParts.isNotEmpty,
            exitParts.join(' · '),
          );
    final kernelRow = valueOf(showValues, _coreName(runningCore ?? activeKind));
    // The counters are mihomo-fed; under sing-box they would misreport zero.
    final totalShow = (total.up + total.down).traffic;
    final sessionRow = valueOf(
      showValues && runningCore != CoreKind.singbox,
      totalShow.value,
      totalShow.unit,
    );
    final rows = <(String, (String, Color, String?))>[
      (appLocalizations.delay, delayRow),
      (appLocalizations.ipExit, exitRow),
      (appLocalizations.core, kernelRow),
      (appLocalizations.totalTraffic, sessionRow),
    ];
    return Column(
      children: [
        for (final (label, value) in rows) ...[
          const HaraHairline(),
          Padding(
            padding: const EdgeInsets.symmetric(
              vertical: HaraSpace.dataRowVertical,
            ),
            child: Row(
              children: [
                Text(label, style: HaraText.dataKey(context, palette.sub)),
                const Spacer(),
                Text(value.$1, style: HaraText.dataValue(context, value.$2)),
                if (value.$3 != null) ...[
                  const SizedBox(width: 6),
                  Text(
                    value.$3!,
                    style: HaraText.dataUnit(context, palette.sub),
                  ),
                ],
              ],
            ),
          ),
        ],
        const HaraHairline(),
      ],
    );
  }

  Widget _modeRow(BuildContext context, HaraPalette palette) {
    final mode = ref.watch(
      patchClashConfigProvider.select((state) => state.mode),
    );
    return Row(
      children: [
        for (final (index, item) in Mode.values.indexed) ...[
          if (index > 0) const SizedBox(width: HaraSpace.modeItemGap),
          InkWell(
            customBorder: AppShape.hara,
            onTap: () {
              if (mode == item) return;
              ref.read(setupActionProvider.notifier).changeMode(item);
            },
            child: IntrinsicWidth(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    item.label,
                    style: HaraText.mode(
                      context,
                      item == mode ? palette.ink : palette.dim,
                      selected: item == mode,
                    ),
                  ),
                  const SizedBox(height: HaraSpace.modeUnderlineGap),
                  Container(
                    height: HaraSpace.modeUnderline,
                    color: item == mode ? palette.ink : HaraPalette.transparent,
                  ),
                ],
              ),
            ),
          ),
        ],
      ],
    );
  }
}
