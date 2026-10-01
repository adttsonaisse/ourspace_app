// Tiny date labels. No intl dependency on purpose.

const _months = [
  'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
  'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
];

String dayLabel(DateTime d) => '${d.day} ${_months[d.month - 1]}';

String dayLabelYear(DateTime d) =>
    '${d.day} ${_months[d.month - 1]} ${d.year}';

bool isSameDay(DateTime a, DateTime b) =>
    a.year == b.year && a.month == b.month && a.day == b.day;

int daysSince(DateTime since) {
  final now = DateTime.now();
  final a = DateTime(now.year, now.month, now.day);
  final b = DateTime(since.year, since.month, since.day);
  return a.difference(b).inDays;
}

String greeting() {
  final h = DateTime.now().hour;
  if (h < 11) return 'Good morning,';
  if (h < 18) return 'Good afternoon,';
  return 'Good evening,';
}
