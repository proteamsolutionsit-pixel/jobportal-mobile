/// The company directory.
///
/// `GET /api/companies` and `GET /api/companies/{id}` are both public — a
/// signed-out reader can browse employers, the same as they can browse jobs.
/// Nothing here requires a session, so none of it belongs behind the auth
/// guard in the router.
library;

import '../../core/network/api_client.dart';
import '../models/models.dart';
import '../models/wire.dart';

class CompaniesRepository {
  const CompaniesRepository(this._api);

  final ApiClient _api;

  /// One page of the directory.
  ///
  /// `per_page`, not `limit` — the server ignores `limit` entirely and quietly
  /// returns its own default, which looked like the parameter working until the
  /// page sizes were compared.
  Future<CompanyListOut> list({
    String? q,
    int page = 1,
    int perPage = 20,
  }) async {
    final json = await _api.get<Map<String, dynamic>>(
      '/api/companies',
      query: compact({
        'q': (q != null && q.trim().isNotEmpty) ? q.trim() : null,
        'page': page,
        'per_page': perPage,
      }),
    );
    return CompanyListOut.decode(json);
  }

  /// One company, with the jobs it currently has open.
  Future<CompanyDetailOut> detail(int companyId) async {
    final json =
        await _api.get<Map<String, dynamic>>('/api/companies/$companyId');
    return CompanyDetailOut.decode(json);
  }
}
