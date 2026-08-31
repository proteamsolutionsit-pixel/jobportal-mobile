/// The seeker's own record.
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/providers.dart';
import '../../../data/models/models.dart';
import '../../../data/repositories/seeker_repository.dart';

final profileProvider = FutureProvider<SeekerProfileOut>((ref) {
  return ref.watch(seekerRepositoryProvider).profile();
});

final historyProvider =
    FutureProvider.autoDispose.family<List<HistoryEntry>, HistoryKind>((ref, kind) {
  return ref.watch(seekerRepositoryProvider).history(kind);
});

final linksProvider = FutureProvider.autoDispose<List<LinkEntry>>((ref) {
  return ref.watch(seekerRepositoryProvider).links();
});

final alertsProvider = FutureProvider.autoDispose<List<JobAlert>>((ref) {
  return ref.watch(seekerRepositoryProvider).alerts();
});

final notificationPrefsProvider =
    FutureProvider.autoDispose<NotificationPrefs>((ref) {
  return ref.watch(seekerRepositoryProvider).notificationPrefs();
});

final notificationsProvider =
    FutureProvider.autoDispose<NotificationListOut>((ref) {
  return ref.watch(seekerRepositoryProvider).notifications();
});

/// Who viewed me.
///
/// **The total comes from the payload, not the list.** This is the exact
/// endpoint that once told a candidate opened forty times by three agencies that
/// they had "3 views", because the list was capped at fifty and the label
/// counted recruiter rows.
final viewersProvider = FutureProvider.autoDispose<
    ({List<Map<String, dynamic>> viewers, int total})>((ref) {
  return ref.watch(seekerRepositoryProvider).viewers();
});
