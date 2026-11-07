// Pure Dart helpers: dates, quantity parsing and display.

const List<String> _months = [
  'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
];
const List<String> _weekdaysShort = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
const List<String> _weekdaysLong = [
  'Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday', 'Sunday'
];

DateTime mondayOf(DateTime d) => DateTime(d.year, d.month, d.day - (d.weekday - 1));
DateTime addDays(DateTime d, int days) => DateTime(d.year, d.month, d.day + days);

String isoDate(DateTime d) =>
    '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

bool isSameDay(DateTime a, DateTime b) =>
    a.year == b.year && a.month == b.month && a.day == b.day;

String weekdayShort(int index) => _weekdaysShort[index];
String weekdayLong(int index) => _weekdaysLong[index];
String monthShort(DateTime d) => _months[d.month - 1];

/// "Nov 9 – 15" or "Nov 30 – Dec 6".
String weekRangeLabel(DateTime monday) {
  final end = addDays(monday, 6);
  final start = '${_months[monday.month - 1]} ${monday.day}';
  final stop = monday.month == end.month ? '${end.day}' : '${_months[end.month - 1]} ${end.day}';
  return '$start – $stop';
}

String capitalize(String s) {
  final t = s.trim();
  if (t.isEmpty) return t;
  return t[0].toUpperCase() + t.substring(1);
}

/// Parses "2", "1.5", "1/2" and "1 1/2".
/// Empty text -> null (meaning "to taste"). Invalid text -> -1.
double? parseQuantity(String input) {
  final s = input.trim().replaceAll(',', '.');
  if (s.isEmpty) return null;
  double total = 0;
  for (final part in s.split(RegExp(r'\s+'))) {
    if (part.contains('/')) {
      final ab = part.split('/');
      if (ab.length != 2) return -1;
      final a = double.tryParse(ab[0]);
      final b = double.tryParse(ab[1]);
      if (a == null || b == null || b == 0) return -1;
      total += a / b;
    } else {
      final v = double.tryParse(part);
      if (v == null) return -1;
      total += v;
    }
  }
  return total <= 0 ? -1 : total;
}

/// 0.5 -> "½", 1.5 -> "1½", 2 -> "2", 2.333 -> "2⅓", 0.2 -> "0.2".
String formatQuantity(double q) {
  const fractions = <(double, String)>[
    (0.25, '¼'),
    (0.5, '½'),
    (0.75, '¾'),
    (1 / 3, '⅓'),
    (2 / 3, '⅔'),
  ];
  final whole = q.truncate();
  final frac = q - whole;
  if (frac < 0.01) return '$whole';
  if (frac > 0.99) return '${whole + 1}';
  for (final (value, glyph) in fractions) {
    if ((frac - value).abs() < 0.02) {
      return whole == 0 ? glyph : '$whole$glyph';
    }
  }
  var text = q.toStringAsFixed(2);
  while (text.endsWith('0')) {
    text = text.substring(0, text.length - 1);
  }
  if (text.endsWith('.')) text = text.substring(0, text.length - 1);
  return text;
}

String amountLabel({required double quantity, required String unit, required bool toTaste}) {
  if (toTaste) return 'to taste';
  final q = formatQuantity(quantity);
  return unit.trim().isEmpty ? q : '$q ${unit.trim()}';
}
