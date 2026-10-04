import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../data/backend_errors.dart';
import '../data/composer.dart';
import '../theme/kawaii.dart';
import 'kawaii.dart';

enum CreateKind { note, pile, date }

class _KindMeta {
  final String label;
  final String fabLabel;
  final IconData icon;
  final Color bg;
  final KawaiiBtnColor btn;
  const _KindMeta(this.label, this.fabLabel, this.icon, this.bg, this.btn);
}

const _metas = {
  CreateKind.note: _KindMeta('Note', 'New note', Icons.edit_note_rounded,
      Kawaii.peach, KawaiiBtnColor.peach),
  CreateKind.pile: _KindMeta('Pile', 'New pile', Icons.photo_library_rounded,
      Kawaii.sky, KawaiiBtnColor.sky),
  CreateKind.date: _KindMeta('Date', 'Plan date',
      Icons.calendar_month_rounded, Kawaii.sunny, KawaiiBtnColor.sunny),
};

/// Sticker-style contextual create button: label and button fused into
/// one extended FAB pill. One tab = one action: notes -> note,
/// piles -> pile, dates -> date. Ink is outline-only; every fill is
/// a kawaii-pop pastel.
class KawaiiCreateFab extends StatelessWidget {
  final CreateKind kind;
  final VoidCallback onTap;
  const KawaiiCreateFab(
      {super.key, required this.kind, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final m = _metas[kind]!;
    final dark = Theme.of(context).brightness == Brightness.dark;
    final edge = dark ? Colors.white : Kawaii.ink;
    return Semantics(
      button: true,
      label: m.fabLabel,
      child: GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: Container(
          padding:
              const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
          decoration: BoxDecoration(
            color: m.bg,
            borderRadius: BorderRadius.circular(999),
            border: Border.all(color: edge, width: 3),
            boxShadow: [
              BoxShadow(color: edge, offset: const Offset(4, 4)),
            ],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(m.icon, size: 26, color: Kawaii.ink),
              const SizedBox(width: 10),
              Text(
                m.fabLabel,
                style: const TextStyle(
                  color: Kawaii.ink,
                  fontWeight: FontWeight.w900,
                  fontSize: 16,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class ComposerDeps {
  final String spaceId;
  final AppComposer composer;
  final VoidCallback onCreated;
  const ComposerDeps(
      {required this.spaceId,
      required this.composer,
      required this.onCreated});
}

Future<void> showCreateSheet(
    BuildContext context, CreateKind kind, ComposerDeps deps) async {
  final m = _metas[kind]!;
  final created = await showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (ctx) => Padding(
      padding: EdgeInsets.only(
          bottom: MediaQuery.of(ctx).viewInsets.bottom,
          left: 16,
          right: 16,
          top: 16),
      child: _ComposerSheet(kind: kind, deps: deps),
    ),
  );
  if (created == true && context.mounted) {
    deps.onCreated();
    final label = m.label;
    showDialog(
      context: context,
      builder: (d) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.all(20),
        child: KawaiiAlert(
          title: '$label pasted!',
          message: 'Fresh $label is in the book for both of you.',
          kind: KawaiiAlertKind.success,
          actionLabel: 'Sweet!',
          onAction: () => Navigator.of(d).pop(),
        ),
      ),
    );
  }
}

class _ComposerSheet extends StatefulWidget {
  final CreateKind kind;
  final ComposerDeps deps;
  const _ComposerSheet({required this.kind, required this.deps});

  @override
  State<_ComposerSheet> createState() => _ComposerSheetState();
}

class _ComposerSheetState extends State<_ComposerSheet> {
  static const noteBtns = [
    KawaiiBtnColor.peach,
    KawaiiBtnColor.sky,
    KawaiiBtnColor.sunny,
    KawaiiBtnColor.mint,
    KawaiiBtnColor.pink,
  ];
  static const maxPileImages = 9;

  final _picker = ImagePicker();
  int noteColor = 0;
  final List<XFile> pileImages = [];
  bool picking = false;
  late DateTime calMonth;
  late DateTime calDay;

  final _noteCtrl = TextEditingController();
  final _pileTitleCtrl = TextEditingController();
  final _pileLocCtrl = TextEditingController();
  final _dateTitleCtrl = TextEditingController();
  final _dateNoteCtrl = TextEditingController();
  final _datePlaceCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    calDay = DateTime(now.year, now.month, now.day);
    calMonth = DateTime(now.year, now.month);
  }

  @override
  void dispose() {
    _noteCtrl.dispose();
    _pileTitleCtrl.dispose();
    _pileLocCtrl.dispose();
    _dateTitleCtrl.dispose();
    _dateNoteCtrl.dispose();
    _datePlaceCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickImages() async {
    if (picking) return;
    if (pileImages.length >= maxPileImages) {
      showKawaiiToast(context, 'Max 9 photos per pile',
          kind: KawaiiAlertKind.warning);
      return;
    }
    setState(() => picking = true);
    try {
      final imgs = await _picker.pickMultiImage(
          maxWidth: 1600, imageQuality: 85);
      if (!mounted) return;
      if (imgs.isNotEmpty) {
        final room = maxPileImages - pileImages.length;
        setState(() => pileImages.addAll(imgs.take(room)));
      }
    } catch (_) {
      if (!mounted) return;
      showKawaiiToast(context, 'Could not open gallery',
          kind: KawaiiAlertKind.warning);
    } finally {
      if (mounted) setState(() => picking = false);
    }
  }

  bool _saving = false;

  void _submit() async {
    final kind = widget.kind;
    final deps = widget.deps;
    final valid = switch (kind) {
      CreateKind.note => _noteCtrl.text.trim().isNotEmpty,
      CreateKind.pile => _pileTitleCtrl.text.trim().isNotEmpty,
      CreateKind.date => _dateTitleCtrl.text.trim().isNotEmpty,
    };
    if (!valid || _saving) {
      if (!valid) {
        showKawaiiToast(context, 'Give it a title first',
            kind: KawaiiAlertKind.warning);
      }
      return;
    }
    setState(() => _saving = true);
    try {
      switch (kind) {
        case CreateKind.note:
          await deps.composer.createNote(
              spaceId: deps.spaceId,
              body: _noteCtrl.text.trim(),
              colorIdx: noteColor);
        case CreateKind.pile:
          final report = await deps.composer.createPile(
              spaceId: deps.spaceId,
              title: _pileTitleCtrl.text.trim(),
              location: _pileLocCtrl.text.trim(),
              images: pileImages);
          if (report.failed > 0 && mounted) {
            showKawaiiToast(context,
                'Pile saved — ${report.failed} photo(s) could not upload',
                kind: KawaiiAlertKind.warning);
          }
        case CreateKind.date:
          await deps.composer.createDate(
              spaceId: deps.spaceId,
              title: _dateTitleCtrl.text.trim(),
              note: _dateNoteCtrl.text.trim(),
              place: _datePlaceCtrl.text.trim(),
              day: calDay);
      }
    } catch (e) {
      if (!mounted) return;
      showKawaiiToast(context, userMessage(e),
          kind: KawaiiAlertKind.danger);
      return;
    } finally {
      if (mounted) setState(() => _saving = false);
    }
    if (mounted) Navigator.of(context).pop(true);
  }

  @override
  Widget build(BuildContext context) {
    final m = _metas[widget.kind]!;
    final dark = Theme.of(context).brightness == Brightness.dark;
    final edge = dark ? Colors.white : Kawaii.ink;
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
      decoration: BoxDecoration(
        color: dark ? Kawaii.nightCard : Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
        border: Border.all(color: edge, width: 3),
        boxShadow: [BoxShadow(color: edge, offset: const Offset(4, -4))],
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(
              child: Container(
                width: 48,
                height: 6,
                decoration: BoxDecoration(
                  color: m.bg,
                  borderRadius: BorderRadius.circular(999),
                  border: Border.all(color: edge, width: 2),
                ),
              ),
            ),
            const SizedBox(height: 14),
            Row(children: [
              KawaiiIcon(icon: m.icon, bg: m.bg, size: 48, iconSize: 24),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Fresh ${m.label.toLowerCase()}',
                          style: const TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.w900,
                              fontFamily: Kawaii.displayFamily)),
                      Text(_subtitle(),
                          style: const TextStyle(
                              fontSize: 13, fontWeight: FontWeight.w500)),
                    ]),
              ),
            ]),
            const SizedBox(height: 16),
            ..._fields(),
            const SizedBox(height: 16),
            KawaiiButton(
              label: _saving ? 'Pasting…' : 'Paste it in',
              icon: Icons.check_rounded,
              color: widget.kind == CreateKind.note
                  ? noteBtns[noteColor]
                  : m.btn,
              onTap: _saving ? null : _submit,
            ),
          ],
        ),
      ),
    );
  }

  String _subtitle() {
    switch (widget.kind) {
      case CreateKind.note:
        return 'Say it before you forget it.';
      case CreateKind.pile:
        return 'Name it, add the moments.';
      case CreateKind.date:
        return 'Never “what should we do?” again.';
    }
  }

  List<Widget> _fields() {
    switch (widget.kind) {
      case CreateKind.note:
        return [
          KawaiiInput(
              hint: 'Left oat latte in the fridge…',
              label: 'NOTE',
              controller: _noteCtrl,
              maxLines: 3),
          const SizedBox(height: 12),
          Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            decoration: BoxDecoration(
              color: Kawaii.sunny,
              borderRadius: BorderRadius.circular(999),
              border: Border.all(color: Kawaii.ink, width: 2),
            ),
            child: const Text('COLOR',
                style: TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 12,
                    color: Kawaii.ink)),
          ),
          const SizedBox(height: 8),
          Row(
            children: List.generate(Kawaii.notePalette.length, (i) {
              final active = noteColor == i;
              return GestureDetector(
                onTap: () => setState(() => noteColor = i),
                child: Container(
                  width: 48,
                  height: 48,
                  margin: EdgeInsets.only(
                      right: i == Kawaii.notePalette.length - 1 ? 0 : 10),
                  decoration: BoxDecoration(
                    color: Kawaii.notePalette[i],
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                        color: active
                            ? Kawaii.ink
                            : Kawaii.ink.withValues(alpha: 0.25),
                        width: active ? 3 : 2),
                    boxShadow: active
                        ? const [
                            BoxShadow(
                                color: Kawaii.ink,
                                offset: Offset(3, 3))
                          ]
                        : null,
                  ),
                  alignment: Alignment.center,
                  child: active
                      ? const Icon(Icons.check_rounded,
                          size: 22, color: Kawaii.ink)
                      : null,
                ),
              );
            }),
          ),
        ];
      case CreateKind.pile:
        return [
          _photoPicker(),
          const SizedBox(height: 12),
          KawaiiInput(
              hint: 'e.g. Beach daze',
              label: 'TITLE',
              controller: _pileTitleCtrl),
          const SizedBox(height: 12),
          KawaiiInput(
              hint: 'e.g. Riverside park',
              label: 'LOCATION',
              controller: _pileLocCtrl,
              prefix: Icons.place_outlined),
        ];
      case CreateKind.date:
        return [
          KawaiiInput(
              hint: 'e.g. Sunset picnic',
              label: 'TITLE',
              controller: _dateTitleCtrl),
          const SizedBox(height: 12),
          KawaiiInput(
              hint: 'Blanket, oat lattes, camera…',
              label: 'NOTE',
              controller: _dateNoteCtrl,
              maxLines: 2),
          const SizedBox(height: 12),
          KawaiiInput(
              hint: 'e.g. Riverside park',
              label: 'PLACE',
              controller: _datePlaceCtrl,
              prefix: Icons.place_outlined),
          const SizedBox(height: 12),
          KawaiiCalendar(
            month: calMonth,
            selected: calDay,
            onPrev: () => setState(() =>
                calMonth = DateTime(calMonth.year, calMonth.month - 1)),
            onNext: () => setState(() =>
                calMonth = DateTime(calMonth.year, calMonth.month + 1)),
            onSelect: (d) => setState(() => calDay = d),
          ),
        ];
    }
  }

  Widget _photoPicker() {
    return GestureDetector(
      onTap: _pickImages,
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: Kawaii.ink, width: 2.5),
        ),
        child: pileImages.isEmpty
            ? Row(children: [
                const KawaiiIcon(
                    icon: Icons.add_photo_alternate_outlined,
                    bg: Kawaii.skySubtle,
                    size: 52,
                    iconSize: 26),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(picking ? 'Opening gallery…' : 'Add photos',
                            style: const TextStyle(
                                fontWeight: FontWeight.w800, fontSize: 15)),
                        const Text('From your gallery, as many as you like',
                            style: TextStyle(
                                fontSize: 12, fontWeight: FontWeight.w600)),
                      ]),
                ),
                if (picking)
                  const SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(strokeWidth: 3)),
              ])
            : Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  GridView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    gridDelegate:
                        const SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: 3,
                            crossAxisSpacing: 8,
                            mainAxisSpacing: 8),
                    itemCount: pileImages.length,
                    itemBuilder: (_, i) => Stack(
                      clipBehavior: Clip.none,
                      children: [
                        ClipRRect(
                          borderRadius: BorderRadius.circular(14),
                          child: _PileThumb(file: pileImages[i]),
                        ),
                        Positioned(
                          top: -8,
                          right: -8,
                          child: GestureDetector(
                            onTap: () =>
                                setState(() => pileImages.removeAt(i)),
                            child: Container(
                              padding: const EdgeInsets.all(10),
                              decoration: const BoxDecoration(
                                color: Colors.white,
                                shape: BoxShape.circle,
                              ),
                              child: Container(
                                padding: const EdgeInsets.all(4),
                                decoration: BoxDecoration(
                                  color: Kawaii.bubble,
                                  shape: BoxShape.circle,
                                  border: Border.all(
                                      color: Kawaii.ink, width: 2),
                                ),
                                child: const Icon(Icons.close_rounded,
                                    size: 14, color: Kawaii.ink),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 10),
                  Container(
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    decoration: BoxDecoration(
                      color: Kawaii.skySubtle,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: Kawaii.ink, width: 2),
                    ),
                    alignment: Alignment.center,
                    child: Text(
                        picking
                            ? 'Opening gallery…'
                            : 'Add more • ${pileImages.length} picked',
                        style: const TextStyle(
                            fontWeight: FontWeight.w800, fontSize: 13)),
                  ),
                ],
              ),
      ),
    );
  }
}

/// Web-safe thumbnail: reads bytes via XFile (works on mobile + web),
/// no dart:io dependency.
class _PileThumb extends StatelessWidget {
  final XFile file;
  const _PileThumb({required this.file});

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<Uint8List>(
      future: file.readAsBytes(),
      builder: (context, snap) {
        if (snap.hasData) {
          return Image.memory(snap.data!,
              height: 96, width: double.infinity, fit: BoxFit.cover,
              errorBuilder: (_, _, _) => Container(
                  height: 96,
                  color: Kawaii.skySubtle,
                  alignment: Alignment.center,
                  child: const Icon(Icons.broken_image_rounded)));
        }
        if (snap.hasError) {
          return Container(
              height: 96,
              color: Kawaii.skySubtle,
              alignment: Alignment.center,
              child: const Icon(Icons.broken_image_rounded));
        }
        return Container(
            height: 96,
            color: Kawaii.skySubtle,
            alignment: Alignment.center,
            child: const SizedBox(
                width: 22,
                height: 22,
                child: CircularProgressIndicator(strokeWidth: 3)));
      },
    );
  }
}

/// Sticker-style month picker. Ink is outline-only; the picked day
/// owns the sunny fill, today gets a bubble dot.
class KawaiiCalendar extends StatelessWidget {
  final DateTime month;
  final DateTime selected;
  final VoidCallback onPrev;
  final VoidCallback onNext;
  final ValueChanged<DateTime> onSelect;

  static const months = [
    'January', 'February', 'March', 'April', 'May', 'June', 'July',
    'August', 'September', 'October', 'November', 'December'
  ];
  static const weekdays = ['M', 'T', 'W', 'T', 'F', 'S', 'S'];

  const KawaiiCalendar({
    super.key,
    required this.month,
    required this.selected,
    required this.onPrev,
    required this.onNext,
    required this.onSelect,
  });

  @override
  Widget build(BuildContext context) {
    final today = DateTime.now();
    final first = DateTime(month.year, month.month);
    final lead = first.weekday - 1;
    // Day 0 of next month = last day of this month (works across Dec->Jan).
    final count = DateTime(month.year, month.month + 1, 0).day;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Kawaii.cream,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Kawaii.ink, width: 2.5),
      ),
      child: Column(
        children: [
          Row(children: [
            _nav(Icons.chevron_left_rounded, onPrev),
            Expanded(
              child: Text('${months[month.month - 1]} ${month.year}',
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                      fontWeight: FontWeight.w900,
                      fontFamily: Kawaii.displayFamily,
                      fontSize: 16)),
            ),
            _nav(Icons.chevron_right_rounded, onNext),
          ]),
          const SizedBox(height: 8),
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate:
                const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 7),
            itemCount: weekdays.length,
            itemBuilder: (_, i) => Center(
              child: Text(weekdays[i],
                  style: TextStyle(
                      fontWeight: FontWeight.w800,
                      fontSize: 12,
                      color: Kawaii.ink.withValues(alpha: 0.5))),
            ),
          ),
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate:
                const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 7),
            itemCount: lead + count,
            itemBuilder: (_, i) {
              if (i < lead) return const SizedBox();
              final day = i - lead + 1;
              final date = DateTime(month.year, month.month, day);
              final isSel = date.year == selected.year &&
                  date.month == selected.month &&
                  date.day == selected.day;
              final isToday = date.year == today.year &&
                  date.month == today.month &&
                  date.day == today.day;
              return Semantics(
                button: true,
                selected: isSel,
                label: '${months[month.month - 1]} $day',
                child: GestureDetector(
                onTap: () => onSelect(date),
                behavior: HitTestBehavior.opaque,
                child: Center(
                  child: Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: isSel ? Kawaii.sunny : Colors.transparent,
                      shape: BoxShape.circle,
                      border: Border.all(
                          color: isSel ? Kawaii.ink : Colors.transparent,
                          width: 2.5),
                      boxShadow: isSel
                          ? const [
                              BoxShadow(
                                  color: Kawaii.ink,
                                  offset: Offset(2, 2))
                            ]
                          : null,
                    ),
                    alignment: Alignment.center,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text('$day',
                            style: TextStyle(
                                fontWeight: isSel
                                    ? FontWeight.w900
                                    : FontWeight.w700,
                                fontSize: 14)),
                        if (isToday && !isSel)
                          Container(
                            width: 6,
                            height: 6,
                            margin: const EdgeInsets.only(top: 1),
                            decoration: const BoxDecoration(
                                color: Kawaii.bubble,
                                shape: BoxShape.circle),
                          ),
                      ],
                    ),
                  ),
                ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _nav(IconData icon, VoidCallback onTap) {
    final label = icon == Icons.chevron_left_rounded
        ? 'Previous month'
        : 'Next month';
    return Semantics(
      button: true,
      label: label,
      child: GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        width: 44,
        height: 44,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: Kawaii.ink, width: 2.5),
        ),
        alignment: Alignment.center,
        child: Icon(icon, size: 24, color: Kawaii.ink),
      ),
      ),
    );
  }
}
