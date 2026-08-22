String dateLabelDe(DateTime dt, DateTime now) {
  final d = DateTime(dt.year, dt.month, dt.day);
  final n = DateTime(now.year, now.month, now.day);

  final diffDays = n.difference(d).inDays;

  if (diffDays == 0) return 'Heute';
  if (diffDays == 1) return 'Gestern';

  String two(int v) => v.toString().padLeft(2, '0');
  return '${two(dt.day)}.${two(dt.month)}.${dt.year}';
}
