import 'package:flutter/material.dart';
import '../data/backend_errors.dart';
import '../data/format.dart';
import '../data/models/content.dart';
import '../data/models/space.dart';
import '../data/repos.dart';
import '../theme/kawaii.dart';
import '../widgets/kawaii.dart';

class HomeTab extends StatefulWidget {
  final Space? space;
  final NotesRepo notesRepo;
  final RitualsRepo ritualsRepo;
  final ValueChanged<int>? onJump;
  const HomeTab(
      {super.key,
      required this.space,
      required this.notesRepo,
      required this.ritualsRepo,
      this.onJump});
  @override
  State<HomeTab> createState() => _HomeTabState();
}

class _HomeTabState extends State<HomeTab> {
  String get _spaceId => widget.space?.id ?? kDemoSpaceId;

  Future<void> _toggle(Ritual r) async {
    try {
      await widget.ritualsRepo.toggle(r.id, !r.done);
    } catch (e) {
      if (!mounted) return;
      showKawaiiToast(context, userMessage(e),
          kind: KawaiiAlertKind.danger);
    }
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: EdgeInsets.fromLTRB(20, 12, 20, Kawaii.tabBottom(context)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _heroCard(),
          const SizedBox(height: 16),
          const Text('Today in ourspace',
              style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w900,
                  fontFamily: Kawaii.displayFamily)),
          const SizedBox(height: 10),
          Row(children: [
            Expanded(
              child: KawaiiCard(
                color: Kawaii.skySubtle,
                onTap: widget.onJump == null ? null : () => widget.onJump!(3),
                child: const Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      KawaiiIcon(
                          icon: Icons.wb_sunny_rounded, bg: Kawaii.sky),
                      SizedBox(height: 8),
                      Text('Date plans',
                          style: TextStyle(fontWeight: FontWeight.w800)),
                      SizedBox(height: 2),
                      Text('Never wonder what to do',
                          style: TextStyle(
                              fontSize: 12, fontWeight: FontWeight.w600)),
                      SizedBox(height: 8),
                      KawaiiPill(label: 'open dates', color: Kawaii.sky),
                    ]),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: KawaiiCard(
                color: Kawaii.sunnySubtle,
                onTap: widget.onJump == null ? null : () => widget.onJump!(2),
                child: const Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      KawaiiIcon(
                          icon: Icons.photo_library_rounded,
                          bg: Kawaii.sunny),
                      SizedBox(height: 8),
                      Text('Photo piles',
                          style: TextStyle(fontWeight: FontWeight.w800)),
                      SizedBox(height: 2),
                      Text('Moments minus the feed',
                          style: TextStyle(
                              fontSize: 12, fontWeight: FontWeight.w600)),
                      SizedBox(height: 8),
                      KawaiiPill(label: 'view piles', color: Kawaii.sunny),
                    ]),
              ),
            ),
          ]),
          const SizedBox(height: 12),
          _ritualsCard(),
        ],
      ),
    );
  }

  Widget _heroCard() {
    final name = widget.space?.name ?? 'Our space';
    final since = widget.space?.createdAt;
    final dayPill = since == null
        ? 'just us two'
        : 'day ${daysSince(since) + 1} together';
    return KawaiiCard(
      color: Kawaii.peach,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              KawaiiPill(label: dayPill, color: Colors.white),
              const Spacer(),
              StreamBuilder<List<Note>>(
                stream: widget.notesRepo.watch(_spaceId),
                builder: (context, snap) {
                  final n = snap.data?.length ?? 0;
                  return KawaiiPill(
                      label: '$n notes',
                      color: Kawaii.sunny,
                      icon: Icons.edit_note_rounded);
                },
              ),
            ],
          ),
          const SizedBox(height: 14),
          Text(greeting(),
              style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
          Row(children: [
            Expanded(
              child: Text(name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.w900,
                      fontFamily: Kawaii.displayFamily)),
            ),
            const SizedBox(width: 6),
            const Icon(Icons.favorite_rounded,
                size: 28, color: Kawaii.bubble),
          ]),
          const SizedBox(height: 10),
          _latestNote(),
        ],
      ),
    );
  }

  Widget _latestNote() {
    return StreamBuilder<List<Note>>(
      stream: widget.notesRepo.watch(_spaceId),
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const Padding(
            padding: EdgeInsets.symmetric(vertical: 12),
            child: Center(
                child: SizedBox(
                    width: 24,
                    height: 24,
                    child: CircularProgressIndicator(strokeWidth: 3))),
          );
        }
        if (snap.hasError || (snap.data ?? []).isEmpty) {
          return GestureDetector(
            onTap:
                widget.onJump == null ? null : () => widget.onJump!(1),
            child: Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: Kawaii.ink, width: 2.5),
              ),
              child: const Row(children: [
                KawaiiIcon(
                    icon: Icons.edit_note_rounded,
                    bg: Kawaii.peach,
                    size: 46,
                    iconSize: 22),
                SizedBox(width: 10),
                Expanded(
                    child: Text('No notes yet — tap + to drop the first one',
                        style: TextStyle(
                            fontWeight: FontWeight.w600, fontSize: 14))),
              ]),
            ),
          );
        }
        final n = snap.data!.first;
        return GestureDetector(
          onTap: widget.onJump == null ? null : () => widget.onJump!(1),
          child: Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: Kawaii.ink, width: 2.5),
            ),
            child: Row(children: [
              const KawaiiIcon(
                  icon: Icons.mail_rounded,
                  bg: Kawaii.peach,
                  size: 46,
                  iconSize: 22),
              const SizedBox(width: 10),
              Expanded(
                  child: Text('“${n.body}” — ${dayLabel(n.createdAt)}',
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                          fontWeight: FontWeight.w600, fontSize: 14))),
            ]),
          ),
        );
      },
    );
  }

  Widget _ritualsCard() {
    return KawaiiCard(
      color: Kawaii.cardOf(context),
      child: StreamBuilder<List<Ritual>>(
        stream: widget.ritualsRepo.watch(_spaceId),
        builder: (context, snap) {
          if (snap.connectionState == ConnectionState.waiting) {
            return const Padding(
              padding: EdgeInsets.symmetric(vertical: 16),
              child: Center(child: CircularProgressIndicator()),
            );
          }
          if (snap.hasError) {
            return KawaiiAlert(
              title: 'Could not load rituals',
              message: userMessage(snap.error!),
              kind: KawaiiAlertKind.danger,
              actionLabel: 'Retry',
              onAction: () => setState(() {}),
            );
          }
          final rituals = snap.data ?? [];
          final done = rituals.where((r) => r.done).length;
          return Column(children: [
            Row(
              children: [
                const Text('Weekly rituals',
                    style: TextStyle(
                        fontWeight: FontWeight.w900,
                        fontFamily: Kawaii.displayFamily,
                        fontSize: 16)),
                const Spacer(),
                KawaiiPill(
                    label: rituals.isEmpty
                        ? 'fresh page'
                        : '$done/${rituals.length} done',
                    color: Kawaii.mint),
              ],
            ),
            const SizedBox(height: 12),
            if (rituals.isEmpty)
              const Text(
                  'No rituals yet — small repeats keep couples close. Add them from your next update.',
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500)),
            ...rituals.map(_ritual),
          ]);
        },
      ),
    );
  }

  Widget _ritual(Ritual r) {
    final color =
        Kawaii.notePalette[r.colorIdx % Kawaii.notePalette.length];
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Semantics(
        button: true,
        toggled: r.done,
        label: r.title,
        child: GestureDetector(
          onTap: () => _toggle(r),
          behavior: HitTestBehavior.opaque,
          child: Row(children: [
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: r.done ? color : Kawaii.cardOf(context),
                borderRadius: BorderRadius.circular(10),
                border:
                    Border.all(color: Kawaii.edgeOf(context), width: 2.5),
              ),
              child: r.done
                  ? const Icon(Icons.check_rounded, size: 18)
                  : null,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(r.title,
                  style: TextStyle(
                      fontWeight: FontWeight.w700,
                      decoration:
                          r.done ? TextDecoration.lineThrough : null)),
            ),
          ]),
        ),
      ),
    );
  }
}
