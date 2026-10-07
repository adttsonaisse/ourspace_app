import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';
import '../data/app_update_repo.dart';
import '../data/auth_repo.dart';
import '../data/backend.dart';
import '../data/backend_errors.dart';
import '../data/format.dart';
import '../data/models/space.dart';
import '../data/push.dart';
import '../data/repos.dart';
import '../data/storage_maintenance.dart';
import '../theme/kawaii.dart';
import '../theme/prefs.dart';
import '../widgets/app_update_dialog.dart';
import '../widgets/kawaii.dart';
import '../widgets/kawaii_deco.dart';
import 'auth_gate.dart';
import 'auth_pairing.dart';

class SettingsTab extends StatefulWidget {
  final AuthRepo? auth;
  final SpaceRepo? spaceRepo;
  final Space? space;
  final NotesRepo? notesRepo;
  final DatesRepo? datesRepo;
  final PilesRepo? pilesRepo;
  final VoidCallback? onSpaceChanged;
  const SettingsTab(
      {super.key,
      this.auth,
      this.spaceRepo,
      this.space,
      this.notesRepo,
      this.datesRepo,
      this.pilesRepo,
      this.onSpaceChanged});
  @override
  State<SettingsTab> createState() => _SettingsTabState();
}

class _SettingsTabState extends State<SettingsTab> {
  bool notif = false;
  bool _leaving = false;
  bool _exporting = false;
  bool _savingProfile = false;
  bool _savingAnniversary = false;
  bool _checkingUpdate = false;
  bool _clearingCache = false;
  String? _version;
  String? _cacheLabel;
  late final AuthRepo _auth;
  late final SpaceRepo _spaces;
  List<MemberProfile> _members = [];

  String get _uid {
    final id = _auth.currentUserId;
    if (id != null) return id;
    return kDemoUid;
  }

  String get _myName {
    final me = _members.where((m) => m.userId == _uid);
    if (me.isNotEmpty && me.first.username.trim().isNotEmpty) {
      return me.first.username;
    }
    final hint =
        _auth.currentUsername ?? _auth.currentEmail?.split('@').first;
    if ((hint ?? '').trim().isNotEmpty) return hint!.trim();
    return 'you';
  }

  String get _meInitial => avatarInitial(_myName, fallback: 'Y');

  String get _secondInitial {
    final others = _members.where((m) => m.userId != _uid).toList();
    if (others.isEmpty) return '?';
    return others.first.initial;
  }

  String? get _pairNames {
    if (widget.space == null || _members.length < 2) return null;
    final others = _members.where((m) => m.userId != _uid).toList();
    if (others.isEmpty) return null;
    return '$_myName & ${others.first.username}';
  }

  DateTime? get _anniversary => widget.space?.effectiveAnniversary;

  @override
  void initState() {
    super.initState();
    _auth = widget.auth ?? resolveAuthRepo();
    _spaces = widget.spaceRepo ?? resolveSpaceRepo();
    KawaiiPrefs.loadNotif().then((v) {
      if (mounted) setState(() => notif = v);
    });
    _loadMembers();
    _loadVersion();
    _loadCacheSize();
  }

  @override
  void didUpdateWidget(SettingsTab old) {
    super.didUpdateWidget(old);
    if (old.space?.id != widget.space?.id) _loadMembers();
  }

  Future<void> _loadMembers() async {
    final space = widget.space;
    if (space == null) {
      if (mounted) setState(() => _members = []);
      return;
    }
    try {
      final members = await _spaces.membersWithProfiles(space.id);
      if (mounted) setState(() => _members = members);
    } catch (_) {}
  }

  Future<void> _loadVersion() async {
    try {
      final info = await PackageInfo.fromPlatform();
      if (mounted) setState(() => _version = info.version);
    } catch (_) {}
  }

  Future<void> _loadCacheSize() async {
    try {
      final bytes = await getAppCacheBytes();
      if (mounted) setState(() => _cacheLabel = formatBytes(bytes));
    } catch (_) {
      if (mounted) setState(() => _cacheLabel = null);
    }
  }

  Future<void> _clearCache() async {
    if (_clearingCache) return;
    setState(() => _clearingCache = true);
    try {
      await clearAppCaches();
      await _loadCacheSize();
      if (!mounted) return;
      showKawaiiToast(context, 'Cache cleared — storage is fresh again',
          kind: KawaiiAlertKind.success);
    } catch (_) {
      if (!mounted) return;
      showKawaiiToast(context, 'Could not clear cache — try again',
          kind: KawaiiAlertKind.warning);
    } finally {
      if (mounted) setState(() => _clearingCache = false);
    }
  }

  Future<void> _manualCheckUpdate() async {
    if (_checkingUpdate) return;
    setState(() => _checkingUpdate = true);
    try {
      String localVersion;
      try {
        localVersion = (await PackageInfo.fromPlatform()).version;
      } catch (_) {
        if (!mounted) return;
        showKawaiiToast(context, 'Could not read app version. Try again.',
            kind: KawaiiAlertKind.warning);
        return;
      }
      final check = await checkForAppUpdate(localVersion: localVersion);
      if (!mounted) return;
      switch (check.status) {
        case UpdateStatus.upToDate:
          showKawaiiToast(
              context, 'You are on the latest version (v$localVersion)',
              kind: KawaiiAlertKind.success);
        case UpdateStatus.failed:
          showKawaiiToast(context,
              'Could not check for updates — check connection and retry.',
              kind: KawaiiAlertKind.warning);
        case UpdateStatus.available:
          final rel = check.release!;
          showDialog<void>(
            context: context,
            barrierDismissible: false,
            builder: (dlgCtx) => AppUpdateDialog(
              release: rel,
              onLater: () {
                Navigator.of(dlgCtx).pop();
                KawaiiPrefs.saveSkippedUpdateTag(rel.tag);
              },
              onOpenRelease: () async {
                final url = rel.url;
                if (url.isEmpty) return;
                try {
                  await launchUrl(Uri.parse(url),
                      mode: LaunchMode.externalApplication);
                } catch (_) {
                  if (!mounted) return;
                  showKawaiiToast(
                      context, 'Could not open the release page',
                      kind: KawaiiAlertKind.danger);
                }
              },
            ),
          );
      }
    } finally {
      if (mounted) setState(() => _checkingUpdate = false);
    }
  }

  Future<void> _logout() async {
    if (_leaving) return;
    setState(() => _leaving = true);
    try {
      // Drop only this device's token while the uid still exists.
      await Push.unregisterToken();
      await _auth.signOut();
    } catch (e) {
      if (!mounted) return;
      showKawaiiToast(context, friendlyAuthError(e),
          kind: KawaiiAlertKind.danger);
      return;
    } finally {
      if (mounted) setState(() => _leaving = false);
    }
    if (!mounted) return;
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const AuthGate()),
      (_) => false,
    );
  }

  Future<void> _export() async {
    final space = widget.space;
    final notes = widget.notesRepo;
    final dates = widget.datesRepo;
    final piles = widget.pilesRepo;
    if (space == null || notes == null || dates == null || piles == null) {
      showKawaiiToast(context, 'Pair first — then export your space',
          kind: KawaiiAlertKind.info);
      return;
    }
    if (_exporting) return;
    setState(() => _exporting = true);
    try {
      final ns = await notes.list(space.id);
      final ds = await dates.list(space.id);
      final ps = await piles.list(space.id);
      final buf = StringBuffer('${space.name} — ourspace export\n');
      buf.writeln('Anniversary: ${dayLabelYear(space.effectiveAnniversary)}');
      buf.writeln('\nNotes (${ns.length}):');
      for (final n in ns) {
        buf.writeln('- ${n.body}');
      }
      buf.writeln('\nDates (${ds.length}):');
      for (final d in ds) {
        buf.writeln('- ${d.title} (${dayLabelYear(d.day)})');
      }
      buf.writeln('\nPiles (${ps.length}):');
      for (final p in ps) {
        buf.writeln('- ${p.title}');
      }
      await SharePlus.instance
          .share(ShareParams(text: buf.toString()));
    } catch (e) {
      if (!mounted) return;
      showKawaiiToast(context, userMessage(e),
          kind: KawaiiAlertKind.danger);
    } finally {
      if (mounted) setState(() => _exporting = false);
    }
  }

  Future<void> _editAnniversary() async {
    final space = widget.space;
    if (space == null || _savingAnniversary) return;
    final initial = space.effectiveAnniversary;
    final picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime(2000),
      lastDate: DateTime.now().add(const Duration(days: 365 * 5)),
    );
    if (picked == null || !mounted) return;
    setState(() => _savingAnniversary = true);
    try {
      await _spaces.updateAnniversary(space.id, picked);
      widget.onSpaceChanged?.call();
      if (!mounted) return;
      showKawaiiToast(context, 'Anniversary updated to ${dayLabelYear(picked)}',
          kind: KawaiiAlertKind.success);
    } catch (e) {
      if (!mounted) return;
      showKawaiiToast(context, userMessage(e),
          kind: KawaiiAlertKind.danger);
    } finally {
      if (mounted) setState(() => _savingAnniversary = false);
    }
  }

  Future<void> _editProfile() async {
    final saved = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetCtx) => Padding(
        padding: EdgeInsets.fromLTRB(
            16, 16, 16, 16 + MediaQuery.of(sheetCtx).viewInsets.bottom),
        child: _EditProfileSheet(
          initial: _myName,
          email: _auth.currentEmail,
        ),
      ),
    );
    if (saved == null || !mounted) return;
    final next = saved.trim();
    if (next.isEmpty || next == _myName || _savingProfile) return;
    setState(() => _savingProfile = true);
    try {
      await _spaces.ensureProfile(username: next);
      await _loadMembers();
      if (!mounted) return;
      showKawaiiToast(context, 'Username updated',
          kind: KawaiiAlertKind.success);
    } catch (e) {
      if (!mounted) return;
      showKawaiiToast(context, 'Could not save — ${userMessage(e)}',
          kind: KawaiiAlertKind.danger);
    } finally {
      if (mounted) setState(() => _savingProfile = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: EdgeInsets.fromLTRB(20, 12, 20, Kawaii.tabBottom(context)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _ourspaceCard(),
          const SizedBox(height: 12),
          _statRow(),
          const SizedBox(height: 18),
          const KawaiiSectionTitle('Settings', trailing: KawaiiDoodles()),
          KawaiiCard(
            color: Kawaii.cardOf(context),
            padding: EdgeInsets.zero,
            child: Column(children: [
              _row(Icons.person_rounded, 'Edit profile', Kawaii.peach,
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Flexible(
                        child: Text('@$_myName',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: Theme.of(context).textTheme.bodySmall?.copyWith(fontWeight: FontWeight.w700)),
                      ),
                      const SizedBox(width: 6),
                      Icon(Icons.arrow_forward_ios_rounded, size: 14, color: Kawaii.mutedOf(context)),
                    ],
                  ),
                  onTap: _savingProfile ? null : _editProfile),
              _div(),
              _row(
                Icons.cake_rounded,
                _savingAnniversary ? 'Saving date…' : 'Anniversary date',
                Kawaii.bubble,
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Flexible(
                      child: Text(
                        widget.space == null
                            ? 'pair first'
                            : dayLabelYear(widget.space!.effectiveAnniversary),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context)
                            .textTheme
                            .bodySmall
                            ?.copyWith(fontWeight: FontWeight.w700),
                      ),
                    ),
                    const SizedBox(width: 6),
                    Icon(Icons.arrow_forward_ios_rounded,
                        size: 14, color: Kawaii.mutedOf(context)),
                  ],
                ),
                onTap: widget.space == null || _savingAnniversary
                    ? null
                    : _editAnniversary,
              ),
              _div(),
              _row(Icons.notifications_rounded, 'Sweet reminders', Kawaii.peach,
                  trailing: _stickerSwitch(
                      value: notif,
                      label: 'Sweet reminders',
                      onChanged: (v) async {
                        setState(() => notif = v);
                        await KawaiiPrefs.saveNotif(v);
                        if (v) {
                          if (await Push.ensurePermission()) {
                            await Push.registerToken();
                          } else {
                            if (!context.mounted) return;
                            setState(() => notif = false);
                            await KawaiiPrefs.saveNotif(false);
                            if (!context.mounted) return;
                            showKawaiiToast(context,
                                'Notifications blocked — allow them in system settings.',
                                kind: KawaiiAlertKind.warning);
                          }
                        } else {
                          await Push.unregisterToken();
                        }
                      })),
              _div(),
              ValueListenableBuilder<ThemeMode>(
                valueListenable: Kawaii.themeMode,
                builder: (context, mode, _) {
                  final darkOn = mode == ThemeMode.dark;
                  return _row(Icons.dark_mode_rounded, 'Night sticker mode',
                      Kawaii.sky,
                      trailing: _stickerSwitch(
                          value: darkOn,
                          label: 'Night sticker mode',
                          onChanged: (v) => Kawaii.themeMode.value =
                              v ? ThemeMode.dark : ThemeMode.light));
                },
              ),
              _div(),
              _row(Icons.lock_rounded, 'Pair code & privacy', Kawaii.sunny,
                  onTap: () => Navigator.of(context).push(MaterialPageRoute(
                      builder: (_) => const PairingPage()))),
              _div(),
              _row(
                  Icons.file_download_rounded,
                  _exporting ? 'Exporting…' : 'Export scrapbook',
                  Kawaii.mint,
                  onTap: _exporting ? null : _export),
              _div(),
              _row(
                  Icons.system_update_rounded,
                  _checkingUpdate ? 'Checking…' : 'Check for update',
                  Kawaii.sunny,
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (_version != null)
                        Text('v$_version',
                            style: Theme.of(context).textTheme.bodySmall?.copyWith(fontWeight: FontWeight.w700)),
                      if (_version != null) const SizedBox(width: 6),
                      if (_checkingUpdate)
                        const SizedBox(
                          width: 14,
                          height: 14,
                          child:
                              CircularProgressIndicator(strokeWidth: 2),
                        )
                      else
                        Icon(Icons.arrow_forward_ios_rounded,
                            size: 14, color: Kawaii.mutedOf(context)),
                    ],
                  ),
                  onTap: _checkingUpdate ? null : _manualCheckUpdate),
              _div(),
              _row(
                  Icons.cleaning_services_rounded,
                  _clearingCache ? 'Clearing…' : 'Clear cache',
                  Kawaii.bubble,
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (_cacheLabel != null)
                        Text(_cacheLabel!,
                            style: Theme.of(context).textTheme.bodySmall?.copyWith(fontWeight: FontWeight.w700)),
                      if (_cacheLabel != null) const SizedBox(width: 6),
                      if (_clearingCache)
                        const SizedBox(
                          width: 14,
                          height: 14,
                          child:
                              CircularProgressIndicator(strokeWidth: 2),
                        )
                      else
                        Icon(Icons.arrow_forward_ios_rounded,
                            size: 14, color: Kawaii.mutedOf(context)),
                    ],
                  ),
                  onTap: _clearingCache ? null : _clearCache),
            ]),
          ),
          const SizedBox(height: 16),
          KawaiiCard(
            sticker: false,
            color: Kawaii.pinkSubtle,
            padding: EdgeInsets.zero,
            child: KawaiiPolkaBg(
              dot: Kawaii.bubble,
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(children: [
                      const KawaiiStickerCluster(
                        main: Icons.heart_broken_rounded,
                        mainBg: Kawaii.bubble,
                      ),
                      const SizedBox(width: 4),
                      Expanded(
                          child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: const [
                            Text('Need space?',
                                style: TextStyle(
                                    fontFamily: Kawaii.displayFamily,
                                    fontWeight: FontWeight.w800,
                                    fontSize: 15,
                                    color: Kawaii.ink)),
                            Text('Log out or leave this device.',
                                style: TextStyle(
                                    fontFamily: Kawaii.displayFamily,
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                    color: Kawaii.ink)),
                          ])),
                      const KawaiiSparkle(size: 18),
                    ]),
                    const SizedBox(height: 8),
                    const Row(
                      children: [
                        KawaiiDoodles(),
                        Spacer(),
                      ],
                    ),
                    const SizedBox(height: 12),
                    KawaiiButton(
                      label: _leaving ? 'Leaving…' : 'Log out',
                      icon: Icons.logout_rounded,
                      color: KawaiiBtnColor.white,
                      expanded: false,
                      onTap: _leaving ? null : _logout,
                    ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: 16),
          const KawaiiDotDivider(count: 10),
          const SizedBox(height: 12),
          Center(
              child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              KawaiiAppMascot(size: 56),
              SizedBox(height: 8),
              Row(mainAxisSize: MainAxisSize.min, children: [
                Text('made with ',
                    style: TextStyle(
                        fontFamily: Kawaii.displayFamily,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: Kawaii.mutedOf(context))),
                Icon(Icons.favorite_rounded,
                    size: 14, color: Kawaii.bubble),
                Text(' in ourspace',
                    style: TextStyle(
                        fontFamily: Kawaii.displayFamily,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: Kawaii.mutedOf(context))),
              ]),
            ],
          )),
        ],
      ),
    );
  }

  /// Informative Ourspace card: no edit buttons, read-only pair info.
  Widget _ourspaceCard() {
    final space = widget.space;
    final paired = space != null;
    final since = _anniversary;
    final dayText = since == null
        ? 'solo • pair to sync'
        : 'paired • day ${daysSince(since) + 1}';
    final anniText = since == null
        ? 'no anniversary yet'
        : dayLabelYear(since);
    return KawaiiCard(
      color: Kawaii.sunnySubtle,
      padding: EdgeInsets.zero,
      child: KawaiiPolkaBg(
        dot: Kawaii.sunny,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(children: [
                KawaiiAvatar(text: _meInitial, bg: Kawaii.peach, size: 56),
                const SizedBox(width: 8),
                KawaiiAvatar(
                    text: paired ? _secondInitial : '?',
                    bg: paired ? Kawaii.sky : Colors.white,
                    size: 56),
                const SizedBox(width: 14),
                Expanded(
                    child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                      Text(space?.name ?? 'Just you for now',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                              fontFamily: Kawaii.displayFamily,
                              fontWeight: FontWeight.w900,
                              fontSize: 18,
                              color: Kawaii.ink)),
                      Text(dayText,
                          style: TextStyle(
                              fontFamily: Kawaii.displayFamily,
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              color: Kawaii.ink.withValues(alpha: 0.8))),
                      if (_pairNames != null)
                        Text(_pairNames!,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                                fontFamily: Kawaii.displayFamily,
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: Kawaii.ink.withValues(alpha: 0.7))),
                    ])),
              ]),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 12, vertical: 10),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                      color: Kawaii.ink, width: Kawaii.paperBorderW),
                ),
                child: Row(
                  children: [
                    const KawaiiSparkle(size: 18),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        paired
                            ? 'together since $anniText'
                            : 'pair to start your day count',
                        style: const TextStyle(
                          fontFamily: Kawaii.displayFamily,
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: Kawaii.ink,
                        ),
                      ),
                    ),
                    KawaiiPill(
                        label: paired ? 'paired' : 'solo',
                        color: Kawaii.mint,
                        icon: Icons.favorite_rounded),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _statRow() {
    final spaceId = widget.space?.id;
    if (spaceId == null) return const SizedBox.shrink();
    Widget tile(
        String label, IconData icon, Color bg, Stream<int> count, int i) {
      return Expanded(
        child: Transform.rotate(
          angle: kawaiiDecoTilt(i),
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 12),
            decoration: BoxDecoration(
              color: bg.withValues(alpha: 0.35),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                  color: Kawaii.edgeOf(context),
                  width: Kawaii.paperBorderW),
            ),
            child: Column(
              children: [
                KawaiiIcon(icon: icon, bg: bg, size: 40, iconSize: 20),
                const SizedBox(height: 6),
                StreamBuilder<int>(
                  stream: count,
                  builder: (context, snap) => Text(
                    '${snap.data ?? 0}',
                    style: const TextStyle(
                      fontFamily: Kawaii.displayFamily,
                      fontWeight: FontWeight.w900,
                      fontSize: 16,
                    ),
                  ),
                ),
                Text(label,
                    style: TextStyle(
                        fontFamily: Kawaii.displayFamily,
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: Kawaii.mutedOf(context))),
              ],
            ),
          ),
        ),
      );
    }

    Stream<int> notesCount() async* {
      final repo = widget.notesRepo;
      if (repo == null) {
        yield 0;
        return;
      }
      await for (final l in repo.watch(spaceId)) {
        yield l.length;
      }
    }

    Stream<int> datesCount() async* {
      final repo = widget.datesRepo;
      if (repo == null) {
        yield 0;
        return;
      }
      await for (final l in repo.watch(spaceId)) {
        yield l.length;
      }
    }

    Stream<int> pilesCount() async* {
      final repo = widget.pilesRepo;
      if (repo == null) {
        yield 0;
        return;
      }
      await for (final l in repo.watch(spaceId)) {
        yield l.length;
      }
    }

    return Row(
      children: [
        tile('notes', Icons.edit_note_rounded, Kawaii.peach, notesCount(), 0),
        const SizedBox(width: 10),
        tile('dates', Icons.calendar_month_rounded, Kawaii.sunny,
            datesCount(), 1),
        const SizedBox(width: 10),
        tile(
            'piles', Icons.photo_library_rounded, Kawaii.sky, pilesCount(), 2),
      ],
    );
  }

  Widget _row(IconData icon, String t, Color c,
      {Widget? trailing, VoidCallback? onTap}) {
    final edge = Kawaii.edgeOf(context);
    final row = Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      child: Row(children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
              color: c,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: edge, width: Kawaii.paperBorderW)),
          child: Icon(icon, size: 18, color: Kawaii.ink),
        ),
        const SizedBox(width: 12),
        Expanded(
            child: Text(t,
                style: Theme.of(context).textTheme.titleSmall)),
        trailing ?? Icon(Icons.arrow_forward_ios_rounded, size: 14, color: Kawaii.mutedOf(context)),
      ]),
    );
    if (onTap == null) return row;
    return Semantics(
      button: true,
      label: t,
      child: GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: row,
      ),
    );
  }

  Widget _div() =>
      Container(height: 1.5, color: Kawaii.lineOf(context));

  Widget _stickerSwitch(
      {required bool value,
      required String label,
      required ValueChanged<bool> onChanged}) {
    final edge = Kawaii.edgeOf(context);
    return Semantics(
      label: label,
      toggled: value,
      child: Switch(
        value: value,
        onChanged: onChanged,
        activeTrackColor: Kawaii.mint,
        inactiveTrackColor: Kawaii.cardOf(context),
        inactiveThumbColor: Colors.white,
        trackOutlineColor: WidgetStateProperty.all(edge),
        trackOutlineWidth: WidgetStateProperty.all(2.0),
      ),
    );
  }
}

class _EditProfileSheet extends StatefulWidget {
  final String initial;
  final String? email;
  const _EditProfileSheet({required this.initial, this.email});

  @override
  State<_EditProfileSheet> createState() => _EditProfileSheetState();
}

class _EditProfileSheetState extends State<_EditProfileSheet> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _ctrl =
      TextEditingController(text: widget.initial);

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return KawaiiCard(
      color: Kawaii.cardOf(context),
      child: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('Edit username',
                style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 4),
            Text(
              widget.email ?? 'solo demo account',
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const SizedBox(height: 14),
            KawaiiInput(
              hint: 'e.g. alex_02',
              label: 'Username',
              controller: _ctrl,
              prefix: Icons.person_rounded,
              validator: (v) {
                final t = (v ?? '').trim();
                if (t.isEmpty) return 'Pick a username';
                if (t.length > 40) return 'Max 40 characters';
                return null;
              },
            ),
            const SizedBox(height: 16),
            KawaiiButton(
              label: 'Save username',
              icon: Icons.check_rounded,
              color: KawaiiBtnColor.peach,
              onTap: () {
                if (_formKey.currentState?.validate() ?? false) {
                  Navigator.of(context).pop(_ctrl.text.trim());
                }
              },
            ),
          ],
        ),
      ),
    );
  }
}
