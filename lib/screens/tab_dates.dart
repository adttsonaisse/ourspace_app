import 'package:flutter/material.dart';
import '../data/backend_errors.dart';
import '../data/format.dart';
import '../data/models/content.dart';
import '../data/repos.dart';
import '../theme/kawaii.dart';
import '../widgets/kawaii.dart';

class DatesTab extends StatefulWidget {
  final String spaceId;
  final DatesRepo datesRepo;
  final VoidCallback? onSchedule;
  const DatesTab(
      {super.key,
      required this.spaceId,
      required this.datesRepo,
      this.onSchedule});
  @override
  State<DatesTab> createState() => _DatesTabState();
}

class _DatesTabState extends State<DatesTab> {
  Future<void> _remove(DatePlan p) async {
    final ok = await confirmKawaii(
      context,
      title: 'Remove date plan?',
      message: '“${p.title}” will be removed from your plans.',
      confirmLabel: 'Remove plan',
    );
    if (!ok) return;
    try {
      await widget.datesRepo.remove(p.id);
      if (!mounted) return;
      showKawaiiToast(context, '“${p.title}” removed',
          kind: KawaiiAlertKind.success);
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
          StreamBuilder<List<DatePlan>>(
            stream: widget.datesRepo.watch(widget.spaceId),
            builder: (context, snap) {
              if (snap.connectionState == ConnectionState.waiting) {
                return const Padding(
                  padding: EdgeInsets.symmetric(vertical: 32),
                  child: Center(child: CircularProgressIndicator()),
                );
              }
              if (snap.hasError) {
                return KawaiiAlert(
                  title: 'Could not load dates',
                  message: userMessage(snap.error!),
                  kind: KawaiiAlertKind.danger,
                  actionLabel: 'Retry',
                  onAction: () => setState(() {}),
                );
              }
              final all = snap.data ?? [];
              if (all.isEmpty) {
                return KawaiiEmpty(
                  title: 'No dates yet',
                  message: 'Tap + below to plan the first one together.',
                  actionLabel: 'Plan a date',
                  actionIcon: Icons.calendar_month_rounded,
                  actionColor: KawaiiBtnColor.sunny,
                  onAction: widget.onSchedule,
                );
              }
              final today = DateTime.now();
              final day0 =
                  DateTime(today.year, today.month, today.day);
              final upcoming = all
                  .where((p) =>
                      !DateTime(p.day.year, p.day.month, p.day.day)
                          .isBefore(day0))
                  .toList();
              final past = all.length - upcoming.length;
              final next = upcoming.isEmpty ? null : upcoming.first;
              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (next != null) _nextCard(next),
                  const SizedBox(height: 16),
                  KawaiiSectionTitle(
                    upcoming.length <= 1
                        ? 'All plans'
                        : 'More plans',
                  ),
                  ...upcoming
                      .skip(next == null ? 0 : 1)
                      .map(_planCard),
                  if (past > 0) ...[
                    const SizedBox(height: 8),
                    KawaiiCard(
                      sticker: false,
                      color: Kawaii.cardOf(context),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 12),
                      child: Row(children: [
                        const KawaiiIcon(
                            icon: Icons.history_rounded,
                            bg: Kawaii.sunnySubtle,
                            size: 40,
                            iconSize: 20),
                        const SizedBox(width: 12),
                        Expanded(
                            child: Text(
                                '$past saved memory ${past == 1 ? 'date' : 'dates'}',
                                style: Theme.of(context).textTheme.bodyMedium)),
                      ]),
                    ),
                  ],
                ],
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _nextCard(DatePlan p) {
    final detail = [
      if (p.place.isNotEmpty) p.place,
      if (p.note.isNotEmpty) p.note,
    ].join(' • ');
    return KawaiiCard(
      color: Kawaii.bubble,
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            KawaiiPill(
                label: 'Next up • ${dayLabel(p.day)}',
                color: Colors.white),
            const Spacer(),
            const KawaiiIcon(
                icon: Icons.wb_sunny_rounded,
                bg: Colors.white,
                size: 40,
                iconSize: 22),
          ]),
          const SizedBox(height: 10),
          Text(p.title,
              style: const TextStyle(
                  fontFamily: Kawaii.displayFamily,
                  fontSize: 22,
                  fontWeight: FontWeight.w900,
                  color: Kawaii.ink)),
          if (detail.isNotEmpty) ...[
            const SizedBox(height: 2),
            Text(detail,
                style: const TextStyle(
                    fontFamily: Kawaii.displayFamily,
                    color: Kawaii.ink,
                    fontSize: 14,
                    fontWeight: FontWeight.w600)),
          ],
          const SizedBox(height: 14),
          KawaiiButton(
            label: 'Plan another',
            icon: Icons.add_rounded,
            color: KawaiiBtnColor.white,
            onTap: widget.onSchedule,
          ),
        ],
      ),
    );
  }

  Widget _planCard(DatePlan p) {
    final sub = [
      dayLabelYear(p.day),
      if (p.place.isNotEmpty) p.place,
    ].join(' • ');
    final edge = Kawaii.edgeOf(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: KawaiiCard(
        sticker: false,
        color: Kawaii.sunnySubtle,
        padding: const EdgeInsets.all(12),
        child: Row(children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
                color: Kawaii.cardOf(context),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: edge, width: Kawaii.paperBorderW)),
            alignment: Alignment.center,
            child: Text('${p.day.day}',
                style: TextStyle(
                    fontFamily: Kawaii.displayFamily,
                    color: Kawaii.textOf(context),
                    fontWeight: FontWeight.w900,
                    fontSize: 18)),
          ),
          const SizedBox(width: 12),
          Expanded(
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                Text(p.title,
                    style: const TextStyle(
                        fontFamily: Kawaii.displayFamily,
                        fontWeight: FontWeight.w800,
                        fontSize: 15,
                        color: Kawaii.ink)),
                const SizedBox(height: 2),
                Text(sub,
                    style: TextStyle(
                        fontFamily: Kawaii.displayFamily,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: Kawaii.ink.withValues(alpha: 0.75))),
              ])),
          KawaiiIconButton(
            icon: Icons.close_rounded,
            label: 'Remove ${p.title}',
            fill: Kawaii.cardOf(context),
            size: 40,
            onTap: () => _remove(p),
          ),
        ]),
      ),
    );
  }
}
