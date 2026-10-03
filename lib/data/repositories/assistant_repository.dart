/// `/api/assistant` — the same assistant the web's floating widget talks to.
library;

import '../../core/network/api_client.dart';
import '../models/assistant.dart';

class AssistantRepository {
  const AssistantRepository(this._api);
  final ApiClient _api;

  /// The starter chips for whoever is signed in. The server picks them by
  /// role; nothing here hardcodes a suggestion.
  Future<AssistantIntents> intents() async => AssistantIntents.decode(
    await _api.get<dynamic>('/api/assistant/intents'),
  );

  /// One turn. [context] is the previous answer's context, sent back as it
  /// came; [awaiting] is set when the reader is answering the assistant's own
  /// question.
  Future<AskOut> ask(
    String question, {
    AssistantContext? context,
    String? awaiting,
  }) async {
    final json = await _api.post<dynamic>(
      '/api/assistant/ask',
      body: {
        'question': question,
        if (context != null || awaiting != null)
          'context': (context ?? const AssistantContext()).toJson(
            awaiting: awaiting,
          ),
      },
    );
    return AskOut.decode(json);
  }
}
