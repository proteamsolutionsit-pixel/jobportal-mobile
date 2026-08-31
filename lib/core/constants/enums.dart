/// The controlled vocabularies, transcribed from `backend/app/models/__init__.py`.
///
/// **That file is the authority and this one is a copy.** `jobportal-python/CLAUDE.md`
/// states the rule plainly: *"Enum members are spelled exactly as the column
/// declares them; inventing one fails or truncates on MySQL."*
///
/// So these are **wire values, not labels**. The label maps below are separate,
/// and nothing sends a label.
///
/// ## Two of these are order-sensitive on the client
///
///  * **[jobBenefits]** — `jobs.benefits` is a canonical CSV written in this
///    order, so two postings with the same selection hold the same string and a
///    reader never has to sort. A client sending a selection sends it in this
///    order.
///  * **[jobTypeValues]** — `job_types_of()` returns primary first, then the
///    rest in the vocabulary's own order, so two requests for the same posting
///    never disagree. **Render in the order received.**
///
/// The server-side rule behind both — *"appended to, never reordered: an ENUM is
/// stored as its member's ORDINAL, so moving one rewrites the meaning of every
/// row already carrying it, in place, with no error and no warning"* — does not
/// bite the client directly, because the wire value here is the string. It is
/// quoted anyway, because it is the reason a member must never be reordered when
/// this file is synced against the server.
///
/// **Unknown members are dropped, never trusted.** A stale value must narrow a
/// search rather than crash a screen — the same read-side tolerance the server
/// applies to the `job_types` VARCHAR.
library;

// ---------------------------------------------------------------------------
// Accounts
// ---------------------------------------------------------------------------

/// `ROLES`. This app is the **seeker** client; the other three exist so that a
/// signed-in user of the wrong kind can be told so rather than shown a broken
/// screen.
const roleValues = <String>['admin', 'recruiter', 'recruiter_agent', 'seeker'];

/// `USER_STATUSES`. Only `active` may hold a session — `current_user_optional`
/// returns null for anything else, so the app sees a 401, not a status.
const userStatusValues = <String>['active', 'inactive', 'locked', 'pending'];

/// `CANDIDATE_STATUSES`.
const candidateStatusValues = <String>[
  'pending_update',
  'active',
  'inactive',
  'blacklisted',
];

/// `CANDIDATE_SOURCES`. A profile created through this app is `self_signup`;
/// one created by parsing an uploaded CV is `resume_upload`. The server decides.
const candidateSourceValues = <String>[
  'manual',
  'bulk_import',
  'self_signup',
  'resume_upload',
];

// ---------------------------------------------------------------------------
// Postings
// ---------------------------------------------------------------------------

/// `JOB_STATUSES`. A seeker only ever sees `active` in a listing; the others
/// reach the app through a saved job whose posting has since moved on, which is
/// what `SavedJobOut.is_open` is for.
const jobStatusValues = <String>['draft', 'active', 'paused', 'closed', 'expired'];

/// `SKILL_LEVELS` — the three portal tracks.
const skillLevelValues = <String>['fresher', 'experienced', 'unskilled'];

/// `SKILL_LEVEL_LABELS`, defined server-side once because views, forms and
/// search all read it.
const skillLevelLabels = <String, String>{
  'fresher': 'Fresher',
  'experienced': 'Experienced',
  'unskilled': 'Unskilled',
};

/// `JOB_TYPES`.
///
/// **`temporary` is not a second spelling of `contract`.** A contract is a
/// fixed-term engagement with its own deliverable and its own rate; temporary
/// staffing is cover — a season, a peak, somebody's leave. Every staffing agency
/// prices them as separate lines. Do not merge them in a filter or a label.
const jobTypeValues = <String>[
  'full_time',
  'part_time',
  'contract',
  'internship',
  'freelance',
  'temporary',
];

const jobTypeLabels = <String, String>{
  'full_time': 'Full time',
  'part_time': 'Part time',
  'contract': 'Contract',
  'temporary': 'Temporary',
  'internship': 'Internship',
  'freelance': 'Freelance',
};

/// `WORK_MODES`.
///
/// **`field` is a fourth location type, not a flavour of `onsite`.** A service
/// engineer, a field sales rep, a delivery role and a site surveyor have no
/// office to be on-site *at*.
const workModeValues = <String>['onsite', 'remote', 'hybrid', 'field'];

/// Humanising the column value would render the fourth as "Field", which is not
/// what anybody calls the thing. Named here so the posting, the card and the
/// listing rail cannot disagree about what a work mode is called.
const workModeLabels = <String, String>{
  'onsite': 'On-site',
  'remote': 'Remote',
  'hybrid': 'Hybrid',
  'field': 'On the Road / Field Work',
};

/// `SALARY_MODES` — how a posting states its pay.
///
///  * `range` — `min_salary`..`max_salary`, or an open-ended "min+".
///  * `fixed` — one exact figure in `min_salary`; `max_salary` is NULL and that
///    NULL means **"there is no upper end"**, not "and above".
///  * `negotiable` — no figure at all.
///
/// **`negotiable` is a different statement from `hide_salary`.** Negotiable says
/// there is no number yet; hidden says there is one and it is not being
/// published. A posting can be either, or both — and hidden wins, because
/// "Negotiable" would otherwise be a claim about a number that exists.
const salaryModeValues = <String>['range', 'fixed', 'negotiable'];

/// `SALARY_PERIODS`. **Figures are stored as entered in this period and are
/// never annualised on the way in**, so a ₹45,000 role is `45000` with period
/// `month`. Rendering that in lakhs is off by twelve.
const salaryPeriodValues = <String>['hour', 'day', 'week', 'month', 'year'];

/// `BENEFITS` — the owner's list, **in the order `jobs.benefits` stores them**.
///
/// "Other" is deliberately absent: it is the posting's own `benefits_other` free
/// text, "selected" exactly when that column is non-empty, so the state *"Other
/// is ticked and says nothing"* cannot be stored.
///
/// > Added 31 Aug 2026 and **not yet on production** — see
/// > `docs/change-baseline.md`. Treat as API PENDING.
const jobBenefits = <String>[
  'provident_fund',
  'esi',
  'health_insurance',
  'life_insurance',
  'paid_leave',
  'performance_bonus',
  'joining_bonus',
  'food_allowance',
  'travel_allowance',
  'transportation',
  'accommodation',
  'work_from_home',
  'flexible_hours',
];

const benefitLabels = <String, String>{
  'provident_fund': 'Provident Fund (PF)',
  'esi': 'ESI',
  'health_insurance': 'Health Insurance',
  'life_insurance': 'Life Insurance',
  'paid_leave': 'Paid Leave',
  'performance_bonus': 'Performance Bonus',
  'joining_bonus': 'Joining Bonus',
  'food_allowance': 'Food Allowance',
  'travel_allowance': 'Travel Allowance',
  'transportation': 'Transportation',
  'accommodation': 'Accommodation',
  'work_from_home': 'Work From Home',
  'flexible_hours': 'Flexible Working Hours',
};

/// `DESCRIPTION_FORMATS` — whether `jobs.description` holds plain text or
/// sanitised HTML. `text` is the default and is what every posting written
/// before 31 Aug 2026 carries, rendered with newlines preserved.
///
/// **The answer is recorded, not sniffed.** Sniffing for tags would have turned
/// the first plain description containing a "<" into one run-on paragraph.
const descriptionFormatValues = <String>['text', 'html'];

// ---------------------------------------------------------------------------
// Applications
// ---------------------------------------------------------------------------

/// `APPLICATION_STAGES`.
const applicationStageValues = <String>[
  'applied',
  'viewed',
  'shortlisted',
  'interview',
  'offered',
  'hired',
  'rejected',
  'withdrawn',
];

const applicationStageLabels = <String, String>{
  'applied': 'Applied',
  'viewed': 'Viewed',
  'shortlisted': 'Shortlisted',
  'interview': 'Interview',
  'offered': 'Offered',
  'hired': 'Hired',
  'rejected': 'Not taken forward',
  'withdrawn': 'Withdrawn',
};

/// `withdrawn` is **not a stage a recruiter may set** — `set_stage` refuses it
/// with a 409 and the recruiter's screen renders no control. It is reached only
/// by the candidate, and it is **permanent**: `has_applied` counts an
/// application row whatever its stage, so a withdrawn application still blocks
/// re-applying. Nothing in the product can undo it, and the confirmation dialog
/// must say so.
const withdrawnStage = 'withdrawn';

// ---------------------------------------------------------------------------
// Alerts, locations, notifications
// ---------------------------------------------------------------------------

/// `ALERT_FREQUENCIES`.
const alertFrequencyValues = <String>['daily', 'weekly'];

/// `LOCATION_KINDS` — the hierarchy, **coarsest first. Declaration order is part
/// of the column: MySQL sorts an ENUM by it.**
const locationKindValues = <String>['state', 'district', 'city', 'town', 'locality'];

/// `NOTIFY_CHANNELS` — how one kind of notification reaches a person.
/// **Declaration order is also the order the switch renders in.**
///
/// `none` is a member of the *type*, not an option on every event. Which events
/// may be silenced is decided per event server-side, and **the server refuses a
/// channel an event does not offer.** Only `application.rejected` may be
/// silenced completely; every other seeker event floors at in-app.
///
/// > The per-event preference API is **uncommitted**. The running build serves
/// > three booleans. See `docs/business-rules.md` §7.
const notifyChannelValues = <String>['both', 'email', 'in_app', 'none'];

const notifyChannelLabels = <String, String>{
  'both': 'Email and in-app',
  'email': 'Email only',
  'in_app': 'In-app only',
  'none': 'Do not notify me',
};

/// `LOGIN_CODE_PURPOSES`.
///
/// **This is NOT a channel list.** The server's own comment says it: *"verifying
/// a mobile number was deferred by the owner, so there is no 'sms' member and
/// nothing that would write one."* Do not add one.
const loginCodePurposeValues = <String>['login', 'verify_email'];

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

/// Look up a display label, falling back to the wire value itself.
///
/// Falling back rather than throwing is deliberate: a member added on the server
/// and not yet mirrored here should show the slug — ugly, and visibly a gap —
/// rather than blank the field or crash the screen.
String labelFor(Map<String, String> labels, String? value) {
  if (value == null || value.isEmpty) return '';
  return labels[value] ?? value;
}

/// Keep only members the client knows, **in the vocabulary's own order**.
///
/// Used for `job_types` and `benefits`, both of which cross the wire as a CSV.
/// Dropping the unknown rather than trusting it is the server's own read-side
/// rule: a stale value must narrow a search rather than crash a facet.
List<String> canonicalise(List<String> vocabulary, Iterable<String>? values) {
  if (values == null) return const [];
  final picked = values.toSet();
  return vocabulary.where(picked.contains).toList(growable: false);
}
