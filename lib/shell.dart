import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:ota_update/ota_update.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:url_launcher/url_launcher.dart';
import 'data/app_update_repo.dart';
import 'data/auth_repo.dart';
import 'data/content_repos.dart';
import 'data/models/space.dart';
import 'data/photo_store.dart';
import 'data/repos.dart';
import 'data/space_repo.dart';
import 'data/supa.dart';
import 'theme/kawaii.dart';
import 'theme/prefs.dart';
import 'widgets/kawaii.dart';
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
  bool fabOpen = false;
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

  late final SpaceRepo _spaces = resolveSpaceRepo();
  late final AuthRepo _auth = resolveAuthRepo();
  // Cloud impls (used when paired) + memory impls (solo/demo). Created
  // once so solo sessions keep their in-memory pages.
  final NotesRepo _cloudNotes = SupabaseNotesRepo();
  final DatesRepo _cloudDates = SupabaseDatesRepo();
  final RitualsRepo _cloudRituals = SupabaseRitualsRepo();
  final PilesRepo _cloudPiles = SupabasePilesRepo();
  final NotesRepo _memNotes = MemoryNotesRepo();
  final DatesRepo _memDates = MemoryDatesRepo();
  final RitualsRepo _memRituals = MemoryRitualsRepo();
  final PilesRepo _memPiles = MemoryPilesRepo();
  final PhotoStore _r2photos = R2PhotoStore();
  final PhotoStore _memPhotos = MemoryPhotoStore();

  Space? _space;
  bool _spaceLoading = true;
  List<MemberProfile> _members = [];
  String _myUsername = 'you';
  AppRelease? _update;
  bool _updateDialogShown = false;

  bool get _paired => _space != null;
  String get _spaceId => _space?.id ?? 'local';
  NotesRepo get _notes => _paired ? _cloudNotes : _memNotes;
  DatesRepo get _dates => _paired ? _cloudDates : _memDates;
  RitualsRepo get _rituals => _paired ? _cloudRituals : _memRituals;
  PilesRepo get _piles => _paired ? _cloudPiles : _memPiles;
  PhotoStore get _photos => _paired ? _r2photos : _memPhotos;
  String get _uid {
    if (Supa.ready) return Supa.client.auth.currentUser?.id ?? 'demo-user';
    return 'demo-user';
  }

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
      builder: (dlgCtx) => _UpdateDialog(
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
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not open the release page')),
      );
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
        notes: _notes,
        piles: _piles,
        dates: _dates,
        photos: _photos,
        onCreated: () {
          if (mounted) setState(() => _tick++);
        },
      );

  void _jump(int i) => setState(() {
        fabOpen = false;
        idx = i;
      });

  void _scheduleDate() =>
      showCreateSheet(context, CreateKind.date, _deps());

  void _pickKind(CreateKind kind) {
    setState(() {
      fabOpen = false;
      idx = switch (kind) {
        CreateKind.note => 1,
        CreateKind.pile => 2,
        CreateKind.date => 3,
      };
    });
    showCreateSheet(context, kind, _deps());
  }

  @override
  Widget build(BuildContext context) {
    final dark = Kawaii.isDark(context);
    final edge = Kawaii.edgeOf(context);
    final barBg = Kawaii.cardOf(context);
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
          if (fabOpen)
            Positioned.fill(
              child: GestureDetector(
                onTap: () => setState(() => fabOpen = false),
                child: Container(
                  color: (dark ? Colors.black : Kawaii.ink)
                      .withValues(alpha: 0.25),
                ),
              ),
            ),
          Positioned(
            right: 20,
            bottom: 100,
            child: KawaiiCreateFab(
              open: fabOpen,
              onToggle: () => setState(() => fabOpen = !fabOpen),
              onPick: _pickKind,
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

/// Update dialog: direct download + install on Android when the release
/// carries an APK asset, otherwise a shortcut to the release page
/// (iOS and asset-less releases).
class _UpdateDialog extends StatefulWidget {
  final AppRelease release;
  final VoidCallback onLater;
  final VoidCallback onOpenRelease;
  const _UpdateDialog({
    required this.release,
    required this.onLater,
    required this.onOpenRelease,
  });

  @override
  State<_UpdateDialog> createState() => _UpdateDialogState();
}

class _UpdateDialogState extends State<_UpdateDialog> {
  bool _busy = false;
  bool _installing = false;
  int _progress = 0;
  String? _error;
  StreamSubscription<OtaEvent>? _sub;

  bool get _direct =>
      Platform.isAndroid && widget.release.supportsDirectInstall;

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }

  void _startDownload() {
    if (_busy) return;
    setState(() {
      _busy = true;
      _installing = false;
      _progress = 0;
      _error = null;
    });
    final tag = widget.release.tag.replaceAll(RegExp(r'[^A-Za-z0-9._-]'), '');
    _sub = OtaUpdate()
        .execute(widget.release.apkUrl,
            destinationFilename: 'ourspace-$tag.apk')
        .listen((e) {
      if (!mounted) return;
      switch (e.status) {
        case OtaStatus.DOWNLOADING:
          setState(() => _progress = int.tryParse(e.value ?? '0') ?? 0);
        case OtaStatus.INSTALLING:
          setState(() {
            _installing = true;
            _progress = 100;
          });
        case OtaStatus.INSTALLATION_DONE:
          if (mounted) Navigator.of(context).maybePop();
        case OtaStatus.PERMISSION_NOT_GRANTED_ERROR:
          setState(() {
            _busy = false;
            _error = 'Allow “install unknown apps” for ourspace, then retry.';
          });
        case OtaStatus.DOWNLOAD_ERROR:
          setState(() {
            _busy = false;
            _error = 'Download failed — check connection and retry.';
          });
        default:
          setState(() {
            _busy = false;
            _error = 'Update hiccuped — try the release page instead.';
          });
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final rel = widget.release;
    final notes = rel.notes.trim();
    return Dialog(
      backgroundColor: Colors.transparent,
      child: KawaiiCard(
        color: Kawaii.sunnySubtle,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const KawaiiPill(label: 'fresh sticker drop', color: Kawaii.sunny),
            const SizedBox(height: 12),
            Text('ourspace ${rel.tag} is here',
                style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w900,
                    fontFamily: Kawaii.displayFamily)),
            const SizedBox(height: 6),
            Text(
              notes.isEmpty
                  ? 'A cuter build is waiting on GitHub.'
                  : (notes.length > 220 ? '${notes.substring(0, 220)}…' : notes),
              style:
                  const TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
            ),
            const SizedBox(height: 16),
            if (_busy) ...[
              Row(
                children: [
                  Expanded(
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(999),
                      child: LinearProgressIndicator(
                        value: _installing ? null : _progress / 100,
                        minHeight: 12,
                        backgroundColor: Colors.white,
                        valueColor: const AlwaysStoppedAnimation<Color>(
                            Kawaii.mint),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Text(_installing ? '…' : '$_progress%',
                      style: const TextStyle(fontWeight: FontWeight.w800)),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                _installing
                    ? 'Installing — confirm on the system prompt.'
                    : 'Downloading update… keep the app open.',
                style: const TextStyle(
                    fontSize: 12, fontWeight: FontWeight.w600),
              ),
            ] else if (_direct)
              KawaiiButton(
                label: 'Download & install',
                icon: Icons.file_download_rounded,
                color: KawaiiBtnColor.sunny,
                onTap: _startDownload,
              )
            else
              KawaiiButton(
                label: 'View release',
                icon: Icons.file_download_rounded,
                color: KawaiiBtnColor.sunny,
                onTap: widget.onOpenRelease,
              ),
            if (_error != null) ...[
              const SizedBox(height: 10),
              Text(_error!,
                  style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: Kawaii.ink)),
              if (_direct)
                TextButton(
                  onPressed: widget.onOpenRelease,
                  child: const Text('Open release page instead',
                      style: TextStyle(
                          fontWeight: FontWeight.w700,
                          color: Kawaii.ink,
                          decoration: TextDecoration.underline)),
                ),
            ],
            const SizedBox(height: 10),
            Center(
              child: TextButton(
                onPressed: _busy && _error == null ? null : widget.onLater,
                child: const Text('Later',
                    style: TextStyle(
                        fontWeight: FontWeight.w700,
                        color: Kawaii.ink,
                        decoration: TextDecoration.underline)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
