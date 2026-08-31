/// Saved jobs.
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/providers.dart';
import '../../../data/models/models.dart';

final savedJobsProvider =
    FutureProvider.autoDispose<SavedJobListOut>((ref) async {
  return ref.watch(seekerRepositoryProvider).saved(perPage: 50);
});
