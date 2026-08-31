/// The seeker's own record: profile, history, links, applications, saved jobs,
/// alerts, notifications, files.
library;

import 'package:dio/dio.dart';

import '../../core/network/api_client.dart';
import '../models/models.dart';
import '../models/wire.dart';

class SeekerRepository {
  const SeekerRepository(this._api);
  final ApiClient _api;

  // =========================================================================
  // Profile
  // =========================================================================

  Future<SeekerProfileOut> profile() async {
    final json = await _api.get<Map<String, dynamic>>('/api/seeker/profile');
    return SeekerProfileOut.decode(json);
  }

  /// `PATCH /api/seeker/profile`. **`section` is required** — the profile is
  /// saved a card at a time and the server decides which fields a given section
  /// may write. See `docs/decisions.md` D-003.
  ///
  /// [fields] must carry **every field of that section**, including the ones the
  /// reader did not change. A partial round-trip writes NULL over what it
  /// omitted — that is how changing a job's title once dropped the date
  /// applications closed on it.
  Future<SeekerProfileOut> updateProfile({
    required String section,
    required Map<String, dynamic> fields,
  }) async {
    final json = await _api.patch<Map<String, dynamic>>(
      '/api/seeker/profile',
      body: {'section': section, ...compact(fields)},
    );
    return SeekerProfileOut.decode(json);
  }

  /// Skills are set through the profile patch with `skill_ids`.
  ///
  /// **Two stores are written server-side** — `candidates.key_skills` (a
  /// denormalised CSV) and `candidate_skills` (the link table search joins on) —
  /// plus a completeness rescore. Never try to write one of them directly.
  Future<SeekerProfileOut> setSkills(List<int> skillIds) =>
      updateProfile(section: 'skills', fields: {'skill_ids': skillIds});

  Future<List<SkillOut>> lookupSkills(String term) async {
    final json = await _api.get<dynamic>(
      '/api/seeker/skills',
      query: {'q': term},
    );
    final list = json is Map ? json['items'] : json;
    return SkillOut.decodeList(list ?? const []);
  }

  Future<SeekerProfileOut> updatePrivacy({
    bool? isSearchable,
    bool? isPublic,
  }) async {
    final json = await _api.patch<Map<String, dynamic>>(
      '/api/seeker/privacy',
      body: compact({'is_searchable': isSearchable, 'is_public': isPublic}),
    );
    return SeekerProfileOut.decode(json);
  }

  /// Irreversible. The caller confirms hard before this is ever reached.
  Future<void> deleteAccount() async {
    await _api.delete<Map<String, dynamic>>('/api/seeker/account');
    await _api.clearSession();
  }

  // =========================================================================
  // History — employment, education, certifications
  // =========================================================================
  //
  // These feed completeness through COLUMNS, not weights.
  // `COMPLETENESS_WEIGHTS` totals exactly 100 and matches the CodeIgniter build
  // so a score means the same thing on both sides; adding an entry for
  // employment would mean taking points off something else and re-weighting
  // every stored score on the platform. Instead `sync_denormalised()` writes
  // current_company / current_designation / highest_education, which are
  // already weighted and already what recruiter search filters on.
  //
  // Rendered in the order received — history.py's three *_order() helpers
  // decide it, each ending id.desc(). Re-sorting here would make the profile
  // screen and the resume disagree about the same rows.

  static const _historyPaths = {
    HistoryKind.employment: '/api/seeker/employment',
    HistoryKind.education: '/api/seeker/education',
    HistoryKind.certifications: '/api/seeker/certifications',
  };

  Future<List<HistoryEntry>> history(HistoryKind kind) async {
    final json = await _api.get<dynamic>(_historyPaths[kind]!);
    return HistoryEntry.decodeList(json);
  }

  Future<void> addHistory(HistoryKind kind, Map<String, dynamic> fields) =>
      _api.post<dynamic>(_historyPaths[kind]!, body: compact(fields));

  Future<void> editHistory(
    HistoryKind kind,
    int entryId,
    Map<String, dynamic> fields,
  ) =>
      _api.put<dynamic>('${_historyPaths[kind]!}/$entryId', body: compact(fields));

  Future<void> deleteHistory(HistoryKind kind, int entryId) =>
      _api.delete<dynamic>('${_historyPaths[kind]!}/$entryId');

  // =========================================================================
  // Online links
  // =========================================================================

  Future<List<LinkEntry>> links() async {
    final json = await _api.get<dynamic>('/api/seeker/links');
    return LinkEntry.decodeList(json);
  }

  /// `sort_order` is **a sort key, not an insert-before index.**
  Future<void> addLink({required String url, String? label, int? sortOrder}) =>
      _api.post<dynamic>('/api/seeker/links',
          body: compact({'url': url, 'label': label, 'sort_order': sortOrder}));

  Future<void> editLink(int entryId,
          {required String url, String? label, int? sortOrder}) =>
      _api.put<dynamic>('/api/seeker/links/$entryId',
          body: compact({'url': url, 'label': label, 'sort_order': sortOrder}));

  Future<void> deleteLink(int entryId) =>
      _api.delete<dynamic>('/api/seeker/links/$entryId');

  // =========================================================================
  // Applications
  // =========================================================================

  Future<MyApplicationListOut> applications({int page = 1, int perPage = 20}) async {
    final json = await _api.get<Map<String, dynamic>>(
      '/api/applications/mine',
      query: {'page': page, 'per_page': perPage},
    );
    return MyApplicationListOut.decode(json);
  }

  /// `POST /api/applications/{id}/withdraw` — **the route the web uses.**
  ///
  /// **Permanent.** `has_applied` counts an application row whatever its stage,
  /// so a withdrawn application still blocks re-applying, and a recruiter cannot
  /// reverse it either (`set_stage` refuses `withdrawn` with a 409). Nothing in
  /// the product can undo this, and the confirmation must say so.
  Future<void> withdraw(int applicationId) =>
      _api.post<dynamic>('/api/applications/$applicationId/withdraw');

  // =========================================================================
  // Saved and suggested
  // =========================================================================

  Future<SavedJobListOut> saved({int page = 1, int perPage = 20}) async {
    final json = await _api.get<Map<String, dynamic>>(
      '/api/seeker/saved',
      query: {'page': page, 'per_page': perPage},
    );
    return SavedJobListOut.decode(json);
  }

  Future<List<JobOut>> suggested() async {
    final json = await _api.get<dynamic>('/api/seeker/suggested');
    final list = json is Map ? json['items'] : json;
    if (list is! List) return const [];
    return list.map(JobOut.decode).toList(growable: false);
  }

  /// Who viewed me.
  ///
  /// **Read the totals out of the payload, never `list.length`.** This is the
  /// exact endpoint that once told a candidate opened forty times by three
  /// agencies that they had "3 views", because the list was capped at fifty and
  /// the label counted recruiter rows.
  Future<({List<Map<String, dynamic>> viewers, int total})> viewers() async {
    final json = await _api.get<Map<String, dynamic>>('/api/seeker/viewers');
    final raw = json['items'] ?? json['views'] ?? const [];
    final list = raw is List
        ? raw.map((e) => Map<String, dynamic>.from(e as Map)).toList()
        : <Map<String, dynamic>>[];
    final total = json['total'];
    return (
      viewers: list,
      total: total is int ? total : list.length,
    );
  }

  // =========================================================================
  // Alerts
  // =========================================================================

  Future<List<JobAlert>> alerts() async {
    final json = await _api.get<dynamic>('/api/seeker/alerts');
    return JobAlert.decodeList(json);
  }

  Future<void> createAlert({
    required String keyword,
    String? location,
    String frequency = 'daily',
  }) =>
      _api.post<dynamic>('/api/seeker/alerts',
          body: compact({
            'keyword': keyword,
            'location': location,
            'frequency': frequency,
          }));

  Future<void> toggleAlert(int alertId) =>
      _api.post<dynamic>('/api/seeker/alerts/$alertId/toggle');

  Future<void> deleteAlert(int alertId) =>
      _api.delete<dynamic>('/api/seeker/alerts/$alertId');

  // =========================================================================
  // Notifications
  // =========================================================================

  Future<NotificationListOut> notifications({int limit = 30}) async {
    final json = await _api.get<Map<String, dynamic>>(
      '/api/notifications',
      query: {'limit': limit},
    );
    return NotificationListOut.decode(json);
  }

  Future<void> markRead(int id) =>
      _api.post<dynamic>('/api/notifications/$id/read');

  Future<void> markAllRead() => _api.post<dynamic>('/api/notifications/read-all');

  Future<NotificationPrefs> notificationPrefs() async {
    final json = await _api.get<Map<String, dynamic>>('/api/notifications/preferences');
    return NotificationPrefs.decode(json);
  }

  Future<NotificationPrefs> setNotificationPrefs(NotificationPrefs prefs) async {
    final json = await _api.put<Map<String, dynamic>>(
      '/api/notifications/preferences',
      body: prefs.toJson(),
    );
    return NotificationPrefs.decode(json);
  }

  // =========================================================================
  // Files
  // =========================================================================

  /// Upload a CV. The server validates type and size; this is the courtesy copy.
  Future<SeekerProfileOut> uploadResume({
    required String filePath,
    required String fileName,
    void Function(int sent, int total)? onProgress,
    CancelToken? cancelToken,
  }) async {
    final form = FormData.fromMap({
      'file': await MultipartFile.fromFile(filePath, filename: fileName),
    });
    final response = await _api.raw.post<Map<String, dynamic>>(
      '/api/seeker/profile/resume',
      data: form,
      onSendProgress: onProgress,
      cancelToken: cancelToken,
    );
    return SeekerProfileOut.decode(response.data);
  }

  /// Upload a profile photograph.
  ///
  /// **A deliberate upload does not go through the document detector** — someone
  /// choosing their own photograph is making a statement, not leaving us a
  /// guess. It *is* re-encoded through Pillow server-side, which drops EXIF,
  /// colour profiles and anything appended after the image data.
  Future<SeekerProfileOut> uploadPhoto({
    required String filePath,
    required String fileName,
    void Function(int sent, int total)? onProgress,
    CancelToken? cancelToken,
  }) async {
    final form = FormData.fromMap({
      'file': await MultipartFile.fromFile(filePath, filename: fileName),
    });
    final response = await _api.raw.post<Map<String, dynamic>>(
      '/api/seeker/profile/photo',
      data: form,
      onSendProgress: onProgress,
      cancelToken: cancelToken,
    );
    return SeekerProfileOut.decode(response.data);
  }

  /// Fetch the CV **into memory**.
  ///
  /// `GET /api/files/resume/{id}` is session-checked and answers
  /// `octet-stream` with `no-store`. **It is never written to disk** — a
  /// photograph is public, a resume is not, and a cached CV on a shared or lost
  /// device is the whole employment history of the person carrying it.
  Future<List<int>> resumeBytes(int candidateId) async {
    final response = await _api.raw.get<List<int>>(
      '/api/files/resume/$candidateId',
      options: Options(responseType: ResponseType.bytes),
    );
    return response.data ?? const [];
  }

  /// Parse a CV into profile fields without committing them.
  ///
  /// Extraction is heuristic, so the reading is **shown back for confirmation**
  /// rather than trusted — the same rule the web resume intake follows.
  Future<Map<String, dynamic>> parseResume({
    required String filePath,
    required String fileName,
  }) async {
    final form = FormData.fromMap({
      'file': await MultipartFile.fromFile(filePath, filename: fileName),
    });
    final response = await _api.raw.post<Map<String, dynamic>>(
      '/api/resumes/parse',
      data: form,
    );
    return response.data ?? const {};
  }
}

enum HistoryKind {
  employment('Employment'),
  education('Education'),
  certifications('Certifications');

  const HistoryKind(this.label);
  final String label;
}
