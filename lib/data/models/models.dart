/// The wire models for the JobSeeker surface.
///
/// One class per declared response schema, field lists taken from
/// `docs/api-contract-generated.md` (generated from the running server's
/// `/openapi.json`). **Strict** — see `wire.dart` for why.
library;

import '../../core/constants/enums.dart';
import 'wire.dart';

// ===========================================================================
// Account
// ===========================================================================

/// `UserOut`. Note what it deliberately does **not** carry: `password_hash` is
/// omitted from the schema and there is a server test asserting it.
class UserOut {
  const UserOut({
    required this.id,
    required this.email,
    required this.fullName,
    required this.role,
    required this.status,
    this.companyId,
    this.candidateId,
    this.mustSetPassword = false,
    this.emailVerifiedAt,
    this.impersonating = false,
    this.actorEmail,
    this.actorName,
  });

  final int id;
  final String email;
  final String fullName;
  final String role;
  final String status;
  final int? companyId;

  /// Null until the account has a candidate record. A seeker who registered but
  /// has never opened their profile can legitimately have none.
  final int? candidateId;

  /// **Enforced in the auth dependency, not by a client redirect.** Honour it
  /// because it is the right UX; it is not the control.
  final bool mustSetPassword;

  /// Stamped by signing in with an emailed code, **not** by registration —
  /// filling in a form proves nothing about the address in it.
  final DateTime? emailVerifiedAt;

  final bool impersonating;
  final String? actorEmail;
  final String? actorName;

  bool get isSeeker => role == 'seeker';
  bool get isEmailVerified => emailVerifiedAt != null;

  factory UserOut.fromWire(Wire w) => UserOut(
        id: w.integer('id'),
        email: w.str('email'),
        fullName: w.str('full_name'),
        role: w.str('role'),
        status: w.str('status'),
        companyId: w.intOrNull('company_id'),
        candidateId: w.intOrNull('candidate_id'),
        mustSetPassword: w.boolean('must_set_password', orElse: false),
        emailVerifiedAt: w.dateTimeOrNull('email_verified_at'),
        impersonating: w.boolean('impersonating', orElse: false),
        actorEmail: w.strOrNull('actor_email'),
        actorName: w.strOrNull('actor_name'),
      );

  static UserOut decode(Object? json) =>
      UserOut.fromWire(Wire.of(json, 'UserOut'));
}

/// `Message` — `{detail}`. Used by every endpoint whose answer is a sentence.
class Message {
  const Message(this.detail);
  final String detail;

  factory Message.fromWire(Wire w) => Message(w.str('detail'));
  static Message decode(Object? json) =>
      Message.fromWire(Wire.of(json, 'Message'));
}

// ===========================================================================
// Company
// ===========================================================================

class CompanyOut {
  const CompanyOut({
    required this.id,
    required this.name,
    this.slug,
    this.logoPath,
    this.industry,
    this.city,
    this.website,
    this.about,
    this.jobCount,
  });

  final int id;
  final String name;
  final String? slug;
  final String? logoPath;
  final String? industry;
  final String? city;
  final String? website;
  final String? about;
  final int? jobCount;

  factory CompanyOut.fromWire(Wire w) => CompanyOut(
        id: w.integer('id'),
        name: w.str('name'),
        slug: w.strOrNull('slug'),
        logoPath: w.strOrNull('logo_path'),
        industry: w.strOrNull('industry'),
        city: w.strOrNull('city'),
        website: w.strOrNull('website'),
        about: w.strOrNull('about'),
        jobCount: w.intOrNull('job_count'),
      );
}

// ===========================================================================
// Jobs
// ===========================================================================

class JobOut {
  const JobOut({
    required this.id,
    required this.title,
    required this.slug,
    required this.description,
    required this.location,
    required this.minExperience,
    required this.hideSalary,
    required this.skillLevel,
    required this.jobType,
    required this.workMode,
    required this.vacancies,
    required this.status,
    this.responsibilities,
    this.requirements,
    this.keySkills,
    this.maxExperience,
    this.minSalary,
    this.maxSalary,
    this.salaryPeriod = 'year',
    this.salaryMode = 'range',
    this.jobTypes = const [],
    this.benefits = const [],
    this.benefitsOther,
    this.descriptionFormat = 'text',
    this.industry,
    this.viewCount,
    this.applicationCount,
    this.education,
    this.functionalArea,
    this.expiresAt,
    this.postedAt,
    this.company,
  });

  final int id;
  final String title;
  final String slug;
  final String description;
  final String location;
  final int minExperience;

  /// **Informational only.** The router has already blanked the figures before
  /// serialising — "a number the API has been told not to show must never leave
  /// the server, or hidden only means hidden in one client." Use it to render
  /// "Not disclosed"; never to decide whether to hide something you were sent.
  final bool hideSalary;

  final String skillLevel;
  final String jobType;
  final String workMode;
  final int vacancies;
  final String status;

  final String? responsibilities;
  final String? requirements;
  final String? keySkills;
  final int? maxExperience;

  /// `String` on the wire — a SQL DECIMAL. See `docs/decisions.md` D-002.
  final double? minSalary;
  final double? maxSalary;

  final String salaryPeriod;
  final String salaryMode;

  /// Every type this posting is offered under, **primary first**, then the rest
  /// in the vocabulary's own order. Empty on the wire means "just the primary" —
  /// that read-side fallback is the whole backward-compatibility story, because
  /// the importer, the seed and the CodeIgniter migration all set only
  /// `job_type`. Resolved here so no screen has to know.
  final List<String> jobTypes;

  final List<String> benefits;
  final String? benefitsOther;
  final String descriptionFormat;

  final String? industry;
  final int? viewCount;
  final int? applicationCount;
  final String? education;
  final String? functionalArea;

  /// When applications close. Distinct from [status], which is the posting's own
  /// state.
  final DateTime? expiresAt;
  final DateTime? postedAt;
  final CompanyOut? company;

  bool get isOpen => status == 'active';
  bool get isNegotiable => salaryMode == 'negotiable';
  bool get isHtmlDescription => descriptionFormat == 'html';

  factory JobOut.fromWire(Wire w) {
    final primary = w.str('job_type');
    final declared = canonicalise(jobTypeValues, w.csv('job_types'));

    // Primary first, then the rest in vocabulary order — mirrors the server's
    // job_types_of() so two reads of the same posting never disagree.
    final types = declared.isEmpty
        ? [primary]
        : <String>[
            if (declared.contains(primary)) primary,
            ...declared.where((t) => t != primary),
          ];

    return JobOut(
      id: w.integer('id'),
      title: w.str('title'),
      slug: w.str('slug'),
      description: w.str('description'),
      location: w.str('location'),
      minExperience: w.integer('min_experience'),
      hideSalary: w.boolean('hide_salary'),
      skillLevel: w.str('skill_level'),
      jobType: primary,
      workMode: w.str('work_mode'),
      vacancies: w.integer('vacancies'),
      status: w.str('status'),
      responsibilities: w.strOrNull('responsibilities'),
      requirements: w.strOrNull('requirements'),
      keySkills: w.strOrNull('key_skills'),
      maxExperience: w.intOrNull('max_experience'),
      minSalary: w.money('min_salary'),
      maxSalary: w.money('max_salary'),
      salaryPeriod: w.strOrNull('salary_period') ?? 'year',
      salaryMode: w.strOrNull('salary_mode') ?? 'range',
      jobTypes: types,
      benefits: canonicalise(jobBenefits, w.csv('benefits')),
      benefitsOther: w.strOrNull('benefits_other'),
      descriptionFormat: w.strOrNull('description_format') ?? 'text',
      industry: w.strOrNull('industry'),
      viewCount: w.intOrNull('view_count'),
      applicationCount: w.intOrNull('application_count'),
      education: w.strOrNull('education'),
      functionalArea: w.strOrNull('functional_area'),
      expiresAt: w.dateTimeOrNull('expires_at'),
      postedAt: w.dateTimeOrNull('posted_at'),
      company: w.objectOrNull('company', CompanyOut.fromWire),
    );
  }

  static JobOut decode(Object? json) => JobOut.fromWire(Wire.of(json, 'JobOut'));

  /// The comma-separated `key_skills` column, as chips.
  List<String> get skillChips => (keySkills ?? '')
      .split(',')
      .map((s) => s.trim())
      .where((s) => s.isNotEmpty)
      .toList(growable: false);
}

/// `JobListOut`.
class JobListOut {
  const JobListOut({
    required this.items,
    required this.total,
    required this.page,
    required this.perPage,
    this.totalCapped = false,
  });

  final List<JobOut> items;

  /// **Read this, never `items.length`.** The web build once printed "3 views"
  /// to a candidate opened forty times, because the list was capped at fifty and
  /// the label counted the list.
  final int total;

  final int page;
  final int perPage;

  /// True when the backend stopped counting rather than running an unbounded
  /// `COUNT(*)`. The total is then a **floor** — render "500+", not "500".
  final bool totalCapped;

  bool get hasMore => page * perPage < total;

  factory JobListOut.fromWire(Wire w) => JobListOut(
        items: w.list('items', JobOut.fromWire),
        total: w.integer('total'),
        page: w.integer('page'),
        perPage: w.integer('per_page'),
        totalCapped: w.boolean('total_capped', orElse: false),
      );

  static JobListOut decode(Object? json) =>
      JobListOut.fromWire(Wire.of(json, 'JobListOut'));
}

/// `JobBriefOut` — the shape hung off an application.
class JobBriefOut {
  const JobBriefOut({
    required this.id,
    required this.title,
    required this.slug,
    required this.location,
    required this.jobType,
    required this.workMode,
    required this.status,
    this.company,
  });

  final int id;
  final String title;
  final String slug;
  final String location;
  final String jobType;
  final String workMode;
  final String status;
  final CompanyOut? company;

  bool get isOpen => status == 'active';

  factory JobBriefOut.fromWire(Wire w) => JobBriefOut(
        id: w.integer('id'),
        title: w.str('title'),
        slug: w.str('slug'),
        location: w.str('location'),
        jobType: w.str('job_type'),
        workMode: w.str('work_mode'),
        status: w.str('status'),
        company: w.objectOrNull('company', CompanyOut.fromWire),
      );
}

/// `JobStateOut` — what the Apply and Save buttons should read.
class JobStateOut {
  const JobStateOut({
    required this.jobId,
    required this.hasApplied,
    required this.isSaved,
  });

  final int jobId;

  /// **Counts an application row whatever its stage**, so this stays true after
  /// a withdrawal — which is exactly why withdrawing is final.
  final bool hasApplied;

  final bool isSaved;

  factory JobStateOut.fromWire(Wire w) => JobStateOut(
        jobId: w.integer('job_id'),
        hasApplied: w.boolean('has_applied'),
        isSaved: w.boolean('is_saved'),
      );

  static JobStateOut decode(Object? json) =>
      JobStateOut.fromWire(Wire.of(json, 'JobStateOut'));
}

/// `SavedToggleOut`.
class SavedToggleOut {
  const SavedToggleOut({
    required this.jobId,
    required this.saved,
    required this.detail,
  });

  final int jobId;
  final bool saved;
  final String detail;

  factory SavedToggleOut.fromWire(Wire w) => SavedToggleOut(
        jobId: w.integer('job_id'),
        saved: w.boolean('saved'),
        detail: w.str('detail'),
      );

  static SavedToggleOut decode(Object? json) =>
      SavedToggleOut.fromWire(Wire.of(json, 'SavedToggleOut'));
}

/// `SavedJobOut`.
class SavedJobOut {
  const SavedJobOut({required this.job, this.savedAt, this.isOpen = true});

  final JobOut job;
  final DateTime? savedAt;

  /// **A saved posting can close.** The card must say so rather than offering
  /// Apply — which is why this is a separate type instead of a bare `JobOut`.
  final bool isOpen;

  factory SavedJobOut.fromWire(Wire w) => SavedJobOut(
        job: w.object('job', JobOut.fromWire),
        savedAt: w.dateTimeOrNull('saved_at'),
        isOpen: w.boolean('is_open', orElse: true),
      );
}

class SavedJobListOut {
  const SavedJobListOut({
    required this.items,
    required this.total,
    required this.page,
    required this.perPage,
  });

  final List<SavedJobOut> items;
  final int total;
  final int page;
  final int perPage;

  bool get hasMore => page * perPage < total;

  factory SavedJobListOut.fromWire(Wire w) => SavedJobListOut(
        items: w.list('items', SavedJobOut.fromWire),
        total: w.integer('total'),
        page: w.integer('page'),
        perPage: w.integer('per_page'),
      );

  static SavedJobListOut decode(Object? json) =>
      SavedJobListOut.fromWire(Wire.of(json, 'SavedJobListOut'));
}

// ===========================================================================
// Applications
// ===========================================================================

class MyApplicationOut {
  const MyApplicationOut({
    required this.id,
    required this.jobId,
    required this.status,
    required this.appliedAt,
    this.statusChangedAt,
    this.job,
    this.recruiterNote,
  });

  final int id;
  final int jobId;
  final String status;
  final DateTime appliedAt;
  final DateTime? statusChangedAt;
  final JobBriefOut? job;

  /// Shown to the candidate. **Untrusted text — render as plain text, never as
  /// markup.**
  final String? recruiterNote;

  bool get isWithdrawn => status == withdrawnStage;

  /// A withdrawn or rejected application is over; anything else is live.
  bool get isActive => !isWithdrawn && status != 'rejected';

  factory MyApplicationOut.fromWire(Wire w) => MyApplicationOut(
        id: w.integer('id'),
        jobId: w.integer('job_id'),
        status: w.str('status'),
        appliedAt: w.dateTime('applied_at'),
        statusChangedAt: w.dateTimeOrNull('status_changed_at'),
        job: w.objectOrNull('job', JobBriefOut.fromWire),
        recruiterNote: w.strOrNull('recruiter_note'),
      );

  static MyApplicationOut decode(Object? json) =>
      MyApplicationOut.fromWire(Wire.of(json, 'MyApplicationOut'));
}

class MyApplicationListOut {
  const MyApplicationListOut({
    required this.items,
    required this.total,
    required this.page,
    required this.perPage,
  });

  final List<MyApplicationOut> items;
  final int total;
  final int page;
  final int perPage;

  bool get hasMore => page * perPage < total;

  factory MyApplicationListOut.fromWire(Wire w) => MyApplicationListOut(
        items: w.list('items', MyApplicationOut.fromWire),
        total: w.integer('total'),
        page: w.integer('page'),
        perPage: w.integer('per_page'),
      );

  static MyApplicationListOut decode(Object? json) =>
      MyApplicationListOut.fromWire(Wire.of(json, 'MyApplicationListOut'));
}

// ===========================================================================
// Profile
// ===========================================================================

class SkillOut {
  const SkillOut({
    required this.id,
    required this.name,
    required this.slug,
    this.category,
  });

  final int id;
  final String name;
  final String slug;
  final String? category;

  factory SkillOut.fromWire(Wire w) => SkillOut(
        id: w.integer('id'),
        name: w.str('name'),
        slug: w.str('slug'),
        category: w.strOrNull('category'),
      );

  static List<SkillOut> decodeList(Object? json) =>
      Wire.listOf(json, 'SkillOut').map(SkillOut.fromWire).toList();
}

class SeekerProfileOut {
  const SeekerProfileOut({
    required this.id,
    required this.fullName,
    required this.email,
    required this.isSearchable,
    required this.isPublic,
    required this.source,
    required this.status,
    required this.profileCompleteness,
    this.phone,
    this.gender,
    this.currentLocation,
    this.preferredLocations,
    this.experienceYears,
    this.experienceMonths,
    this.currentCompany,
    this.currentDesignation,
    this.currentCtc,
    this.expectedCtc,
    this.noticePeriodDays,
    this.highestEducation,
    this.headline,
    this.summary,
    this.photoPath,
    this.resumeName,
    this.resumeSize,
    this.resumeUploadedAt,
    this.hasResume = false,
    this.lastActiveAt,
    this.createdAt,
    this.updatedAt,
    this.skills = const [],
  });

  final int id;
  final String fullName;
  final String email;
  final bool isSearchable;
  final bool isPublic;
  final String source;
  final String status;

  /// **Server-owned.** Rescored on every write, and it is a campaign-targeting
  /// filter — a stale score decides who gets emailed. Display it; never compute
  /// or cache it.
  final int profileCompleteness;

  final String? phone;
  final String? gender;
  final String? currentLocation;
  final String? preferredLocations;
  final int? experienceYears;
  final int? experienceMonths;

  /// Written by `sync_denormalised()` from the employment rows. **It sets and
  /// never clears** — deleting your only current role does not blank this,
  /// deliberately, because that is far more often a correction in progress than
  /// a statement of unemployment. Do not present a retained value as an error.
  final String? currentCompany;
  final String? currentDesignation;

  /// `String` on the wire, number on the way in (D-002).
  final double? currentCtc;
  final double? expectedCtc;

  final int? noticePeriodDays;
  final String? highestEducation;
  final String? headline;
  final String? summary;
  final String? photoPath;
  final String? resumeName;
  final int? resumeSize;
  final DateTime? resumeUploadedAt;
  final bool hasResume;
  final DateTime? lastActiveAt;
  final DateTime? createdAt;
  final DateTime? updatedAt;
  final List<SkillOut> skills;

  factory SeekerProfileOut.fromWire(Wire w) => SeekerProfileOut(
        id: w.integer('id'),
        fullName: w.str('full_name'),
        email: w.str('email'),
        isSearchable: w.boolean('is_searchable'),
        isPublic: w.boolean('is_public'),
        source: w.str('source'),
        status: w.str('status'),
        profileCompleteness: w.integer('profile_completeness'),
        phone: w.strOrNull('phone'),
        gender: w.strOrNull('gender'),
        currentLocation: w.strOrNull('current_location'),
        preferredLocations: w.strOrNull('preferred_locations'),
        experienceYears: w.intOrNull('experience_years'),
        experienceMonths: w.intOrNull('experience_months'),
        currentCompany: w.strOrNull('current_company'),
        currentDesignation: w.strOrNull('current_designation'),
        currentCtc: w.money('current_ctc'),
        expectedCtc: w.money('expected_ctc'),
        noticePeriodDays: w.intOrNull('notice_period_days'),
        highestEducation: w.strOrNull('highest_education'),
        headline: w.strOrNull('headline'),
        summary: w.strOrNull('summary'),
        photoPath: w.strOrNull('photo_path'),
        resumeName: w.strOrNull('resume_name'),
        resumeSize: w.intOrNull('resume_size'),
        resumeUploadedAt: w.dateTimeOrNull('resume_uploaded_at'),
        hasResume: w.boolean('has_resume', orElse: false),
        lastActiveAt: w.dateTimeOrNull('last_active_at'),
        createdAt: w.dateTimeOrNull('created_at'),
        updatedAt: w.dateTimeOrNull('updated_at'),
        skills: w.listOrEmpty('skills', SkillOut.fromWire),
      );

  static SeekerProfileOut decode(Object? json) =>
      SeekerProfileOut.fromWire(Wire.of(json, 'SeekerProfileOut'));

  List<String> get preferredLocationList => (preferredLocations ?? '')
      .split(',')
      .map((s) => s.trim())
      .where((s) => s.isNotEmpty)
      .toList(growable: false);
}

/// One row of employment, education or certification history.
///
/// The three tables differ in their columns but share a shape on screen, so one
/// model carries all three with the unused fields null. **Rendered in the order
/// received** — `history.py`'s `*_order()` helpers decide it, each ending
/// `id.desc()`, and re-sorting here would make the profile and the resume
/// disagree about the same rows.
class HistoryEntry {
  const HistoryEntry({
    required this.id,
    required this.title,
    this.organisation,
    this.startDate,
    this.endDate,
    this.isCurrent = false,
    this.description,
    this.credentialId,
    this.credentialUrl,
    this.grade,
  });

  final int id;

  /// designation / degree / certification name.
  final String title;

  /// company / institution / issuing body.
  final String? organisation;

  final DateTime? startDate;
  final DateTime? endDate;
  final bool isCurrent;
  final String? description;
  final String? credentialId;
  final String? credentialUrl;
  final String? grade;

  factory HistoryEntry.fromWire(Wire w) => HistoryEntry(
        id: w.integer('id'),
        // The three endpoints name their headline column differently; the first
        // present wins. This is NOT the tolerant parsing wire.dart forbids —
        // these are three distinct declared schemas sharing one screen model,
        // and an entry with none of them still fails loudly below.
        title: w.strOrNull('designation') ??
            w.strOrNull('degree') ??
            w.strOrNull('name') ??
            w.str('title'),
        organisation: w.strOrNull('company_name') ??
            w.strOrNull('institution') ??
            w.strOrNull('issuer') ??
            w.strOrNull('organisation'),
        startDate: w.dateTimeOrNull('start_date') ?? w.dateTimeOrNull('issued_on'),
        endDate: w.dateTimeOrNull('end_date') ?? w.dateTimeOrNull('expires_on'),
        isCurrent: w.boolean('is_current', orElse: false),
        description: w.strOrNull('description'),
        credentialId: w.strOrNull('credential_id'),
        credentialUrl: w.strOrNull('credential_url'),
        grade: w.strOrNull('grade'),
      );

  static List<HistoryEntry> decodeList(Object? json) {
    // Both a bare list and {items: [...]} are accepted here because the three
    // history endpoints are not uniform in the generated contract. Anything
    // else still throws.
    if (json is Map && json['items'] != null) {
      return Wire.listOf(json['items'], 'HistoryEntry')
          .map(HistoryEntry.fromWire)
          .toList();
    }
    return Wire.listOf(json, 'HistoryEntry').map(HistoryEntry.fromWire).toList();
  }
}

/// A row of `candidate_links`.
class LinkEntry {
  const LinkEntry({
    required this.id,
    required this.url,
    this.label,
    this.sortOrder = 0,
  });

  final int id;
  final String url;
  final String? label;

  /// **A sort key, not an insert-before index.**
  final int sortOrder;

  /// The server validates the scheme (`_http_url()`) because a `javascript:`
  /// href would be stored XSS on the **admin's** page. Re-checked here on the
  /// principle that the client is the second line, not the first.
  bool get isSafe {
    final u = Uri.tryParse(url);
    return u != null && (u.scheme == 'http' || u.scheme == 'https');
  }

  factory LinkEntry.fromWire(Wire w) => LinkEntry(
        id: w.integer('id'),
        url: w.str('url'),
        label: w.strOrNull('label') ?? w.strOrNull('title'),
        sortOrder: w.intOrNull('sort_order') ?? 0,
      );

  static List<LinkEntry> decodeList(Object? json) {
    if (json is Map && json['items'] != null) {
      return Wire.listOf(json['items'], 'LinkEntry').map(LinkEntry.fromWire).toList();
    }
    return Wire.listOf(json, 'LinkEntry').map(LinkEntry.fromWire).toList();
  }
}

// ===========================================================================
// Notifications
// ===========================================================================

class NotificationOut {
  const NotificationOut({
    required this.id,
    required this.kind,
    required this.title,
    required this.read,
    required this.createdAt,
    this.body,
    this.link,
  });

  final int id;
  final String kind;
  final String title;
  final bool read;
  final DateTime createdAt;
  final String? body;

  /// **An in-app route, not a URL.** Mapping it to a route is deliberate;
  /// handing a server-supplied string to a URL launcher would make navigation a
  /// server-controlled primitive.
  final String? link;

  factory NotificationOut.fromWire(Wire w) => NotificationOut(
        id: w.integer('id'),
        kind: w.str('kind'),
        title: w.str('title'),
        read: w.boolean('read'),
        createdAt: w.dateTime('created_at'),
        body: w.strOrNull('body'),
        link: w.strOrNull('link'),
      );
}

class NotificationListOut {
  const NotificationListOut({
    required this.items,
    required this.unread,
    this.more = false,
  });

  final List<NotificationOut> items;

  /// **The badge count.** Not `items.length` — the list is capped by `limit`.
  final int unread;

  final bool more;

  factory NotificationListOut.fromWire(Wire w) => NotificationListOut(
        items: w.list('items', NotificationOut.fromWire),
        unread: w.integer('unread'),
        more: w.boolean('more', orElse: false),
      );

  static NotificationListOut decode(Object? json) =>
      NotificationListOut.fromWire(Wire.of(json, 'NotificationListOut'));
}

/// `PrefsOut` — **three booleans in the running build.**
///
/// The richer per-event shape (Email / In-app / Both / None per event) is among
/// the 82 uncommitted files on the web side and is **not on production**. Built
/// against what is live; see `docs/feature-parity.md`.
class NotificationPrefs {
  const NotificationPrefs({
    required this.emailApplication,
    required this.emailStatus,
    required this.emailDigest,
  });

  final bool emailApplication;
  final bool emailStatus;
  final bool emailDigest;

  factory NotificationPrefs.fromWire(Wire w) => NotificationPrefs(
        emailApplication: w.boolean('email_application'),
        emailStatus: w.boolean('email_status'),
        emailDigest: w.boolean('email_digest'),
      );

  static NotificationPrefs decode(Object? json) =>
      NotificationPrefs.fromWire(Wire.of(json, 'PrefsOut'));

  Map<String, dynamic> toJson() => {
        'email_application': emailApplication,
        'email_status': emailStatus,
        'email_digest': emailDigest,
      };

  NotificationPrefs copyWith({
    bool? emailApplication,
    bool? emailStatus,
    bool? emailDigest,
  }) =>
      NotificationPrefs(
        emailApplication: emailApplication ?? this.emailApplication,
        emailStatus: emailStatus ?? this.emailStatus,
        emailDigest: emailDigest ?? this.emailDigest,
      );
}

// ===========================================================================
// Alerts, suggestions, branding
// ===========================================================================

class JobAlert {
  const JobAlert({
    required this.id,
    required this.keyword,
    required this.frequency,
    required this.isActive,
    this.location,
    this.createdAt,
  });

  final int id;
  final String keyword;
  final String frequency;
  final bool isActive;
  final String? location;
  final DateTime? createdAt;

  factory JobAlert.fromWire(Wire w) => JobAlert(
        id: w.integer('id'),
        keyword: w.strOrNull('keyword') ?? w.strOrNull('query') ?? '',
        frequency: w.strOrNull('frequency') ?? 'daily',
        isActive: w.boolean('is_active', orElse: true),
        location: w.strOrNull('location'),
        createdAt: w.dateTimeOrNull('created_at'),
      );

  static List<JobAlert> decodeList(Object? json) {
    if (json is Map && json['items'] != null) {
      return Wire.listOf(json['items'], 'JobAlert').map(JobAlert.fromWire).toList();
    }
    return Wire.listOf(json, 'JobAlert').map(JobAlert.fromWire).toList();
  }
}

/// One row from `/api/suggest/*`.
///
/// **A suggestion list is not a whitelist** — nothing in the posting path
/// validates a submitted value against these tables, and there is a server test
/// guarding the *absence* of that check.
class Suggestion {
  const Suggestion({required this.label, this.id, this.kind, this.parent});

  final String label;
  final int? id;
  final String? kind;
  final String? parent;

  factory Suggestion.fromWire(Wire w) => Suggestion(
        label: w.strOrNull('label') ?? w.strOrNull('name') ?? w.str('title'),
        id: w.intOrNull('id'),
        kind: w.strOrNull('kind'),
        parent: w.strOrNull('parent'),
      );

  static List<Suggestion> decodeList(Object? json) {
    if (json is Map && json['items'] != null) {
      return Wire.listOf(json['items'], 'Suggestion').map(Suggestion.fromWire).toList();
    }
    if (json is List && (json.isEmpty || json.first is String)) {
      return json.map((e) => Suggestion(label: e.toString())).toList();
    }
    return Wire.listOf(json, 'Suggestion').map(Suggestion.fromWire).toList();
  }
}

/// `/api/branding` — `{name, logo_path}`.
///
/// **Fetched, not hardcoded.** The site name and logo are settings an admin can
/// change, and an uploaded logo overrides the bundled one. Hardcoding either
/// would leave the app showing something the product has moved on from.
class Branding {
  const Branding({required this.name, this.logoPath});

  final String name;
  final String? logoPath;

  static const fallback = Branding(name: 'JobPortal');

  factory Branding.fromWire(Wire w) => Branding(
        name: w.strOrNull('name') ?? 'JobPortal',
        logoPath: w.strOrNull('logo_path'),
      );

  static Branding decode(Object? json) =>
      Branding.fromWire(Wire.of(json, 'Branding'));
}
