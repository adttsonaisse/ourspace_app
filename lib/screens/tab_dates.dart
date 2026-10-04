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
          const KawaiiPageHeader(
              title: 'Date plans',
              subtitle: 'Never “what should we do?” again.',
              icon: Icons.calendar_month_rounded,
              bg: Kawaii.sunny),
          const SizedBox(height: 14),
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
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    KawaiiCard(
                      color: Kawaii.sunnySubtle,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const KawaiiPill(
                              label: 'idea jar is empty',
                              color: Colors.white),
                          const SizedBox(height: 10),
                          const Text('No dates yet',
                              style: TextStyle(
                                  fontSize: 22,
                                  fontWeight: FontWeight.w900,
                                  fontFamily: Kawaii.displayFamily)),
                          const Text(
                              'Tap + below to plan the first one together.',
                              style: TextStyle(fontWeight: FontWeight.w500)),
                          const SizedBox(height: 12),
                          KawaiiButton(
                            label: 'Plan a date',
                            icon: Icons.calendar_month_rounded,
                            color: KawaiiBtnColor.sunny,
                            onTap: widget.onSchedule,
                          ),
                        ],
                      ),
                    ),
                  ],
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
                  const SizedBox(height: 12),
                  Text(
                      upcoming.length <= 1
                          ? 'All plans'
                          : 'More plans — tap + to add',
                      style: const TextStyle(
                          fontWeight: FontWeight.w900,
                          fontFamily: Kawaii.displayFamily,
                          fontSize: 16)),
                  const SizedBox(height: 8),
                  ...upcoming
                      .skip(next == null ? 0 : 1)
                      .map(_planCard),
                  if (past > 0) ...[
                    const SizedBox(height: 8),
                    KawaiiCard(
                      color: Kawaii.cardOf(context),
                      child: Row(children: [
                        const KawaiiIcon(
                            icon: Icons.calendar_month_rounded,
                            bg: Kawaii.sunnySubtle,
                            size: 46,
                            iconSize: 22),
                        const SizedBox(width: 10),
                        Expanded(
                            child: Text(
                                'Past dates live here as memories — $past saved',
                                style: const TextStyle(
                                    fontWeight: FontWeight.w600,
                                    fontSize: 13))),
                        const Icon(Icons.arrow_forward_rounded),
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
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            KawaiiPill(
                label: 'NEXT UP • ${dayLabel(p.day).toUpperCase()}',
                color: Colors.white),
            const Spacer(),
            const KawaiiIcon(
                icon: Icons.wb_sunny_rounded,
                bg: Colors.white,
                size: 46,
                iconSize: 24),
          ]),
          const SizedBox(height: 8),
          Text(p.title,
              style: const TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.w900,
                  fontFamily: Kawaii.displayFamily,
                  color: Kawaii.ink)),
          if (detail.isNotEmpty)
            Text(detail,
                style: const TextStyle(
                    color: Kawaii.ink, fontWeight: FontWeight.w600)),
          const SizedBox(height: 12),
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
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: KawaiiCard(
        color: Kawaii.sunnySubtle,
        padding: const EdgeInsets.all(14),
        child: Row(children: [
          Container(
            width: 46,
            height: 46,
            decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(15),
                border: Border.all(color: Kawaii.ink, width: 2.5)),
            alignment: Alignment.center,
            child: Text('${p.day.day}',
                style: const TextStyle(
                    fontWeight: FontWeight.w900, fontSize: 18)),
          ),
          const SizedBox(width: 12),
          Expanded(
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                Text(p.title,
                    style: const TextStyle(fontWeight: FontWeight.w800)),
                Text(sub,
                    style: const TextStyle(
                        fontSize: 12, fontWeight: FontWeight.w600)),
              ])),
          GestureDetector(
            onTap: () => _remove(p),
            behavior: HitTestBehavior.opaque,
            child: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(999),
                  border: Border.all(color: Kawaii.ink, width: 2.5)),
              child: const Icon(Icons.close_rounded,
                  size: 16, color: Kawaii.ink),
            ),
          ),
        ]),
      ),
    );
  }
}
