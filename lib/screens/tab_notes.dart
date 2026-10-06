import 'package:flutter/material.dart';
import '../data/backend_errors.dart';
import '../data/format.dart';
import '../data/models/content.dart';
import '../data/repos.dart';
import '../theme/kawaii.dart';
import '../widgets/kawaii.dart';
import '../widgets/kawaii_deco.dart';

class NotesTab extends StatefulWidget {
  final String spaceId;
  final NotesRepo notesRepo;
  final String myUid;
  const NotesTab(
      {super.key,
      required this.spaceId,
      required this.notesRepo,
      required this.myUid});
  @override
  State<NotesTab> createState() => _NotesTabState();
}

class _NotesTabState extends State<NotesTab> {
  int filter = 0; // 0 all, 1 pinned, 2 mine

  List<Note> _visible(List<Note> all) {
    switch (filter) {
      case 1:
        return all.where((n) => n.pinned).toList();
      case 2:
        return all.where((n) => n.authorId == widget.myUid).toList();
      default:
        return all;
    }
  }

  Future<void> _togglePin(Note n) async {
    try {
      await widget.notesRepo.togglePin(n.id, !n.pinned);
    } catch (e) {
      if (!mounted) return;
      showKawaiiToast(context, userMessage(e),
          kind: KawaiiAlertKind.danger);
    }
  }

  Future<void> _remove(Note n) async {
    final ok = await confirmKawaii(
      context,
      title: 'Delete this note?',
      message: '“${n.body}” will be removed for both of you.',
      confirmLabel: 'Delete note',
    );
    if (!ok) return;
    try {
      await widget.notesRepo.remove(n.id);
      if (!mounted) return;
      showKawaiiToast(context, 'Note removed', kind: KawaiiAlertKind.info);
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
          const Row(
            children: [
              KawaiiDoodles(),
              Spacer(),
              KawaiiSparkle(size: 18),
            ],
          ),
          const SizedBox(height: 10),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(children: [
              _chip('All', 0),
              _chip('Pinned', 1),
              _chip('Mine', 2),
            ]),
          ),
          const SizedBox(height: 14),
          StreamBuilder<List<Note>>(
            stream: widget.notesRepo.watch(widget.spaceId),
            builder: (context, snap) {
              if (snap.connectionState == ConnectionState.waiting) {
                return const Padding(
                  padding: EdgeInsets.symmetric(vertical: 32),
                  child: Center(child: CircularProgressIndicator()),
                );
              }
              if (snap.hasError) {
                return KawaiiAlert(
                  title: 'Could not load notes',
                  message: userMessage(snap.error!),
                  kind: KawaiiAlertKind.danger,
                  actionLabel: 'Retry',
                  onAction: () => setState(() {}),
                );
              }
              final all = snap.data ?? [];
              if (all.isEmpty) {
                return const KawaiiEmpty(
                  title: 'No notes yet',
                  message: 'Tap + below to drop the first one for you two.',
                );
              }
              final vis = _visible(all);
              if (vis.isEmpty) {
                return const KawaiiEmpty(
                  title: 'No notes for this filter',
                  message:
                      'Try another filter above, or tap + below to drop a fresh note.',
                );
              }
              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  ...vis.map((n) => Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: _noteCard(n),
                      )),
                ],
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _noteCard(Note n) {
    final color = Kawaii.notePalette[n.colorIdx % Kawaii.notePalette.length];
    final sub = StringBuffer(dayLabel(n.createdAt));
    if (n.pinned) sub.write(' • pinned');
    return GestureDetector(
      onLongPress: () => _remove(n),
      child: KawaiiCard(
        color: color,
        padding: const EdgeInsets.all(16),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: Kawaii.ink, width: Kawaii.paperBorderW),
              ),
              alignment: Alignment.center,
              child: Icon(n.pinned ? Icons.push_pin_rounded : Icons.mail_rounded,
                  size: 20, color: Kawaii.ink),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(n.body,
                      style: const TextStyle(
                          fontFamily: Kawaii.displayFamily,
                          fontWeight: FontWeight.w800,
                          fontSize: 15,
                          height: 1.35,
                          color: Kawaii.ink)),
                  const SizedBox(height: 4),
                  Text(sub.toString(),
                      style: TextStyle(
                          fontFamily: Kawaii.displayFamily,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: Kawaii.ink.withValues(alpha: 0.7))),
                ],
              ),
            ),
            Semantics(
              button: true,
              label: n.pinned ? 'Unpin note' : 'Pin note',
              child: GestureDetector(
                onTap: () => _togglePin(n),
                behavior: HitTestBehavior.opaque,
                child: Padding(
                  padding: const EdgeInsets.all(4),
                  child: Icon(
                      n.pinned
                          ? Icons.push_pin_rounded
                          : Icons.push_pin_outlined,
                      size: 22,
                      color: Kawaii.ink.withValues(alpha: n.pinned ? 1 : 0.45)),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _chip(String l, int i) {
    final active = filter == i;
    const actives = [Kawaii.peach, Kawaii.sky, Kawaii.sunny];
    final edge = Kawaii.edgeOf(context);
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: Semantics(
        button: true,
        selected: active,
        label: 'Filter $l',
        child: GestureDetector(
          onTap: () => setState(() => filter = i),
          behavior: HitTestBehavior.opaque,
          child: Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              color:
                  active ? actives[i % actives.length] : Kawaii.cardOf(context),
              borderRadius: BorderRadius.circular(999),
              border: Border.all(color: edge, width: Kawaii.paperBorderW),
              boxShadow: active
                  ? [BoxShadow(color: edge, offset: const Offset(2, 2))]
                  : null,
            ),
            child: Text(l,
                style: TextStyle(
                    fontFamily: Kawaii.displayFamily,
                    fontWeight: FontWeight.w800,
                    fontSize: 13,
                    color: active ? Kawaii.ink : Kawaii.textOf(context))),
          ),
        ),
      ),
    );
  }
}
