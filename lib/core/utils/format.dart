/// Presentation formatting.
///
/// A faithful port of `jobportal-python/frontend/src/lib/format.ts`, which is
/// itself a faithful port of the PHP build's `application/helpers/format_helper.php`.
///
/// **Ported rather than reinvented, on purpose.** Every screen in the product
/// renders the same strings — "4.5 LPA", "5 yrs 6 mos", "3 days ago" — and a
/// near-miss here shows up on every page. The web's `format.test.ts` fixtures
/// are ported alongside it in `test/core/format_test.dart`; if the two ever
/// disagree, this file is wrong.
///
/// Indian job-market conventions throughout: salaries in lakhs and crores,
/// experience in years and months.
library;

// ---------------------------------------------------------------------------
// Timestamps
// ---------------------------------------------------------------------------

/// Parse a timestamp this API sent. **Everything that reads a date goes through
/// here, and nothing calls `DateTime.parse` directly.**
///
/// Every datetime the API emits is **UTC** — the database session is pinned to
/// it and the server writes `datetime.now(UTC)` — but Pydantic serialises a
/// naive value with no zone suffix, as `2026-08-20T10:30:00`.
///
/// **`DateTime.parse` reads that form as LOCAL.** So without this function the
/// app would silently place every event hours from when it happened: a message
/// sent at 4:00 PM reporting itself as 10:30 AM. Nothing throws. The clock is
/// just wrong, everywhere, in a way that reads as a formatting quirk rather
/// than a bug — which is exactly why it survives review.
///
/// A value already carrying a zone (`Z` or an offset) is left alone, being
/// unambiguous already.
///
/// **Date-only `YYYY-MM-DD` is also read as UTC**, and here the Dart port
/// diverges from the web *implementation* in order to match its *behaviour*:
/// ECMAScript reads a bare date as UTC midnight by spec, so `format.ts` can
/// leave it to the platform. Dart reads it as **local** midnight, so it has to
/// be said out loud. Same result, different amount of code.
DateTime? parseStamp(Object? value) {
  if (value == null) return null;
  if (value is DateTime) return value;
  if (value is int) return DateTime.fromMillisecondsSinceEpoch(value, isUtc: true);

  final raw = value.toString().trim();
  if (raw.isEmpty) return null;

  var text = raw.replaceFirst(' ', 'T');
  final zoned = RegExp(r'(?:Z|[+-]\d{2}:?\d{2})$', caseSensitive: false).hasMatch(text);

  if (!zoned) {
    // A date-only value needs a whole time part, not a bare Z. Dart's parser
    // only accepts a zone designator that FOLLOWS a time, so '2026-08-20Z'
    // returns null — which would have silently turned every date-only field
    // into the fallback dash.
    text += text.contains('T') ? 'Z' : 'T00:00:00Z';
  }

  return DateTime.tryParse(text);
}

/// "just now", "5 mins ago", "3 days ago", then an absolute date.
String timeAgo(Object? datetime, {String fallback = '-', DateTime? now}) {
  final ts = parseStamp(datetime);
  if (ts == null) return fallback;

  final diff = (now ?? DateTime.now()).difference(ts).inSeconds;
  if (diff < 0) return 'scheduled';
  if (diff < 60) return 'just now';
  if (diff < 3600) {
    final m = diff ~/ 60;
    return '$m min${m == 1 ? '' : 's'} ago';
  }
  if (diff < 86400) {
    final h = diff ~/ 3600;
    return '$h hour${h == 1 ? '' : 's'} ago';
  }
  if (diff < 2592000) {
    final d = diff ~/ 86400;
    return '$d day${d == 1 ? '' : 's'} ago';
  }
  return niceDate(datetime, fallback: fallback);
}

/// "20-08-2026" — day-first, zero-padded, numeric.
///
/// **One shape for the whole application.** A numeric date is only unambiguous
/// when it is always the same way round, so the order is decided here and
/// nowhere else: "08-05-2026" must never mean May on one screen and August on
/// the next. The server renders the identical shape into exports and email
/// (`backend/app/services/dates.py`), so a downloaded report and the screen it
/// came from read the same.
String niceDate(Object? datetime, {String fallback = '-'}) {
  final ts = parseStamp(datetime);
  if (ts == null) return fallback;
  final d = ts.toLocal();
  return '${_pad(d.day)}-${_pad(d.month)}-${d.year}';
}

/// "04:00 PM" on its own, for a row that already carries the date.
String clockTime(Object? datetime, {String fallback = '-'}) {
  final ts = parseStamp(datetime);
  if (ts == null) return fallback;
  final d = ts.toLocal();
  final h12 = d.hour % 12 == 0 ? 12 : d.hour % 12;
  return '${_pad(h12)}:${_pad(d.minute)} ${d.hour < 12 ? 'AM' : 'PM'}';
}

/// "2026-08-20", for a value handed to a date picker or sent back to the API.
/// The one place a date deliberately is not dd-mm-yyyy.
String dateInputValue(Object? datetime) {
  final ts = parseStamp(datetime);
  if (ts == null) return '';
  final d = ts.toLocal();
  return '${d.year}-${_pad(d.month)}-${_pad(d.day)}';
}

String _pad(int n) => n.toString().padLeft(2, '0');

// ---------------------------------------------------------------------------
// Money
// ---------------------------------------------------------------------------

/// Coerce whatever the wire carried into a number.
///
/// **Money arrives as a `String`** — `min_salary`, `max_salary`, `current_ctc`
/// and `expected_ctc` are all `string?` on the way out and `number?` on the way
/// in. See `docs/decisions.md` D-002. That is correct pydantic behaviour for a
/// SQL `DECIMAL` (a float would lose precision on money) and is not a defect to
/// report — it is an obligation on this client.
double? asNumber(Object? v) {
  if (v == null) return null;
  if (v is num) return v.toDouble();
  final s = v.toString().trim();
  if (s.isEmpty) return null;
  return double.tryParse(s);
}

/// Render an annual CTC the way Indian job boards do: 450000 → "4.5 LPA".
String inrLakhs(Object? amount, {String fallback = 'Not disclosed'}) {
  final n = asNumber(amount);
  if (n == null || n <= 0) return fallback;

  // Trailing zeros are trimmed so 500000 reads "5 LPA", not "5.00 LPA".
  String trim(double v) {
    final r = double.parse(v.toStringAsFixed(2));
    return r == r.truncateToDouble() ? r.toInt().toString() : r.toString();
  }

  if (n >= 10000000) return '${trim(n / 10000000)} Cr';
  return '${trim(n / 100000)} LPA';
}

/// "6 - 9 LPA", "6+ LPA", or the hidden-salary placeholder.
String salaryRange(Object? min, Object? max, {bool hidden = false}) {
  if (hidden) return 'Not disclosed';
  final lo = asNumber(min) ?? 0;
  final hi = asNumber(max) ?? 0;

  if (lo <= 0 && hi <= 0) return 'Not disclosed';
  if (hi <= 0) return '${inrLakhs(lo)}+';
  if (lo <= 0) return 'Up to ${inrLakhs(hi)}';

  // Share the unit suffix: "6 - 9 LPA" reads better than "6 LPA - 9 LPA".
  final loS = inrLakhs(lo);
  final hiS = inrLakhs(hi);
  final loUnit = loS.substring(loS.lastIndexOf(' ') + 1);
  final hiUnit = hiS.substring(hiS.lastIndexOf(' ') + 1);

  if (loUnit == hiUnit) return '${loS.substring(0, loS.lastIndexOf(' '))} - $hiS';
  return '$loS - $hiS';
}

/// The pay line, as the posting actually states it.
///
/// `salaryRange` above is the ANNUAL RANGE case and is left exactly as the PHP
/// helper wrote it, because that is what every posting written before 29 Aug
/// 2026 says. This wraps rather than replaces it: with no period and no mode
/// the two return the identical string.
///
/// Three things it adds, each of which was a real wrong answer:
///
///  * **A period.** Figures are stored as the recruiter typed them, so a
///    ₹45,000 role is `45000` with period `month` and must never render as
///    "0.45 LPA". Lakhs are an annual unit; reading a monthly figure in them is
///    off by twelve.
///  * **Fixed vs open-ended.** A single figure is indistinguishable from "and
///    above" on the wire — both are `min` with a null `max` — so "₹8 LPA
///    exactly" and "₹8 LPA upwards" printed the same "8 LPA+".
///  * **Negotiable, which is not Hidden.** Negotiable says there is no number
///    yet; hidden says there is one and it is not being published. **Hidden
///    wins when a posting is both**, because "Negotiable" would then be a claim
///    about a number that exists.
String payLabel(
  Object? min,
  Object? max, {
  bool hidden = false,
  String? period = 'year',
  String? mode = 'range',
}) {
  if (hidden) return 'Not disclosed';
  if (mode == 'negotiable') return 'Negotiable';

  final lo = asNumber(min) ?? 0;
  final hi = mode == 'fixed' ? 0.0 : (asNumber(max) ?? 0);
  if (lo <= 0 && hi <= 0) return 'Not disclosed';

  if (period == null || period.isEmpty || period == 'year') {
    if (mode == 'fixed') return inrLakhs(lo);
    return salaryRange(min, max);
  }

  final per = '/ $period';
  if (hi <= 0) {
    final one = '₹${groupIndian(lo)}';
    return mode == 'fixed' ? '$one $per' : '$one+ $per';
  }
  if (lo <= 0) return 'Up to ₹${groupIndian(hi)} $per';
  return '₹${groupIndian(lo)} - ₹${groupIndian(hi)} $per';
}

/// Indian digit grouping: 4500000 → "45,00,000". Last three, then pairs.
String groupIndian(num value) {
  final n = value.truncate().abs();
  final s = n.toString();
  if (s.length <= 3) return '${value < 0 ? '-' : ''}$s';

  final last3 = s.substring(s.length - 3);
  var rest = s.substring(0, s.length - 3);
  final buf = <String>[];
  while (rest.length > 2) {
    buf.insert(0, rest.substring(rest.length - 2));
    rest = rest.substring(0, rest.length - 2);
  }
  if (rest.isNotEmpty) buf.insert(0, rest);
  return '${value < 0 ? '-' : ''}${buf.join(',')},$last3';
}

/// Value for a numeric text field.
///
/// MySQL hands `DECIMAL` columns back as "900000.00", which renders as a stray
/// ".00" in the field. Empty stays empty, so a blank field never becomes a
/// literal 0.
String numVal(Object? v) {
  if (v == null) return '';
  final s = v.toString().trim();
  if (s.isEmpty) return '';
  final n = double.tryParse(s);
  if (n == null) return s;
  return n == n.truncateToDouble() ? n.toInt().toString() : n.toString();
}

// ---------------------------------------------------------------------------
// Experience, notice, files
// ---------------------------------------------------------------------------

/// "Fresher", "6 mos", "5 yrs", "5 yrs 6 mos".
String experienceLabel(int? years, [int? months]) {
  final y = years ?? 0;
  final m = months ?? 0;
  if (y <= 0 && m <= 0) return 'Fresher';

  final parts = <String>[];
  if (y > 0) parts.add('$y yr${y == 1 ? '' : 's'}');
  if (m > 0) parts.add('$m mo${m == 1 ? '' : 's'}');
  return parts.join(' ');
}

/// "2 - 5 yrs", "5+ yrs", "Any experience".
String experienceRangeLabel(int? min, int? max) {
  final lo = min ?? 0;
  if (max == null || max <= 0) {
    return lo > 0 ? '$lo+ yrs' : 'Any experience';
  }
  return '$lo - $max yrs';
}

String noticeLabel(int? days) {
  if (days == null) return 'Not specified';
  if (days <= 0) return 'Immediate';
  if (days < 30) return '$days days';
  final months = (days / 30).round();
  return '$months month${months == 1 ? '' : 's'}';
}

/// "812 B", "4.2 KB", "1.8 MB" — never a misleading "0 KB".
String fileSizeLabel(int? bytes) {
  final b = bytes ?? 0;
  if (b <= 0) return '—';
  if (b < 1024) return '$b B';
  if (b < 1048576) return '${(b / 1024 * 10).round() / 10} KB';
  return '${(b / 1048576 * 10).round() / 10} MB';
}

/// A count the server said may be a floor rather than a total.
///
/// `JobListOut.total_capped` exists because the backend stops counting rather
/// than running an unbounded `COUNT(*)` on a large table. Printing the capped
/// figure as if it were exact is a precise-looking wrong number, which is worse
/// than an obviously approximate one.
String resultCount(int total, {bool capped = false}) => capped ? '$total+' : '$total';
