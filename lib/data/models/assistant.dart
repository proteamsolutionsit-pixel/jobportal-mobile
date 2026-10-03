/// The assistant's wire types — `app/schemas/assistant.py`.
///
/// Strict, as every model here is (CLAUDE.md rule 2): `intent` and `text` are
/// required, the lists are optional-and-empty, and a wrong type throws rather
/// than rendering as blank.
library;

import 'wire.dart';

/// `GET /api/assistant/intents` — the starter chips for the signed-in role.
class AssistantIntents {
  const AssistantIntents({required this.role, required this.chips});

  final String? role;
  final List<String> chips;

  factory AssistantIntents.decode(Object? json) {
    final w = Wire.of(json, 'AssistantIntents');
    return AssistantIntents(
      role: w.strOrNull('role'),
      chips: w.stringsOrEmpty('chips'),
    );
  }
}

/// What a turn established. The client stores it and sends it back with the
/// next message; **that round trip is the whole memory of the conversation**,
/// so it is kept exactly as received rather than reinterpreted.
class AssistantContext {
  const AssistantContext({this.intent, this.filters = const {}, this.awaiting});

  final String? intent;
  final Map<String, dynamic> filters;
  final String? awaiting;

  factory AssistantContext.fromWire(Wire w) {
    final raw = w.json['filters'];
    if (raw != null && raw is! Map) {
      throw WireFormatException(
        '${w.context}.filters',
        'expected an object',
        raw,
      );
    }
    return AssistantContext(
      intent: w.strOrNull('intent'),
      filters: raw == null ? const {} : Map<String, dynamic>.from(raw as Map),
      awaiting: w.strOrNull('awaiting'),
    );
  }

  /// Sent back verbatim; `awaiting` overridden when the reader is answering a
  /// question the assistant asked.
  Map<String, dynamic> toJson({String? awaiting}) => {
    'intent': intent,
    'filters': filters,
    'awaiting': awaiting ?? this.awaiting,
  };
}

/// One result card: a job, a company, a profile field to fill.
class AnswerItem {
  const AnswerItem({
    required this.title,
    this.meta,
    this.note,
    this.url,
    this.tag,
  });

  final String title;
  final String? meta;
  final String? note;
  final String? url;
  final String? tag;

  factory AnswerItem.fromWire(Wire w) => AnswerItem(
    title: w.str('title'),
    meta: w.strOrNull('meta'),
    note: w.strOrNull('note'),
    url: w.strOrNull('url'),
    tag: w.strOrNull('tag'),
  );
}

/// One number with its label.
class AnswerFact {
  const AnswerFact({required this.label, required this.value});

  final String label;
  final String value;

  factory AnswerFact.fromWire(Wire w) =>
      AnswerFact(label: w.str('label'), value: w.str('value'));
}

/// A link out of the conversation into the screen that goes deeper.
class AnswerAction {
  const AnswerAction({required this.label, required this.url});

  final String label;
  final String url;

  factory AnswerAction.fromWire(Wire w) =>
      AnswerAction(label: w.str('label'), url: w.str('url'));
}

/// Set when the assistant is asking rather than answering.
class AssistantQuestion {
  const AssistantQuestion({
    required this.field,
    required this.prompt,
    this.options = const [],
  });

  final String field;
  final String prompt;
  final List<String> options;

  factory AssistantQuestion.fromWire(Wire w) => AssistantQuestion(
    field: w.str('field'),
    prompt: w.str('prompt'),
    options: w.stringsOrEmpty('options'),
  );
}

class AssistantAnswer {
  const AssistantAnswer({
    required this.intent,
    required this.text,
    this.items = const [],
    this.facts = const [],
    this.chips = const [],
    this.actions = const [],
    this.question,
    this.context,
  });

  final String intent;
  final String text;
  final List<AnswerItem> items;
  final List<AnswerFact> facts;
  final List<String> chips;
  final List<AnswerAction> actions;
  final AssistantQuestion? question;
  final AssistantContext? context;

  factory AssistantAnswer.fromWire(Wire w) => AssistantAnswer(
    intent: w.str('intent'),
    text: w.str('text'),
    items: w.listOrEmpty('items', AnswerItem.fromWire),
    facts: w.listOrEmpty('facts', AnswerFact.fromWire),
    chips: w.stringsOrEmpty('chips'),
    actions: w.listOrEmpty('actions', AnswerAction.fromWire),
    question: w.objectOrNull('question', AssistantQuestion.fromWire),
    context: w.objectOrNull('context', AssistantContext.fromWire),
  );
}

/// `POST /api/assistant/ask` — the question echoed back, and the answer.
class AskOut {
  const AskOut({required this.question, required this.answer});

  final String question;
  final AssistantAnswer answer;

  factory AskOut.decode(Object? json) {
    final w = Wire.of(json, 'AskOut');
    return AskOut(
      question: w.str('question'),
      answer: w.object('answer', AssistantAnswer.fromWire),
    );
  }
}
