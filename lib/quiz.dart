import 'dart:convert';
import 'package:http/http.dart' as http;

const scienceUrl =
    'https://opentdb.com/api.php?amount=5&category=17&difficulty=medium&type=boolean&encode=url3986';

class Question {
  final String text;
  final bool correct;
  const Question(this.text, this.correct);
}

List<Question> parseQuestions(String body) {
  final data = jsonDecode(body);
  if (data is! Map ||
      data['response_code'] != 0 ||
      data['results'] is! List ||
      (data['results'] as List).length != 5) {
    throw const FormatException(
      'The science service did not return five valid questions. Please retry.',
    );
  }
  String decode(dynamic value) {
    if (value is! String || value.isEmpty) {
      throw const FormatException('Missing question data.');
    }
    return Uri.decodeComponent(value);
  }

  return List<Question>.unmodifiable(
    (data['results'] as List).map((raw) {
      if (raw is! Map) throw const FormatException('Malformed question.');
      if (decode(raw['category']) != 'Science & Nature' ||
          decode(raw['difficulty']) != 'medium' ||
          decode(raw['type']) != 'boolean') {
        throw const FormatException(
          'Unexpected science question category, difficulty, or type.',
        );
      }
      final text = decode(raw['question']);
      final correct = decode(raw['correct_answer']);
      final wrong = raw['incorrect_answers'];
      if (text.trim().isEmpty || wrong is! List || wrong.length != 1) {
        throw const FormatException('Invalid answer data.');
      }
      final incorrect = decode(wrong.single);
      if (!({'True', 'False'}.contains(correct)) ||
          !({'True', 'False'}.contains(incorrect)) ||
          correct == incorrect) {
        throw const FormatException('Answers must be exactly True and False.');
      }
      return Question(text, correct == 'True');
    }),
  );
}

class ScienceApi {
  final http.Client client;
  DateTime? _lastRequest;
  bool _busy = false;
  ScienceApi({http.Client? client}) : client = client ?? http.Client();
  Future<List<Question>> load() async {
    if (_busy) throw StateError('A question request is already running.');
    _busy = true;
    try {
      final last = _lastRequest;
      if (last != null) {
        final wait =
            const Duration(seconds: 5) - DateTime.now().difference(last);
        if (!wait.isNegative) await Future<void>.delayed(wait);
      }
      _lastRequest = DateTime.now();
      final response = await client
          .get(Uri.parse(scienceUrl))
          .timeout(const Duration(seconds: 10));
      if (response.statusCode != 200) {
        throw StateError(
          'Science service returned HTTP ${response.statusCode}. Retry manually.',
        );
      }
      return parseQuestions(response.body);
    } finally {
      _busy = false;
    }
  }
}

class Quiz {
  final List<Question> questions;
  final List<bool> _answers = [];
  Quiz(this.questions) {
    if (questions.length != 5) throw ArgumentError('Five questions required');
  }
  int index = 0;
  List<bool> get answers => List.unmodifiable(_answers);
  bool get answered => _answers.length > index;
  bool get complete => _answers.length == 5;
  int get score => List.generate(
    _answers.length,
    (i) => _answers[i] == questions[i].correct ? 1 : 0,
  ).fold(0, (a, b) => a + b);
  void answer(bool value) {
    if (!answered && !complete) _answers.add(value);
  }

  void next() {
    if (answered && index < 4) index++;
  }
}
