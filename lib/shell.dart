import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:url_launcher/url_launcher.dart';
import 'data/app_update_repo.dart';
import 'data/backend.dart';
import 'data/composer.dart';
import 'data/models/space.dart';
import 'data/photo_store.dart';
import 'data/repos.dart';
import 'theme/kawaii.dart';
import 'theme/prefs.dart';
import 'widgets/kawaii.dart';
import 'widgets/app_update_dialog.dart';
import 'widgets/kawaii_fab.dart';
import 'widgets/offline_banner.dart';
import 'screens/tab_home.dart';
import 'screens/tab_notes.dart';
import 'screens/tab_galleries.dart';
import 'screens/tab_dates.dart';
import 'screens/tab_settings.dart';

class AppShell extends StatefulWidget {
  const AppShell({super.key});
  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  int idx = 0;
  int _tick = 0;
  final titles = const ['home', 'notes', 'piles', 'dates', 'you'];
  final icons = const [
    Icons.home_rounded,
    Icons.edit_note_rounded,
    Icons.photo_library_rounded,
    Icons.calendar_month_rounded,
    Icons.settings_rounded,
  ];
  final colors = const [
    Kawaii.peach,
    Kawaii.bubble,
    Kawaii.sky,
    Kawaii.sunny,
    Kawaii.mint,
  ];

  late final Backend _backend = resolveBackend();
  // Memory pages for pre-pairing explorers in cloud mode. In demo mode
  // the backend itself is memory-backed, so this fallback is unused.
  final Backend _soloFallback = DemoBackend();
  Backend get _active =>
      (_paired || !_backend.isCloud) ? _backend : _soloFallback;

  SpaceRepo get _spaces => _backend.spaces;
  AuthRepo get _auth => _backend.auth;
  NotesRepo get _notes => _active.notes;
  DatesRepo get _dates => _active.dates;
  RitualsRepo get _rituals => _active.rituals;
  PilesRepo get _piles => _active.piles;
  PhotoStore get _photos => _active.photos;

  Space? _space;
  bool _spaceLoading = true;
  List<MemberProfile> _members = [];
  String _myUsername = 'you';
  AppRelease? _update;
  bool _updateDialogShown = false;

  bool get _paired => _space != null;
  String get _spaceId => _space?.id ?? kDemoSpaceId;
  String get _uid => _auth.currentUserId ?? kDemoUid;

  @override
  void initState() {
    super.initState();
    _loadSpace();
    _checkForUpdate();
  }

  /// Check GitHub releases for a newer build. Silent on any failure
  /// (offline, no releases, tests without platform plugins) so the
  /// shell never blocks on this.
  Future<void> _checkForUpdate() async {
    try {
      final info = await PackageInfo.fromPlatform();
      final rel = await fetchLatestRelease();
      if (rel == null) return;
      if (!isNewerVersion(info.version, rel.tag)) return;
      final skipped = await KawaiiPrefs.loadSkippedUpdateTag();
      if (skipped == rel.tag) return;
      if (!mounted) return;
      setState(() => _update = rel);
      WidgetsBinding.instance.addPostFrameCallback((_) => _showUpdateDialog());
    } catch (_) {}
  }

  void _showUpdateDialog() {
    final rel = _update;
    if (rel == null || _updateDialogShown || !mounted) return;
    _updateDialogShown = true;
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (dlgCtx) => AppUpdateDialog(
        release: rel,
        onLater: () {
          Navigator.of(dlgCtx).pop();
          _dismissUpdate();
        },
        onOpenRelease: _openRelease,
      ),
    ).then((_) => _updateDialogShown = false);
  }

  Future<void> _openRelease() async {
    final url = _update?.url;
    if (url == null || url.isEmpty) return;
    try {
      await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
    } catch (_) {
      if (!mounted) return;
      showKawaiiToast(context, 'Could not open the release page',
          kind: KawaiiAlertKind.danger);
    }
  }

  Future<void> _dismissUpdate() async {
    final tag = _update?.tag;
    if (tag != null) {
      try {
        await KawaiiPrefs.saveSkippedUpdateTag(tag);
      } catch (_) {}
    }
    if (mounted) setState(() => _update = null);
  }

  Future<void> _loadSpace() async {
    try {
      _space = await _spaces.mySpace();
    } catch (_) {
      _space = null;
    }
    try {
      final hint =
          _auth.currentUsername ?? _auth.currentEmail?.split('@').first;
      await _spaces.ensureProfile(username: hint);
      if ((hint ?? '').trim().isNotEmpty) _myUsername = hint!.trim();
    } catch (_) {}
    if (_space != null) {
      try {
        _members = await _spaces.membersWithProfiles(_space!.id);
        final me = _members.where((m) => m.userId == _uid);
        if (me.isNotEmpty && me.first.username.trim().isNotEmpty) {
          _myUsername = me.first.username;
        }
      } catch (_) {
        _members = [];
      }
    } else {
      _members = [];
    }
    if (mounted) setState(() => _spaceLoading = false);
  }

  String get _meInitial => avatarInitial(_myUsername, fallback: 'Y');

  String? get _partnerInitial {
    if (_space == null) return null;
    final others = _members.where((m) => m.userId != _uid).toList();
    if (others.isEmpty) return null;
    return others.first.initial;
  }

  ComposerDeps _deps() => ComposerDeps(
        spaceId: _spaceId,
        composer: AppComposer(_active),
        onCreated: () {
          if (mounted) setState(() => _tick++);
        },
      );

  void _jump(int i) => setState(() {
        idx = i;
      });

  void _scheduleDate() =>
      showCreateSheet(context, CreateKind.date, _deps());

  /// Contextual FAB target: only notes / piles / dates have one.
  /// Returns null on home + you so no FAB is built there.
  CreateKind? get _fabKind => switch (idx) {
        1 => CreateKind.note,
        2 => CreateKind.pile,
        3 => CreateKind.date,
        _ => null,
      };

  void _createForCurrentTab() {
    final kind = _fabKind;
    if (kind == null) return;
    showCreateSheet(context, kind, _deps());
  }

  @override
  Widget build(BuildContext context) {
    final edge = Kawaii.edgeOf(context);
    final barBg = Kawaii.cardOf(context);
    final fabKind = _fabKind;
    return Scaffold(
      appBar: AppBar(
        title: Row(children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: colors[idx],
              borderRadius: BorderRadius.circular(999),
              border: Border.all(color: edge, width: 2.5),
            ),
            child: Row(children: [
              Icon(icons[idx], size: 16, color: Kawaii.ink),
              const SizedBox(width: 6),
              Text(titles[idx],
                  style: const TextStyle(
                      fontWeight: FontWeight.w900,
                      fontSize: 14,
                      color: Kawaii.ink)),
            ]),
          ),
          const Spacer(),
          KawaiiAvatarPair(
            first: _spaceLoading ? '•' : _meInitial,
            second: _spaceLoading ? null : _partnerInitial,
            size: 32,
          ),
        ]),
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const OfflineBanner(),
          if (_update != null)
            GestureDetector(
              onTap: _showUpdateDialog,
              behavior: HitTestBehavior.opaque,
              child: Container(
                width: double.infinity,
                margin: const EdgeInsets.fromLTRB(20, 8, 20, 0),
                padding: const EdgeInsets.symmetric(
                    horizontal: 14, vertical: 10),
                decoration: BoxDecoration(
                  color: Kawaii.sunnySubtle,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                      color: Kawaii.edgeOf(context), width: 2.5),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.celebration_rounded,
                        size: 18, color: Kawaii.ink),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                          'ourspace ${_update!.tag} is here — tap to update',
                          style: const TextStyle(
                              fontWeight: FontWeight.w800,
                              fontSize: 13,
                              color: Kawaii.ink)),
                    ),
                    GestureDetector(
                      onTap: _dismissUpdate,
                      behavior: HitTestBehavior.opaque,
                      child: const Padding(
                        padding: EdgeInsets.all(4),
                        child: Icon(Icons.close_rounded,
                            size: 16, color: Kawaii.ink),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          Expanded(
            child: Stack(
        children: [
          if (_spaceLoading)
            const Center(child: CircularProgressIndicator())
          else
            IndexedStack(index: idx, children: [
              HomeTab(
                  key: ValueKey('home-$_tick'),
                  space: _space,
                  notesRepo: _notes,
                  ritualsRepo: _rituals,
                  onJump: _jump),
              NotesTab(
                  key: ValueKey('notes-$_tick'),
                  spaceId: _spaceId,
                  notesRepo: _notes,
                  myUid: _uid),
              GalleriesTab(
                  key: ValueKey('piles-$_tick'),
                  spaceId: _spaceId,
                  pilesRepo: _piles,
                  photoStore: _photos),
              DatesTab(
                  key: ValueKey('dates-$_tick'),
                  spaceId: _spaceId,
                  datesRepo: _dates,
                  onSchedule: _scheduleDate),
              SettingsTab(
                key: ValueKey('you-$_tick'),
                auth: _auth,
                spaceRepo: _spaces,
                space: _space,
                notesRepo: _notes,
                datesRepo: _dates,
                ritualsRepo: _rituals,
              ),
            ]),
          if (fabKind != null)
            Positioned(
              right: 20,
              bottom: 100,
              child: KawaiiCreateFab(
                kind: fabKind,
                onTap: _createForCurrentTab,
              ),
            ),
        ],
      ),
          ),
        ],
      ),
      extendBody: true,
      bottomNavigationBar: SafeArea(
        child: Container(
          margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
          decoration: BoxDecoration(
            color: barBg,
            borderRadius: BorderRadius.circular(28),
            border: Border.all(color: edge, width: 3),
            boxShadow: [
              BoxShadow(color: edge, offset: const Offset(4, 4)),
            ],
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: List.generate(5, (i) {
              final active = i == idx;
              final inactive = Kawaii.textOf(context).withValues(alpha: 0.45);
              return Semantics(
                button: true,
                selected: active,
                label: titles[i],
                child: GestureDetector(
                onTap: () => _jump(i),
                behavior: HitTestBehavior.opaque,
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 180),
                  padding: EdgeInsets.symmetric(
                      horizontal: active ? 14 : 12, vertical: 12),
                  decoration: BoxDecoration(
                    color: active ? colors[i] : Colors.transparent,
                    borderRadius: BorderRadius.circular(999),
                    border: Border.all(
                        color: active ? edge : Colors.transparent,
                        width: 2.5),
                  ),
                  child: Row(children: [
                    Icon(icons[i],
                        size: 22,
                        color: active ? Kawaii.ink : inactive),
                    if (active) ...[
                      const SizedBox(width: 6),
                      Text(titles[i],
                          style: const TextStyle(
                              fontWeight: FontWeight.w900,
                              fontSize: 13,
                              color: Kawaii.ink)),
                    ],
                  ]),
                ),
                ),
              );
            }),
          ),
        ),
      ),
    );
  }
}
