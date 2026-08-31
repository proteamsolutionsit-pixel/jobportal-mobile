/// Persistence for the cookie jar.
///
/// **The jar holds `hh_token`, which is a live session. It is a credential store**,
/// so it lives in `flutter_secure_storage` — Android Keystore, iOS Keychain —
/// and never in `SharedPreferences`.
///
/// `cookie_jar`'s own `PersistCookieJar` writes to the application documents
/// directory as plain files, which is exactly what this must not do. So the
/// storage backend is replaced rather than the jar: `cookie_jar` already
/// abstracts persistence behind [Storage], and this is an implementation of it.
///
/// ## Keyed per environment
///
/// Cookies are scoped by domain, so dev (`127.0.0.1`) and production
/// (`jobsflood.com`) are naturally separate. The key prefix makes that explicit
/// and survives a base-URL change within one environment — without it, switching
/// targets carries a dead session across and every screen fails with a 401 that
/// looks like a server problem.
library;

import 'package:cookie_jar/cookie_jar.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../config/environment.dart';

class SecureCookieStorage implements Storage {
  SecureCookieStorage({FlutterSecureStorage? backend, String? namespace})
      : _backend = backend ??
            const FlutterSecureStorage(
              aOptions: AndroidOptions(encryptedSharedPreferences: true),
              iOptions: IOSOptions(accessibility: KeychainAccessibility.first_unlock),
            ),
        _namespace = namespace ?? Env.current.name;

  final FlutterSecureStorage _backend;
  final String _namespace;

  String _key(String key) => 'cookies.$_namespace.$key';

  @override
  Future<void> init(bool persistSession, bool ignoreExpires) async {
    // Nothing to open — the platform store is created on first write.
  }

  @override
  Future<String?> read(String key) => _backend.read(key: _key(key));

  @override
  Future<void> write(String key, String value) =>
      _backend.write(key: _key(key), value: value);

  @override
  Future<void> delete(String key) => _backend.delete(key: _key(key));

  @override
  Future<void> deleteAll(List<String> keys) async {
    // Deleted one at a time rather than through deleteAll(): the secure store is
    // shared with anything else the app keeps there, and wiping the whole
    // keychain to clear a session is the kind of shortcut that removes
    // something else six months later.
    for (final key in keys) {
      await _backend.delete(key: _key(key));
    }
  }
}
