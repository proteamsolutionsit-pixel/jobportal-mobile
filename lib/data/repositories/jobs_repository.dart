/// Jobs: listing, search, detail, save, apply, suggestions.
library;

import '../../core/network/api_client.dart';
import '../models/models.dart';

/// The filter set the search screen holds.
///
/// **The plural forms are used and the singular ones are not.** `GET /api/jobs`
/// declares both (`location` and `locations[]`, `work_mode` and `work_modes[]`,
/// and so on); the plurals are the newer multi-select filters. Sending both in
/// one request is untested and the precedence is undocumented — task MOB-B-002
/// asks the backend to state it. Until then this sends exactly one family.
class JobQuery {
  const JobQuery({
    this.q,
    this.locations = const [],
    this.workModes = const [],
    this.jobTypes = const [],
    this.skillLevels = const [],
    this.skills = const [],
    this.companyIds = const [],
    this.expMin,
    this.expMax,
    this.minSalary,
    this.maxSalary,
    this.postedWithin,
    this.sort,
  });

  final String? q;
  final List<String> locations;
  final List<String> workModes;
  final List<String> jobTypes;
  final List<String> skillLevels;
  final List<String> skills;
  final List<int> companyIds;
  final int? expMin;
  final int? expMax;
  final double? minSalary;
  final double? maxSalary;

  /// Days.
  final int? postedWithin;
  final String? sort;

  bool get hasFilters =>
      locations.isNotEmpty ||
      workModes.isNotEmpty ||
      jobTypes.isNotEmpty ||
      skillLevels.isNotEmpty ||
      skills.isNotEmpty ||
      companyIds.isNotEmpty ||
      expMin != null ||
      expMax != null ||
      minSalary != null ||
      maxSalary != null ||
      postedWithin != null;

  int get filterCount => [
        locations.isNotEmpty,
        workModes.isNotEmpty,
        jobTypes.isNotEmpty,
        skillLevels.isNotEmpty,
        skills.isNotEmpty,
        expMin != null || expMax != null,
        minSalary != null || maxSalary != null,
        postedWithin != null,
      ].where((e) => e).length;

  Map<String, dynamic> toQuery({required int page, required int perPage}) => {
        'page': page,
        'per_page': perPage,
        if (q != null && q!.trim().isNotEmpty) 'q': q!.trim(),
        if (locations.isNotEmpty) 'locations': locations,
        if (workModes.isNotEmpty) 'work_modes': workModes,
        if (jobTypes.isNotEmpty) 'job_types': jobTypes,
        if (skillLevels.isNotEmpty) 'skill_levels': skillLevels,
        if (skills.isNotEmpty) 'skills': skills,
        if (companyIds.isNotEmpty) 'company_id': companyIds,
        if (expMin != null) 'exp_min': expMin,
        if (expMax != null) 'exp_max': expMax,
        if (minSalary != null) 'min_salary': minSalary,
        if (maxSalary != null) 'max_salary': maxSalary,
        if (postedWithin != null) 'posted_within': postedWithin,
        if (sort != null) 'sort': sort,
      };

  JobQuery copyWith({
    String? q,
    List<String>? locations,
    List<String>? workModes,
    List<String>? jobTypes,
    List<String>? skillLevels,
    List<String>? skills,
    List<int>? companyIds,
    int? expMin,
    int? expMax,
    double? minSalary,
    double? maxSalary,
    int? postedWithin,
    String? sort,
    bool clearFilters = false,
  }) {
    if (clearFilters) return JobQuery(q: q ?? this.q, sort: sort ?? this.sort);
    return JobQuery(
      q: q ?? this.q,
      locations: locations ?? this.locations,
      workModes: workModes ?? this.workModes,
      jobTypes: jobTypes ?? this.jobTypes,
      skillLevels: skillLevels ?? this.skillLevels,
      skills: skills ?? this.skills,
      companyIds: companyIds ?? this.companyIds,
      expMin: expMin ?? this.expMin,
      expMax: expMax ?? this.expMax,
      minSalary: minSalary ?? this.minSalary,
      maxSalary: maxSalary ?? this.maxSalary,
      postedWithin: postedWithin ?? this.postedWithin,
      sort: sort ?? this.sort,
    );
  }
}

class JobsRepository {
  const JobsRepository(this._api);
  final ApiClient _api;

  Future<JobListOut> search(JobQuery query, {int page = 1, int perPage = 20}) async {
    final json = await _api.get<Map<String, dynamic>>(
      '/api/jobs',
      query: query.toQuery(page: page, perPage: perPage),
    );
    return JobListOut.decode(json);
  }

  Future<JobOut> detail(int jobId) async {
    final json = await _api.get<Map<String, dynamic>>('/api/jobs/$jobId');
    return JobOut.decode(json);
  }

  /// `GET /api/jobs/{id}/state` — whether this seeker has applied or saved.
  /// Separate from the posting so a signed-out reader can still see the job.
  Future<JobStateOut> state(int jobId) async {
    final json = await _api.get<Map<String, dynamic>>('/api/jobs/$jobId/state');
    return JobStateOut.decode(json);
  }

  Future<List<JobOut>> similar(int jobId) async {
    final json = await _api.get<dynamic>('/api/jobs/$jobId/similar');
    final list = json is Map ? json['items'] : json;
    if (list is! List) return const [];
    return list.map(JobOut.decode).toList(growable: false);
  }

  /// **A toggle, not an idempotent set.** Calling it twice unsaves.
  Future<SavedToggleOut> toggleSaved(int jobId) async {
    final json = await _api.post<Map<String, dynamic>>('/api/jobs/$jobId/save');
    return SavedToggleOut.decode(json);
  }

  /// `POST /api/jobs/{id}/apply` — **the route the web client uses.**
  ///
  /// `POST /api/applications` is a second path to the same thing with no
  /// consumer; using it would mean a business-rule change could land on one
  /// client and not the other. Task MOB-B-003 asks for it to be removed or
  /// documented as an alias.
  ///
  /// **Never retried blindly.** A retry after a 500 can produce a second
  /// application row if the first partially succeeded, and applying twice is not
  /// something the candidate can undo — `has_applied` counts a row whatever its
  /// stage.
  Future<MyApplicationOut> apply(int jobId, {String? coverLetter}) async {
    final json = await _api.post<Map<String, dynamic>>(
      '/api/jobs/$jobId/apply',
      body: {
        if (coverLetter != null && coverLetter.trim().isNotEmpty)
          'cover_letter': coverLetter.trim(),
      },
    );
    return MyApplicationOut.decode(json);
  }

  /// The home rail. **`/api/home/jobs`, not `/api/jobs?per_page=8`** — the
  /// latter is a filterless public listing that cannot know about the admin's
  /// curation (`is_featured`, `featured_rank`), which is why the chosen order
  /// once had no route to the page it was chosen for.
  Future<List<JobOut>> homeJobs() async {
    final json = await _api.get<dynamic>('/api/home/jobs');
    final list = json is Map ? (json['items'] ?? json['jobs']) : json;
    if (list is! List) return const [];
    return list.map(JobOut.decode).toList(growable: false);
  }

  Future<Map<String, dynamic>> facets() async {
    return _api.get<Map<String, dynamic>>('/api/jobs/facets');
  }

  // --- suggestions ---------------------------------------------------------
  // Public endpoints, deliberately: the seeker's search box is on the
  // signed-out landing page, so a suggester behind a session is one that only
  // works after you sign in. Budget is 2 SQL statements and ~6 ms per
  // keystroke, so DEBOUNCE — do not fan out.

  Future<List<Suggestion>> suggestLocations(String term) async {
    if (term.trim().length < 2) return const [];
    final json = await _api.get<dynamic>(
      '/api/suggest/locations',
      query: {'q': term.trim()},
    );
    return Suggestion.decodeList(json);
  }

  Future<List<Suggestion>> suggestTitles(String term) async {
    if (term.trim().length < 2) return const [];
    final json = await _api.get<dynamic>(
      '/api/suggest/titles',
      query: {'q': term.trim()},
    );
    return Suggestion.decodeList(json);
  }
}
