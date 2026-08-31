/// Strict decoding helpers for every wire model.
///
/// **A client that accepts two shapes hides a server sending the wrong one.**
/// The web build lost four screens to exactly that tolerance: four routes
/// declared `{record, extras}` and answered with the bare record, nothing threw
/// because the client had been written to accept either shape, and
/// `/api/admin/candidates/{id}` printed *"Account: None"* for every candidate on
/// the platform, its applications rail sat permanently empty, `/companies/{id}`
/// loaded for ever, and `/seeker/saved` drew "Confidential" over real employers.
///
/// So there is no `??` fallback chain anywhere in this layer. A field that the
/// contract declares required and the server did not send is a [WireFormatException],
/// which surfaces as [ApiErrorKind.malformedResponse] — visible, reported, fixed.
///
/// The one thing these helpers *are* lenient about is **type**, and only where
/// the API is genuinely polymorphic by design:
///
///  * money is `String` outbound and number inbound (`docs/decisions.md` D-002);
///  * `int` fields can arrive as `1` or `1.0` through JSON.
///
/// Both are documented server behaviours, not guesses.
library;

import '../../core/utils/format.dart';

class WireFormatException implements Exception {
  WireFormatException(this.field, this.reason, [this.saw]);

  final String field;
  final String reason;
  final Object? saw;

  @override
  String toString() =>
      'WireFormatException($field: $reason${saw == null ? '' : ', saw ${saw.runtimeType} $saw'})';
}

/// A JSON object, checked once at the boundary so every getter below is safe.
class Wire {
  Wire(this.json, this.context);

  final Map<String, dynamic> json;

  /// The model being decoded, for the error message. A `WireFormatException`
  /// that does not say which payload it came from costs an hour.
  final String context;

  static Wire of(Object? value, String context) {
    if (value is Map<String, dynamic>) return Wire(value, context);
    if (value is Map) return Wire(Map<String, dynamic>.from(value), context);
    throw WireFormatException(context, 'expected an object', value);
  }

  static List<Wire> listOf(Object? value, String context) {
    if (value is! List) {
      throw WireFormatException(context, 'expected a list', value);
    }
    return value.map((e) => Wire.of(e, context)).toList(growable: false);
  }

  Never _fail(String field, String reason, Object? saw) =>
      throw WireFormatException('$context.$field', reason, saw);

  bool has(String field) => json[field] != null;

  // --- required -------------------------------------------------------------

  String str(String field) {
    final v = json[field];
    if (v is String) return v;
    if (v == null) _fail(field, 'required, but was absent or null', v);
    _fail(field, 'expected a string', v);
  }

  int integer(String field) {
    final v = json[field];
    if (v is int) return v;
    // JSON has one number type; a whole value can arrive as 1.0.
    if (v is double && v == v.truncateToDouble()) return v.toInt();
    if (v == null) _fail(field, 'required, but was absent or null', v);
    _fail(field, 'expected an integer', v);
  }

  bool boolean(String field, {bool? orElse}) {
    final v = json[field];
    if (v is bool) return v;
    if (v == null && orElse != null) return orElse;
    if (v == null) _fail(field, 'required, but was absent or null', v);
    _fail(field, 'expected a boolean', v);
  }

  /// A required timestamp. **Goes through `parseStamp`**, so a bare value from
  /// this API is read as UTC rather than local.
  DateTime dateTime(String field) {
    final parsed = parseStamp(json[field]);
    if (parsed == null) {
      _fail(field, 'required, but was absent or unparseable', json[field]);
    }
    return parsed;
  }

  T object<T>(String field, T Function(Wire) decode) {
    final v = json[field];
    if (v == null) _fail(field, 'required, but was absent or null', v);
    return decode(Wire.of(v, '$context.$field'));
  }

  List<T> list<T>(String field, T Function(Wire) decode) {
    final v = json[field];
    if (v == null) _fail(field, 'required, but was absent or null', v);
    return Wire.listOf(v, '$context.$field').map(decode).toList(growable: false);
  }

  // --- optional -------------------------------------------------------------

  String? strOrNull(String field) {
    final v = json[field];
    if (v == null) return null;
    if (v is String) return v.isEmpty ? null : v;
    _fail(field, 'expected a string or null', v);
  }

  int? intOrNull(String field) {
    final v = json[field];
    if (v == null) return null;
    if (v is int) return v;
    if (v is double && v == v.truncateToDouble()) return v.toInt();
    _fail(field, 'expected an integer or null', v);
  }

  DateTime? dateTimeOrNull(String field) => parseStamp(json[field]);

  T? objectOrNull<T>(String field, T Function(Wire) decode) {
    final v = json[field];
    if (v == null) return null;
    return decode(Wire.of(v, '$context.$field'));
  }

  /// An optional list. **Absent and empty are the same thing** for every list on
  /// this API — `job_types` empty means "just the primary", and no endpoint uses
  /// null-versus-empty to mean anything.
  List<T> listOrEmpty<T>(String field, T Function(Wire) decode) {
    final v = json[field];
    if (v == null) return const [];
    return Wire.listOf(v, '$context.$field').map(decode).toList(growable: false);
  }

  List<String> stringsOrEmpty(String field) {
    final v = json[field];
    if (v == null) return const [];
    if (v is! List) _fail(field, 'expected a list of strings or null', v);
    return v.map((e) => e.toString()).toList(growable: false);
  }

  /// **Money.** `min_salary`, `max_salary`, `current_ctc`, `expected_ctc` all
  /// arrive as a `String` because they are SQL `DECIMAL` columns — a float would
  /// lose precision on money, so pydantic is right to serialise them this way.
  /// Parsing them is this client's obligation, not the server's defect.
  double? money(String field) {
    final v = json[field];
    if (v == null) return null;
    final n = asNumber(v);
    if (n == null) _fail(field, 'expected a number or numeric string', v);
    return n;
  }

  /// A CSV column (`job_types`, `benefits`). Split, trimmed, blanks dropped.
  List<String> csv(String field) {
    final raw = strOrNull(field);
    if (raw == null) return const [];
    return raw
        .split(',')
        .map((s) => s.trim())
        .where((s) => s.isNotEmpty)
        .toList(growable: false);
  }
}

/// Drop nulls before sending.
///
/// Every request body on this API treats an absent key and an explicit null
/// differently in at least one place, and sending `null` for a field the caller
/// simply did not touch is how a partial round-trip **writes NULL over a stored
/// value** — the failure that dropped the date applications closed on a job when
/// somebody changed its title.
///
/// So: build the map with only the keys you mean to write, and run it through
/// this. To clear a field deliberately, send an empty string — which is what the
/// forms do.
Map<String, dynamic> compact(Map<String, dynamic> body) {
  final out = <String, dynamic>{};
  body.forEach((k, v) {
    if (v != null) out[k] = v;
  });
  return out;
}
