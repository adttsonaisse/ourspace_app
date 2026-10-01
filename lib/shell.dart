import 'package:flutter/material.dart';
import 'data/auth_repo.dart';
import 'data/content_repos.dart';
import 'data/models/space.dart';
import 'data/photo_store.dart';
import 'data/repos.dart';
import 'data/space_repo.dart';
import 'data/supa.dart';
import 'theme/kawaii.dart';
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
