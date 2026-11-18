import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:science_signal_ica16_b/quiz.dart';
import 'package:science_signal_ica16_b/cloud.dart';

Map<String, dynamic> fixture() => {
  'response_code': 0,
  'results': List.generate(
    5,
    (_) => {
      'category': 'Science%20%26%20Nature',
      'difficulty': 'medium',
      'type': 'boolean',
      'question': 'Water%20%26%20ice%3F',
      'correct_answer': 'True',
      'incorrect_answers': ['False'],
    },
  ),
};
void main() {
  test('T02 URL3986 decoding and exact endpoint', () {
    expect(parseQuestions(jsonEncode(fixture())).first.text, 'Water & ice?');
    expect(Uri.parse(scienceUrl).queryParameters, {
      'amount': '5',
      'category': '17',
      'difficulty': 'medium',
      'type': 'boolean',
      'encode': 'url3986',
    });
  });
  test('T03 rejects malformed data across every required field', () {
    for (final key in [
      'category',
      'difficulty',
      'type',
      'question',
      'correct_answer',
    ]) {
      final f = fixture();
      f['results'][0][key] = '%GG';
      expect(
        () => parseQuestions(jsonEncode(f)),
        throwsA(anything),
        reason: key,
      );
    }
    for (final field in ['category', 'difficulty', 'type']) {
      final f = fixture();
      f['results'][0][field] = 'wrong';
      expect(() => parseQuestions(jsonEncode(f)), throwsFormatException);
    }
    final f = fixture();
    f['response_code'] = 5;
    expect(() => parseQuestions(jsonEncode(f)), throwsFormatException);
    f['response_code'] = 0;
    f['results'].removeLast();
    expect(() => parseQuestions(jsonEncode(f)), throwsFormatException);
    final duplicate = fixture();
    duplicate['results'][0]['incorrect_answers'] = ['True'];
    expect(() => parseQuestions(jsonEncode(duplicate)), throwsFormatException);
    expect(() => parseQuestions('not json'), throwsFormatException);
  });
  test(
    'T04 repeated taps never add points and Continue requires an answer',
    () {
      final quiz = Quiz(List.generate(5, (_) => const Question('Q', true)));
      quiz.next();
      expect(quiz.index, 0);
      quiz.answer(true);
      quiz.answer(false);
      quiz.answer(true);
      expect(quiz.score, 1);
      expect(quiz.answers, [true]);
      quiz.next();
      quiz.answer(false);
      expect(quiz.score, 1);
    },
  );
  test('T05 five-answer review and cleared replay', () {
    final questions = List.generate(5, (_) => const Question('Q', true));
    final quiz = Quiz(questions);
    for (var i = 0; i < 5; i++) {
      quiz.answer(i.isEven);
      quiz.next();
    }
    expect(quiz.complete, true);
    expect(quiz.score, 3);
    expect(quiz.answers.length, 5);
    expect(Quiz(questions).answers, isEmpty);
  });
  test('T06 frozen exact fixed payload and collision comparison', () {
    final fixed = fixedPayload(3);
    expect(fixed.length, 5);
    expect(() => fixed['correctCount'] = 4, throwsUnsupportedError);
    expect(
      matchesPayload({...fixed, 'submittedAt': 'placeholder'}, fixed),
      true,
    );
    expect(
      matchesPayload({
        ...fixed,
        'correctCount': 4,
        'submittedAt': 'placeholder',
      }, fixed),
      false,
    );
    expect(
      matchesPayload({
        ...fixed,
        'submittedAt': 'placeholder',
        'extra': 1,
      }, fixed),
      false,
    );
    expect(
      matchesPayload({
        ...fixed,
        'correctCount': 3.0,
        'submittedAt': 'placeholder',
      }, fixed),
      false,
    );
  });
}
