import 'package:flutter/material.dart';
import '../data/format.dart';
import '../data/models/content.dart';
import '../data/repos.dart';
import '../theme/kawaii.dart';
import '../widgets/kawaii.dart';

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
  bool showTip = true;

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
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString().replaceFirst('StateError: ', ''))),
      );
    }
  }

  Future<void> _remove(Note n) async {
    try {
      await widget.notesRepo.remove(n.id);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString().replaceFirst('StateError: ', ''))),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: EdgeInsets.fromLTRB(20, 12, 20, Kawaii.tabBottom(context)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const KawaiiPageHeader(
            title: 'Little love notes',
            subtitle: 'Tiny drops, big warmth. Say it before you forget it.',
            icon: Icons.edit_note_rounded,
            bg: Kawaii.bubble),
          const SizedBox(height: 14),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(children: [
              _chip('All', 0),
              _chip('Pinned', 1),
              _chip('Mine', 2),
            ]),
          ),
          const SizedBox(height: 12),
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
                  message: snap.error
                      .toString()
                      .replaceFirst('StateError: ', ''),
                  kind: KawaiiAlertKind.danger,
                  actionLabel: 'Retry',
                  onAction: () => setState(() {}),
                );
              }
              final all = snap.data ?? [];
              if (all.isEmpty) {
                return const KawaiiAlert(
                  title: 'No notes yet',
                  message:
                      'Tap + below to drop the first one for you two.',
                  kind: KawaiiAlertKind.info,
                );
              }
              final vis = _visible(all);
              if (vis.isEmpty) {
                return const KawaiiAlert(
                  title: 'No notes for this filter',
                  message:
                      'Try another pile above, or tap + below to drop a fresh one.',
                  kind: KawaiiAlertKind.info,
                );
              }
              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  ...vis.map((n) => Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: _noteCard(n),
                      )),
                  if (showTip)
                    KawaiiAlert(
                      title: 'Fresh pages',
                      message:
                          'Tap + below to drop a fresh note. Long-press a note to remove it.',
                      kind: KawaiiAlertKind.info,
                      onClose: () => setState(() => showTip = false),
                    ),
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
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Kawaii.ink, width: 2.5),
              ),
              alignment: Alignment.center,
              child: Icon(n.pinned ? Icons.push_pin_rounded : Icons.mail_rounded,
                  size: 22, color: Kawaii.ink),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(n.body,
                      style: const TextStyle(
                          fontWeight: FontWeight.w800, fontSize: 15)),
                  const SizedBox(height: 2),
                  Text(sub.toString(),
                      style: const TextStyle(
                          fontSize: 12, fontWeight: FontWeight.w600)),
                ],
              ),
            ),
            GestureDetector(
              onTap: () => _togglePin(n),
              behavior: HitTestBehavior.opaque,
              child: Container(
                padding: const EdgeInsets.all(8),
                child: Icon(
                    n.pinned
                        ? Icons.push_pin_rounded
                        : Icons.push_pin_outlined,
                    size: 20,
                    color: Kawaii.ink.withValues(alpha: n.pinned ? 1 : 0.4)),
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
              const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color:
                active ? actives[i % actives.length] : Kawaii.cardOf(context),
            borderRadius: BorderRadius.circular(999),
            border: Border.all(color: Kawaii.edgeOf(context), width: 2.5),
            boxShadow: active
                ? [BoxShadow(color: Kawaii.edgeOf(context), offset: const Offset(3, 3))]
                : null,
          ),
          child: Text(l,
              style: const TextStyle(
                  fontWeight: FontWeight.w800,
                  fontSize: 13,
                  color: Kawaii.ink)),
        ),
        ),
      ),
    );
  }
}
