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
  final DatesRepo? datesRepo;
  final ValueChanged<int>? onJump;
  const HomeTab(
      {super.key,
      required this.space,
      required this.notesRepo,
      required this.ritualsRepo,
      this.datesRepo,
      this.onJump});
  @override
  State<HomeTab> createState() => _HomeTabState();
}

class _HomeTabState extends State<HomeTab> {
  final _ritualCtrl = TextEditingController();
  bool _addingRitual = false;

  String get _spaceId => widget.space?.id ?? kDemoSpaceId;

  @override
  void dispose() {
    _ritualCtrl.dispose();
    super.dispose();
  }

  Future<void> _toggle(Ritual r) async {
    try {
      await widget.ritualsRepo.toggle(r.id, !r.done);
    } catch (e) {
      if (!mounted) return;
      showKawaiiToast(context, userMessage(e),
          kind: KawaiiAlertKind.danger);
    }
  }

  Future<void> _addRitual() async {
    final title = _ritualCtrl.text.trim();
    if (title.isEmpty || _addingRitual) return;
    setState(() => _addingRitual = true);
    try {
      await widget.ritualsRepo.create(
        spaceId: _spaceId,
        title: title,
        colorIdx: DateTime.now().millisecond % Kawaii.notePalette.length,
      );
      _ritualCtrl.clear();
      if (!mounted) return;
      showKawaiiToast(context, 'Ritual added', kind: KawaiiAlertKind.success);
    } catch (e) {
      if (!mounted) return;
      showKawaiiToast(context, userMessage(e), kind: KawaiiAlertKind.danger);
    } finally {
      if (mounted) setState(() => _addingRitual = false);
    }
  }

  Future<void> _removeRitual(Ritual r) async {
    final ok = await confirmKawaii(
      context,
      title: 'Remove ritual?',
      message: '“${r.title}” will be removed from your weekly list.',
      confirmLabel: 'Remove',
    );
    if (!ok) return;
    try {
      await widget.ritualsRepo.remove(r.id);
      if (!mounted) return;
      showKawaiiToast(context, 'Ritual removed', kind: KawaiiAlertKind.info);
    } catch (e) {
      if (!mounted) return;
      showKawaiiToast(context, userMessage(e), kind: KawaiiAlertKind.danger);
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
          const SizedBox(height: 18),
          const KawaiiSectionTitle('Today in ourspace'),
          Row(children: [
            Expanded(
              child: KawaiiCard(
                color: Kawaii.skySubtle,
                sticker: false,
                padding: const EdgeInsets.all(14),
                onTap: widget.onJump == null ? null : () => widget.onJump!(3),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const KawaiiIcon(
                        icon: Icons.calendar_month_rounded, bg: Kawaii.sky, size: 40, iconSize: 20),
                    const SizedBox(height: 10),
                    const Text('Date plans',
                        style: TextStyle(
                            fontFamily: Kawaii.displayFamily,
                            fontWeight: FontWeight.w800,
                            fontSize: 15,
                            color: Kawaii.ink)),
                    const SizedBox(height: 2),
                    Text('Ideas and upcoming dates',
                        style: TextStyle(
                            fontFamily: Kawaii.displayFamily,
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: Kawaii.ink.withValues(alpha: 0.7))),
                  ],
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: KawaiiCard(
                color: Kawaii.sunnySubtle,
                sticker: false,
                padding: const EdgeInsets.all(14),
                onTap: widget.onJump == null ? null : () => widget.onJump!(2),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const KawaiiIcon(
                        icon: Icons.photo_library_rounded,
                        bg: Kawaii.sunny,
                        size: 40,
                        iconSize: 20),
                    const SizedBox(height: 10),
                    const Text('Photo piles',
                        style: TextStyle(
                            fontFamily: Kawaii.displayFamily,
                            fontWeight: FontWeight.w800,
                            fontSize: 15,
                            color: Kawaii.ink)),
                    const SizedBox(height: 2),
                    Text('Shared moments together',
                        style: TextStyle(
                            fontFamily: Kawaii.displayFamily,
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: Kawaii.ink.withValues(alpha: 0.7))),
                  ],
                ),
              ),
            ),
          ]),
          const SizedBox(height: 16),
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
      padding: const EdgeInsets.all(18),
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
          const SizedBox(height: 12),
          Text(greeting(),
              style: const TextStyle(
                  fontFamily: Kawaii.displayFamily,
                  fontWeight: FontWeight.w600,
                  fontSize: 14,
                  color: Kawaii.ink)),
          Row(children: [
            Expanded(
              child: Text(name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.w900,
                      fontFamily: Kawaii.displayFamily,
                      color: Kawaii.ink)),
            ),
            const SizedBox(width: 6),
            const Icon(Icons.favorite_rounded,
                size: 26, color: Kawaii.bubble),
          ]),
          const SizedBox(height: 12),
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
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2.5))),
          );
        }
        if (snap.hasError || (snap.data ?? []).isEmpty) {
          return GestureDetector(
            onTap:
                widget.onJump == null ? null : () => widget.onJump!(1),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Kawaii.ink, width: Kawaii.paperBorderW),
              ),
              child: const Row(children: [
                KawaiiIcon(
                    icon: Icons.edit_note_rounded,
                    bg: Kawaii.peach,
                    size: 38,
                    iconSize: 20),
                SizedBox(width: 10),
                Expanded(
                    child: Text('No notes yet — tap + to drop the first one',
                        style: TextStyle(
                            fontFamily: Kawaii.displayFamily,
                            fontWeight: FontWeight.w700,
                            fontSize: 13,
                            color: Kawaii.ink))),
              ]),
            ),
          );
        }
        final n = snap.data!.first;
        return GestureDetector(
          onTap: widget.onJump == null ? null : () => widget.onJump!(1),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Kawaii.ink, width: Kawaii.paperBorderW),
            ),
            child: Row(children: [
              const KawaiiIcon(
                  icon: Icons.mail_rounded,
                  bg: Kawaii.peach,
                  size: 38,
                  iconSize: 20),
              const SizedBox(width: 10),
              Expanded(
                  child: Text('“${n.body}” — ${dayLabel(n.createdAt)}',
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                          fontFamily: Kawaii.displayFamily,
                          fontWeight: FontWeight.w700,
                          fontSize: 13,
                          color: Kawaii.ink))),
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
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Text('Weekly rituals',
                      style: Theme.of(context).textTheme.titleSmall),
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
                Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Text(
                      'No rituals yet — small repeats keep couples close.',
                      style: Theme.of(context).textTheme.bodySmall),
                ),
              ...rituals.map(_ritual),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: KawaiiInput(
                      hint: 'Add a weekly ritual…',
                      controller: _ritualCtrl,
                      action: TextInputAction.done,
                      onSubmitted: (_) => _addRitual(),
                    ),
                  ),
                  const SizedBox(width: 8),
                  KawaiiIconButton(
                    icon: Icons.add_rounded,
                    label: 'Add ritual',
                    fill: Kawaii.mint,
                    onTap: _addRitual,
                  ),
                ],
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _ritual(Ritual r) {
    final color =
        Kawaii.notePalette[r.colorIdx % Kawaii.notePalette.length];
    final edge = Kawaii.edgeOf(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Semantics(
        button: true,
        toggled: r.done,
        label: r.title,
        child: GestureDetector(
          onTap: () => _toggle(r),
          onLongPress: () => _removeRitual(r),
          behavior: HitTestBehavior.opaque,
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Row(children: [
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: r.done ? color : Kawaii.cardOf(context),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: edge, width: Kawaii.paperBorderW),
                ),
                child: r.done
                    ? const Icon(Icons.check_rounded, size: 18, color: Kawaii.ink)
                    : null,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(r.title,
                    style: TextStyle(
                        fontFamily: Kawaii.displayFamily,
                        fontWeight: FontWeight.w700,
                        fontSize: 15,
                        color: Kawaii.textOf(context),
                        decoration:
                            r.done ? TextDecoration.lineThrough : null)),
              ),
            ]),
          ),
        ),
      ),
    );
  }
}
