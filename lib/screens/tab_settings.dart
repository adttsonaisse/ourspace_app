import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:share_plus/share_plus.dart';
import '../data/auth_repo.dart';
import '../data/format.dart';
import '../data/models/space.dart';
import '../data/repos.dart';
import '../data/space_repo.dart';
import '../theme/kawaii.dart';
import '../theme/prefs.dart';
import '../widgets/kawaii.dart';
import 'auth_get_started.dart';
import 'auth_pairing.dart';

class SettingsTab extends StatefulWidget {
  final AuthRepo? auth;
  final SpaceRepo? spaceRepo;
  final Space? space;
  final NotesRepo? notesRepo;
  final DatesRepo? datesRepo;
  final RitualsRepo? ritualsRepo;
  const SettingsTab(
      {super.key,
      this.auth,
      this.spaceRepo,
      this.space,
      this.notesRepo,
      this.datesRepo,
      this.ritualsRepo});
  @override
  State<SettingsTab> createState() => _SettingsTabState();
}

class _SettingsTabState extends State<SettingsTab> {
  bool notif = true;
  bool _leaving = false;
  bool _exporting = false;
  late final AuthRepo _auth;
  late final SpaceRepo _spaces;
  List<MemberProfile> _members = [];

  String get _uid {
    final id = _auth.currentUserId;
    if (id != null) return id;
    return 'demo-user';
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

  @override
  void initState() {
    super.initState();
    _auth = widget.auth ?? resolveAuthRepo();
    _spaces = widget.spaceRepo ?? resolveSpaceRepo();
    KawaiiPrefs.loadNotif().then((v) {
      if (mounted) setState(() => notif = v);
    });
    _loadMembers();
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

  Future<void> _logout() async {
    if (_leaving) return;
    setState(() => _leaving = true);
    try {
      await _auth.signOut();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(friendlyAuthError(e))),
      );
      return;
    } finally {
      if (mounted) setState(() => _leaving = false);
    }
    if (!mounted) return;
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const GetStartedPage()),
      (_) => false,
    );
  }

  Future<void> _export() async {
    final space = widget.space;
    final notes = widget.notesRepo;
    final dates = widget.datesRepo;
    final rituals = widget.ritualsRepo;
    if (space == null || notes == null || dates == null || rituals == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Pair first — then export your space')),
      );
      return;
    }
    if (_exporting) return;
    setState(() => _exporting = true);
    try {
      final ns = await notes.list(space.id);
      final ds = await dates.list(space.id);
      final rs = await rituals.list(space.id);
      final buf = StringBuffer('${space.name} — ourspace export\n');
      buf.writeln('\nNotes (${ns.length}):');
      for (final n in ns) {
        buf.writeln('- ${n.body}');
      }
      buf.writeln('\nDates (${ds.length}):');
      for (final d in ds) {
        buf.writeln('- ${d.title} (${dayLabelYear(d.day)})');
      }
      buf.writeln('\nRituals (${rs.length}):');
      for (final r in rs) {
        buf.writeln('- ${r.done ? '[x]' : '[ ]'} ${r.title}');
      }
      await SharePlus.instance
          .share(ShareParams(text: buf.toString()));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString().replaceFirst('StateError: ', ''))),
      );
    } finally {
      if (mounted) setState(() => _exporting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final space = widget.space;
    final paired = space != null;
    final since = space?.createdAt;
    return SingleChildScrollView(
      padding: EdgeInsets.fromLTRB(20, 12, 20, Kawaii.tabBottom(context)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          KawaiiCard(
            color: Kawaii.sunnySubtle,
            child: Row(children: [
              KawaiiAvatar(text: _meInitial, bg: Kawaii.peach, size: 60),
              const SizedBox(width: 6),
              KawaiiAvatar(
                  text: paired ? _secondInitial : '?',
                  bg: paired ? Kawaii.sky : Colors.white,
                  size: 60),
              const SizedBox(width: 14),
              Expanded(
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                    Text(space?.name ?? 'Just you for now',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.nunito(
                            fontWeight: FontWeight.w900, fontSize: 18)),
                    Text(
                        paired
                            ? 'paired • day ${daysSince(since!) + 1}'
                            : 'solo • pair to sync',
                        style: const TextStyle(
                            fontSize: 12, fontWeight: FontWeight.w700)),
                    if (_pairNames != null)
                      Text(_pairNames!,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                              fontSize: 12, fontWeight: FontWeight.w600)),
                    const SizedBox(height: 4),
                    KawaiiPill(
                        label: paired ? 'paired' : 'solo',
                        color: Colors.white,
                        icon: Icons.favorite_rounded),
                  ])),
            ]),
          ),
          const SizedBox(height: 14),
          Text('Settings',
              style: GoogleFonts.nunito(
                  fontSize: 18, fontWeight: FontWeight.w900)),
          const SizedBox(height: 8),
          KawaiiCard(
            color: Kawaii.cardOf(context),
            padding: EdgeInsets.zero,
            child: Column(children: [
              _row(Icons.notifications_rounded, 'Sweet reminders', Kawaii.peach,
                  trailing: _stickerSwitch(
                      value: notif,
                      label: 'Sweet reminders',
                      onChanged: (v) {
                        setState(() => notif = v);
                        KawaiiPrefs.saveNotif(v);
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
            ]),
          ),
          const SizedBox(height: 12),
          KawaiiCard(
            color: Kawaii.pinkSubtle,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(children: const [
                  KawaiiIcon(
                      icon: Icons.heart_broken_rounded,
                      bg: Kawaii.bubble,
                      size: 46,
                      iconSize: 22),
                  SizedBox(width: 10),
                  Expanded(
                      child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                        Text('Need space?',
                            style: TextStyle(fontWeight: FontWeight.w800)),
                        Text('Unpair, log out, or nuke everything.',
                            style: TextStyle(fontSize: 12)),
                      ])),
                ]),
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
          const SizedBox(height: 12),
          const Center(
              child: Row(mainAxisSize: MainAxisSize.min, children: [
            Text('made with ',
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
            Icon(Icons.favorite_rounded, size: 14, color: Kawaii.bubble),
            Text(' in ourspace • kawaii-pop',
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
          ])),
        ],
      ),
    );
  }

  Widget _row(IconData icon, String t, Color c,
      {Widget? trailing, VoidCallback? onTap}) {
    final edge = Kawaii.edgeOf(context);
    final row = Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      child: Row(children: [
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
              color: c,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: edge, width: 2.5)),
          child: Icon(icon, size: 20, color: Kawaii.ink),
        ),
        const SizedBox(width: 12),
        Expanded(
            child: Text(t,
                style: const TextStyle(fontWeight: FontWeight.w700))),
        trailing ?? const Icon(Icons.arrow_forward_ios_rounded, size: 16),
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
      Container(height: 2, color: Kawaii.ink.withValues(alpha: 0.08));

  /// Sticker-styled Switch: keeps the chunky outline look but reuses the
  /// real Switch for keyboard + screen-reader semantics.
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
        trackOutlineWidth: WidgetStateProperty.all(2.5),
      ),
    );
  }
}
