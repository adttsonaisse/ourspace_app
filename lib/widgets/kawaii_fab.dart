import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../data/backend_errors.dart';
import '../data/composer.dart';
import '../data/format.dart';
import '../theme/kawaii.dart';
import 'place_picker.dart';
import 'kawaii.dart';
import 'kawaii_deco.dart';

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
/// piles -> pile, dates -> date.
class KawaiiCreateFab extends StatelessWidget {
  final CreateKind kind;
  final VoidCallback onTap;
  const KawaiiCreateFab(
      {super.key, required this.kind, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final m = _metas[kind]!;
    final edge = Kawaii.edgeOf(context);
    return Semantics(
      button: true,
      label: m.fabLabel,
      child: GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: Container(
          padding:
              const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
          decoration: BoxDecoration(
            color: m.bg,
            borderRadius: BorderRadius.circular(999),
            border: Border.all(color: edge, width: Kawaii.borderW),
            boxShadow: [
              BoxShadow(color: edge, offset: const Offset(4, 4)),
            ],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(m.icon, size: 24, color: Kawaii.ink),
              const SizedBox(width: 8),
              Text(
                m.fabLabel,
                style: const TextStyle(
                  fontFamily: Kawaii.displayFamily,
                  color: Kawaii.ink,
                  fontWeight: FontWeight.w900,
                  fontSize: 15,
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
        elevation: 0,
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
  static const maxPileImages = 1;

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
      showKawaiiToast(context, 'Only one photo per pile — remove it to change',
          kind: KawaiiAlertKind.warning);
      return;
    }
    setState(() => picking = true);
    try {
      final img = await _picker.pickImage(
          source: ImageSource.gallery, maxWidth: 1600, imageQuality: 85);
      if (!mounted) return;
      if (img != null) {
        setState(() {
          pileImages
            ..clear()
            ..add(img);
        });
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
    final edge = Kawaii.edgeOf(context);
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
      decoration: BoxDecoration(
        color: Kawaii.cardOf(context),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        border: Border.all(color: edge, width: Kawaii.borderW),
        boxShadow: [BoxShadow(color: edge, offset: const Offset(4, -4))],
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(
              child: Container(
                width: 44,
                height: 5,
                decoration: BoxDecoration(
                  color: m.bg,
                  borderRadius: BorderRadius.circular(999),
                  border: Border.all(color: edge, width: 1.5),
                ),
              ),
            ),
            const SizedBox(height: 14),
            Row(children: [
              KawaiiIcon(icon: m.icon, bg: m.bg, size: 44, iconSize: 22, outlined: true),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Fresh ${m.label.toLowerCase()}',
                          style: Theme.of(context).textTheme.titleLarge),
                      Text(_subtitle(),
                          style: Theme.of(context).textTheme.bodySmall),
                    ]),
              ),
              const KawaiiSparkle(size: 20),
            ]),
            const SizedBox(height: 8),
            const Row(
              children: [
                KawaiiDoodles(),
                Spacer(),
              ],
            ),
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
    final edge = Kawaii.edgeOf(context);
    switch (widget.kind) {
      case CreateKind.note:
        return [
          KawaiiInput(
              hint: 'Left oat latte in the fridge…',
              label: 'Note',
              controller: _noteCtrl,
              maxLines: 3),
          const SizedBox(height: 14),
          Padding(
            padding: const EdgeInsets.only(left: 4, bottom: 8),
            child: Text('Color', style: Theme.of(context).textTheme.titleSmall),
          ),
          LayoutBuilder(
            builder: (context, constraints) {
              final count = Kawaii.notePalette.length;
              final maxItemSize = 44.0;
              final gap = 8.0;
              final itemSize = ((constraints.maxWidth - (gap * (count - 1))) / count)
                  .clamp(32.0, maxItemSize);
              return Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: List.generate(count, (i) {
                  final active = noteColor == i;
                  return Semantics(
                    button: true,
                    selected: active,
                    label: '${Kawaii.notePaletteNames[i]} color',
                    child: GestureDetector(
                      onTap: () => setState(() => noteColor = i),
                      child: Container(
                        width: itemSize,
                        height: itemSize,
                        decoration: BoxDecoration(
                          color: Kawaii.notePalette[i],
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                              color: active ? edge : edge.withValues(alpha: 0.25),
                              width: active ? 3 : 2),
                          boxShadow: active
                              ? [BoxShadow(color: edge, offset: const Offset(2, 2))]
                              : null,
                        ),
                        alignment: Alignment.center,
                        child: active
                            ? const Icon(Icons.check_rounded,
                                size: 20, color: Kawaii.ink)
                            : null,
                      ),
                    ),
                  );
                }),
              );
            },
          ),
        ];
      case CreateKind.pile:
        return [
          _photoPicker(),
          const SizedBox(height: 12),
          KawaiiInput(
              hint: 'e.g. Beach daze',
              label: 'Title',
              controller: _pileTitleCtrl),
          const SizedBox(height: 12),
          _placeField(controller: _pileLocCtrl, label: 'Location'),
        ];
      case CreateKind.date:
        return [
          KawaiiInput(
              hint: 'e.g. Sunset picnic',
              label: 'Title',
              controller: _dateTitleCtrl),
          const SizedBox(height: 12),
          KawaiiInput(
              hint: 'Blanket, oat lattes, camera…',
              label: 'Note',
              controller: _dateNoteCtrl,
              maxLines: 2),
          const SizedBox(height: 12),
          _placeField(controller: _datePlaceCtrl, label: 'Place'),
          const SizedBox(height: 12),
          _dateField(),
        ];
    }
  }

  /// Read-only date field: tap opens the calendar in a dialog.
  Widget _dateField() {
    final edge = Kawaii.edgeOf(context);
    final fg = Kawaii.textOf(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 4, bottom: 6),
          child: Text('Date',
              style: Theme.of(context).textTheme.titleSmall),
        ),
        Semantics(
          button: true,
          label: 'Pick date, currently ${dayLabelYear(calDay)}',
          child: GestureDetector(
            onTap: _pickDate,
            behavior: HitTestBehavior.opaque,
            child: Container(
              padding: const EdgeInsets.symmetric(
                  horizontal: 16, vertical: 15),
              decoration: BoxDecoration(
                color: Kawaii.cardOf(context),
                borderRadius:
                    BorderRadius.circular(Kawaii.radiusInput),
                border: Border.all(
                    color: edge, width: Kawaii.paperBorderW),
              ),
              child: Row(
                children: [
                  Icon(Icons.calendar_month_rounded,
                      color: fg, size: 20),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      dayLabelYear(calDay),
                      style: Theme.of(context)
                          .textTheme
                          .bodyLarge
                          ?.copyWith(color: fg),
                    ),
                  ),
                  Icon(Icons.expand_more_rounded,
                      color: fg.withValues(alpha: 0.6), size: 20),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  Future<void> _pickDate() async {
    var tmpMonth = calMonth;
    var tmpDay = calDay;
    final picked = await showDialog<DateTime>(
      context: context,
      builder: (d) => Dialog(
        backgroundColor: Colors.transparent,
        elevation: 0,
        insetPadding: const EdgeInsets.all(20),
        child: Container(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
          decoration: BoxDecoration(
            color: Kawaii.cardOf(d),
            borderRadius: BorderRadius.circular(Kawaii.radiusCard),
            border: Border.all(
                color: Kawaii.edgeOf(d), width: Kawaii.borderW),
          ),
          child: StatefulBuilder(
            builder: (dctx, setInner) => SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  KawaiiCalendar(
                    month: tmpMonth,
                    selected: tmpDay,
                    onPrev: () => setInner(() => tmpMonth = DateTime(
                        tmpMonth.year, tmpMonth.month - 1)),
                    onNext: () => setInner(() => tmpMonth = DateTime(
                        tmpMonth.year, tmpMonth.month + 1)),
                    onSelect: (day) => setInner(() {
                      tmpDay = day;
                      tmpMonth =
                          DateTime(day.year, day.month);
                    }),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: KawaiiButton(
                          label: 'Cancel',
                          color: KawaiiBtnColor.white,
                          onTap: () =>
                              Navigator.of(dctx).pop(),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: KawaiiButton(
                          label: 'Choose',
                          icon: Icons.check_rounded,
                          color: KawaiiBtnColor.sunny,
                          onTap: () =>
                              Navigator.of(dctx).pop(tmpDay),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
    if (picked != null && mounted) {
      setState(() {
        calDay = DateTime(picked.year, picked.month, picked.day);
        calMonth = DateTime(picked.year, picked.month);
      });
    }
  }

  /// Place/location field shared by date + pile: manual text + real map
  /// picker. The map returns the place's main title which auto-fills
  /// this field (text-only scope).
  Widget _placeField(
      {required TextEditingController controller,
      required String label}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        KawaiiInput(
          hint: 'e.g. Riverside park',
          label: label,
          controller: controller,
          prefix: Icons.place_outlined,
        ),
        const SizedBox(height: 8),
        Semantics(
          button: true,
          label: 'Choose $label on map',
          child: GestureDetector(
            onTap: () => _openPlacePicker(controller),
            behavior: HitTestBehavior.opaque,
            child: Container(
              padding: const EdgeInsets.symmetric(
                  horizontal: 14, vertical: 11),
              decoration: BoxDecoration(
                color: Kawaii.sunnySubtle,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                    color: Kawaii.edgeOf(context),
                    width: Kawaii.paperBorderW),
              ),
              child: const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.map_rounded,
                      size: 18, color: Kawaii.ink),
                  SizedBox(width: 8),
                  Text(
                    'Choose on map',
                    style: TextStyle(
                      fontFamily: Kawaii.displayFamily,
                      fontWeight: FontWeight.w800,
                      fontSize: 13,
                      color: Kawaii.ink,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  Future<void> _openPlacePicker(TextEditingController controller) async {
    final picked = await Navigator.of(context).push<String>(
      MaterialPageRoute(
        builder: (_) => PlacePickerPage(
          initialQuery: controller.text.trim(),
        ),
      ),
    );
    if (picked != null && picked.trim().isNotEmpty && mounted) {
      setState(() => controller.text = picked.trim());
    }
  }

  Widget _photoPicker() {
    final edge = Kawaii.edgeOf(context);
    return GestureDetector(
      onTap: _pickImages,
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Kawaii.cardOf(context),
          borderRadius: BorderRadius.circular(Kawaii.radiusInner),
          border: Border.all(color: edge, width: Kawaii.paperBorderW),
        ),
        child: pileImages.isEmpty
            ? Row(children: [
                const KawaiiIcon(
                    icon: Icons.add_photo_alternate_outlined,
                    bg: Kawaii.skySubtle,
                    size: 48,
                    iconSize: 24,
                    outlined: true),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(picking ? 'Opening gallery…' : 'Add a photo',
                            style: Theme.of(context).textTheme.titleSmall),
                        Text('From your gallery, one photo',
                            style: Theme.of(context).textTheme.bodySmall),
                      ]),
                ),
                if (picking)
                  const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2.5)),
              ])
            : Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Stack(
                    clipBehavior: Clip.none,
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: AspectRatio(
                          aspectRatio: 16 / 10,
                          child: _PileThumb(file: pileImages.first),
                        ),
                      ),
                      Positioned(
                        top: 8,
                        right: 8,
                        child: GestureDetector(
                          onTap: () =>
                              setState(() => pileImages.clear()),
                          child: Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: Kawaii.cardOf(context),
                              shape: BoxShape.circle,
                            ),
                            child: Container(
                              padding: const EdgeInsets.all(3),
                              decoration: BoxDecoration(
                                color: Kawaii.bubble,
                                shape: BoxShape.circle,
                                border: Border.all(
                                    color: edge, width: 1.5),
                              ),
                              child: const Icon(Icons.close_rounded,
                                  size: 13, color: Kawaii.ink),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  GestureDetector(
                    onTap: _pickImages,
                    behavior: HitTestBehavior.opaque,
                    child: Container(
                      padding:
                          const EdgeInsets.symmetric(vertical: 9),
                      decoration: BoxDecoration(
                        color: Kawaii.skySubtle,
                        borderRadius: BorderRadius.circular(12),
                        border:
                            Border.all(color: edge, width: 2),
                      ),
                      alignment: Alignment.center,
                      child: Text(
                          picking
                              ? 'Opening gallery…'
                              : 'Replace photo',
                          style: const TextStyle(
                              fontFamily: Kawaii.displayFamily,
                              fontWeight: FontWeight.w800,
                              fontSize: 13,
                              color: Kawaii.ink)),
                    ),
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
              width: double.infinity,
              height: double.infinity,
              fit: BoxFit.cover,
              errorBuilder: (_, _, _) => Container(
                  color: Kawaii.skySubtle,
                  alignment: Alignment.center,
                  child: const Icon(Icons.broken_image_rounded)));
        }
        if (snap.hasError) {
          return Container(
              color: Kawaii.skySubtle,
              alignment: Alignment.center,
              child: const Icon(Icons.broken_image_rounded));
        }
        return Container(
            color: Kawaii.skySubtle,
            alignment: Alignment.center,
            child: const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2.5)));
      },
    );
  }
}

/// Month picker with dark-mode support and responsive date cells.
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
    final count = DateTime(month.year, month.month + 1, 0).day;
    final edge = Kawaii.edgeOf(context);
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Kawaii.cardOf(context),
        borderRadius: BorderRadius.circular(Kawaii.radiusInner),
        border: Border.all(color: edge, width: Kawaii.paperBorderW),
      ),
      child: Column(
        children: [
          Row(children: [
            _nav(context, Icons.chevron_left_rounded, onPrev),
            Expanded(
              child: Text('${months[month.month - 1]} ${month.year}',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.titleSmall),
            ),
            _nav(context, Icons.chevron_right_rounded, onNext),
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
                      fontFamily: Kawaii.displayFamily,
                      fontWeight: FontWeight.w800,
                      fontSize: 12,
                      color: Kawaii.mutedOf(context))),
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
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        color: isSel ? Kawaii.sunny : Colors.transparent,
                        shape: BoxShape.circle,
                        border: Border.all(
                            color: isSel ? edge : Colors.transparent,
                            width: 2),
                        boxShadow: isSel
                            ? [BoxShadow(color: edge, offset: const Offset(2, 2))]
                            : null,
                      ),
                      alignment: Alignment.center,
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text('$day',
                              style: TextStyle(
                                  fontFamily: Kawaii.displayFamily,
                                  fontWeight: isSel
                                      ? FontWeight.w900
                                      : FontWeight.w700,
                                  fontSize: 13,
                                  color: isSel ? Kawaii.ink : Kawaii.textOf(context))),
                          if (isToday && !isSel)
                            Container(
                              width: 5,
                              height: 5,
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

  Widget _nav(BuildContext context, IconData icon, VoidCallback onTap) {
    final label = icon == Icons.chevron_left_rounded
        ? 'Previous month'
        : 'Next month';
    final edge = Kawaii.edgeOf(context);
    return Semantics(
      button: true,
      label: label,
      child: GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: Container(
          width: 38,
          height: 38,
          decoration: BoxDecoration(
            color: Kawaii.cardOf(context),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: edge, width: Kawaii.paperBorderW),
          ),
          alignment: Alignment.center,
          child: Icon(icon, size: 22, color: Kawaii.textOf(context)),
        ),
      ),
    );
  }
}
