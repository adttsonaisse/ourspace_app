import 'package:flutter/material.dart';

import '../data/format.dart';
import '../data/models/content.dart';
import '../data/models/space.dart';
import '../data/photo_store.dart';
import '../data/repos.dart';
import '../theme/kawaii.dart';
import '../widgets/kawaii.dart';
import '../widgets/kawaii_deco.dart';
import '../widgets/kawaii_fab.dart';

/// v2.0.1 Home: hero pair card + Today in ourspace sections.
/// Layout follows assets/tmp/wireframe home.png:
/// hero, 1 large highlight, 2 medium shortcuts, 4 mini quick actions,
/// 1 full-width CTA pill.
class HomeTab extends StatelessWidget {
  final Space? space;
  final List<MemberProfile> members;
  final String myUid;
  final NotesRepo notesRepo;
  final DatesRepo datesRepo;
  final PilesRepo pilesRepo;
  final PhotoStore photoStore;
  final ValueChanged<int>? onJump;
  final ValueChanged<CreateKind>? onCreate;

  const HomeTab({
    super.key,
    required this.space,
    this.members = const [],
    this.myUid = kDemoUid,
    required this.notesRepo,
    required this.datesRepo,
    required this.pilesRepo,
    required this.photoStore,
    this.onJump,
    this.onCreate,
  });

  String get _spaceId => space?.id ?? kDemoSpaceId;

  String get _meName {
    final me = members.where((m) => m.userId == myUid);
    if (me.isNotEmpty && me.first.username.trim().isNotEmpty) {
      return me.first.username.trim();
    }
    return 'You';
  }

  String? get _partnerName {
    final others = members.where((m) => m.userId != myUid).toList();
    if (others.isEmpty) return null;
    final n = others.first.username.trim();
    return n.isEmpty ? null : n;
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: EdgeInsets.fromLTRB(20, 12, 20, Kawaii.tabBottom(context)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _heroCard(context),
          const SizedBox(height: 18),
          const KawaiiSectionTitle(
            'Today in ourspace',
            trailing: KawaiiDoodles(),
          ),
          _largeHighlight(context),
          const SizedBox(height: 12),
          _mediumRow(context),
          const SizedBox(height: 14),
          const KawaiiDotDivider(),
          const SizedBox(height: 14),
          _quickActions(context),
          const SizedBox(height: 16),
          KawaiiButton(
            label: 'Drop a sweet note',
            icon: Icons.favorite_rounded,
            color: KawaiiBtnColor.peach,
            onTap: onCreate == null ? null : () => onCreate!(CreateKind.note),
          ),
        ],
      ),
    );
  }

  Widget _heroCard(BuildContext context) {
    final anni = space?.effectiveAnniversary;
    final dayPill = anni == null
        ? 'just us two'
        : 'day ${daysSince(anni) + 1} together';
    final anniLabel =
        anni == null ? 'set your anniversary in you' : dayLabelYear(anni);
    return KawaiiCard(
      color: Kawaii.peach,
      padding: EdgeInsets.zero,
      child: KawaiiPolkaBg(
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  KawaiiPill(label: dayPill, color: Colors.white),
                  const Spacer(),
                  StreamBuilder<List<Note>>(
                    stream: notesRepo.watch(_spaceId),
                    builder: (context, snap) {
                      final n = snap.data?.length ?? 0;
                      return KawaiiPill(
                        label: '$n notes',
                        color: Kawaii.sunny,
                        icon: Icons.edit_note_rounded,
                      );
                    },
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Text(
                greeting(),
                style: const TextStyle(
                  fontFamily: Kawaii.displayFamily,
                  fontWeight: FontWeight.w600,
                  fontSize: 14,
                  color: Kawaii.ink,
                ),
              ),
              const SizedBox(height: 2),
              _pairProfiles(),
              const SizedBox(height: 8),
              Row(
                children: [
                  const Icon(Icons.cake_rounded,
                      size: 16, color: Kawaii.ink),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      anniLabel,
                      style: TextStyle(
                        fontFamily: Kawaii.displayFamily,
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: Kawaii.ink.withValues(alpha: 0.8),
                      ),
                    ),
                  ),
                  const KawaiiSparkle(size: 18),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Two profiles side by side with a heart in the middle:
  /// [avatar + name] ❤ [avatar + name]. Shows a waiting slot when
  /// the partner hasn't joined yet.
  Widget _pairProfiles() {
    final me = _meName;
    final partner = _partnerName;
    return Row(
      children: [
        Expanded(child: _profileCell(name: me, bg: Kawaii.peach)),
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: 6),
          child: Icon(Icons.favorite_rounded, size: 26, color: Kawaii.ink),
        ),
        Expanded(
          child: partner == null
              ? _profileCell(
                  name: 'Waiting…',
                  bg: Colors.white,
                  initialOverride: '?',
                  muted: true,
                )
              : _profileCell(name: partner, bg: Kawaii.sky),
        ),
      ],
    );
  }

  Widget _profileCell({
    required String name,
    required Color bg,
    String? initialOverride,
    bool muted = false,
  }) {
    final initial =
        initialOverride ?? avatarInitial(name, fallback: '?');
    return Semantics(
      label: name,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          KawaiiAvatar(text: initial, bg: bg, size: 56),
          const SizedBox(height: 6),
          Text(
            name,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.w900,
              fontFamily: Kawaii.displayFamily,
              color: muted
                  ? Kawaii.ink.withValues(alpha: 0.55)
                  : Kawaii.ink,
            ),
          ),
        ],
      ),
    );
  }

  Widget _largeHighlight(BuildContext context) {
    return StreamBuilder<List<DatePlan>>(
      stream: datesRepo.watch(_spaceId),
      builder: (context, dsnap) {
        final all = dsnap.data ?? [];
        final now = DateTime.now();
        final day0 = DateTime(now.year, now.month, now.day);
        final upcoming = all
            .where((p) => !DateTime(p.day.year, p.day.month, p.day.day)
                .isBefore(day0))
            .toList();
        final next = upcoming.isEmpty ? null : upcoming.first;
        if (next != null) return _nextDateCard(context, next);
        return StreamBuilder<List<Note>>(
          stream: notesRepo.watch(_spaceId),
          builder: (context, nsnap) {
            final notes = nsnap.data ?? [];
            if (notes.isEmpty) {
              return KawaiiCard(
                color: Kawaii.mintSubtle,
                child: Row(
                  children: [
                    const KawaiiStickerCluster(
                      main: Icons.mail_rounded,
                      mainBg: Kawaii.mint,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Fresh page, you two',
                              style: Theme.of(context).textTheme.titleSmall),
                          const SizedBox(height: 2),
                          Text('Pin your first note or plan a date.',
                              style: Theme.of(context).textTheme.bodySmall),
                        ],
                      ),
                    ),
                  ],
                ),
              );
            }
            final n = notes.first;
            return KawaiiCard(
              color: Kawaii.bubble,
              onTap: onJump == null ? null : () => onJump!(1),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Row(
                    children: [
                      KawaiiPill(
                        label: 'latest sweet note',
                        color: Colors.white,
                        icon: Icons.mail_rounded,
                      ),
                      Spacer(),
                      KawaiiSparkle(size: 20, color: Colors.white),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Text(
                    '\u201c${n.body}\u201d',
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontFamily: Kawaii.displayFamily,
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                      color: Kawaii.ink,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    dayLabel(n.createdAt),
                    style: TextStyle(
                      fontFamily: Kawaii.displayFamily,
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: Kawaii.ink.withValues(alpha: 0.8),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Widget _nextDateCard(BuildContext context, DatePlan p) {
    final detail = [
      dayLabelYear(p.day),
      if (p.place.isNotEmpty) p.place,
      if (p.note.isNotEmpty) p.note,
    ].join(' \u2022 ');
    return KawaiiCard(
      color: Kawaii.sky,
      onTap: onJump == null ? null : () => onJump!(3),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              KawaiiPill(
                label: 'Next up \u2022 ${dayLabel(p.day)}',
                color: Colors.white,
              ),
              const Spacer(),
              const KawaiiIcon(
                icon: Icons.wb_sunny_rounded,
                bg: Colors.white,
                size: 40,
                iconSize: 22,
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            p.title,
            style: const TextStyle(
              fontFamily: Kawaii.displayFamily,
              fontSize: 22,
              fontWeight: FontWeight.w900,
              color: Kawaii.ink,
            ),
          ),
          if (detail.isNotEmpty) ...[
            const SizedBox(height: 2),
            Text(
              detail,
              style: const TextStyle(
                fontFamily: Kawaii.displayFamily,
                color: Kawaii.ink,
                fontSize: 14,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
          const SizedBox(height: 12),
          Row(
            children: [
              const KawaiiDoodles(),
              const Spacer(),
              if (onCreate != null)
                GestureDetector(
                  onTap: () => onCreate!(CreateKind.date),
                  behavior: HitTestBehavior.opaque,
                  child: const KawaiiPill(
                    label: 'plan another',
                    color: Colors.white,
                    icon: Icons.add_rounded,
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _mediumRow(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: StreamBuilder<List<DatePlan>>(
            stream: datesRepo.watch(_spaceId),
            builder: (context, snap) {
              final n = snap.data?.length ?? 0;
              return KawaiiCard(
                color: Kawaii.skySubtle,
                sticker: false,
                padding: const EdgeInsets.all(14),
                onTap: onJump == null ? null : () => onJump!(3),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const KawaiiIcon(
                      icon: Icons.calendar_month_rounded,
                      bg: Kawaii.sky,
                      size: 40,
                      iconSize: 20,
                    ),
                    const SizedBox(height: 10),
                    const Text(
                      'Date plans',
                      style: TextStyle(
                        fontFamily: Kawaii.displayFamily,
                        fontWeight: FontWeight.w800,
                        fontSize: 15,
                        color: Kawaii.ink,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      n == 0 ? 'plan the first one' : '$n upcoming',
                      style: TextStyle(
                        fontFamily: Kawaii.displayFamily,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: Kawaii.ink.withValues(alpha: 0.7),
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: StreamBuilder<List<Pile>>(
            stream: pilesRepo.watch(_spaceId),
            builder: (context, snap) {
              final n = snap.data?.length ?? 0;
              return KawaiiCard(
                color: Kawaii.sunnySubtle,
                sticker: false,
                padding: const EdgeInsets.all(14),
                onTap: onJump == null ? null : () => onJump!(2),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const KawaiiIcon(
                      icon: Icons.photo_library_rounded,
                      bg: Kawaii.sunny,
                      size: 40,
                      iconSize: 20,
                    ),
                    const SizedBox(height: 10),
                    const Text(
                      'Photo piles',
                      style: TextStyle(
                        fontFamily: Kawaii.displayFamily,
                        fontWeight: FontWeight.w800,
                        fontSize: 15,
                        color: Kawaii.ink,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      n == 0 ? 'shared moments' : '$n piles',
                      style: TextStyle(
                        fontFamily: Kawaii.displayFamily,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: Kawaii.ink.withValues(alpha: 0.7),
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _quickActions(BuildContext context) {
    final actions = [
      (Icons.edit_note_rounded, 'Note', CreateKind.note, 0),
      (Icons.calendar_month_rounded, 'Date', CreateKind.date, 1),
      (Icons.photo_library_rounded, 'Pile', CreateKind.pile, 2),
      (Icons.favorite_rounded, 'You', null, 3),
    ];
    return Row(
      children: [
        for (var i = 0; i < actions.length; i++) ...[
          if (i > 0) const SizedBox(width: 10),
          Expanded(child: _quickTile(context, actions[i].$1, actions[i].$2, actions[i].$3, actions[i].$4)),
        ],
      ],
    );
  }

  Widget _quickTile(
    BuildContext context,
    IconData icon,
    String label,
    CreateKind? kind,
    int i,
  ) {
    final bg = kawaiiDecoPick(i);
    void go() {
      if (kind != null) {
        if (onCreate != null) onCreate!(kind);
      } else {
        if (onJump != null) onJump!(4);
      }
    }

    return Semantics(
      button: true,
      label: label == 'You' ? 'Open you' : 'Create $label',
      child: GestureDetector(
        onTap: go,
        behavior: HitTestBehavior.opaque,
        child: Transform.rotate(
          angle: kawaiiDecoTilt(i),
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 14),
            decoration: BoxDecoration(
              color: bg,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(
                color: Kawaii.edgeOf(context),
                width: Kawaii.paperBorderW,
              ),
            ),
            child: Column(
              children: [
                Icon(icon, size: 22, color: Kawaii.onFill(bg)),
                const SizedBox(height: 4),
                Text(
                  label,
                  style: TextStyle(
                    fontFamily: Kawaii.displayFamily,
                    fontWeight: FontWeight.w800,
                    fontSize: 12,
                    color: Kawaii.onFill(bg),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
