import '../domain/assessment_question.dart';

/// 12 assessment questions for CEFR level determination.
/// Distribution by level: A1(2), A2(3), B1(3), B2(3), C1(1)
/// Distribution by discipline: Grammar(5), Reading(4), Listening(3)
const List<AssessmentQuestion> questionBank = [
  // --- A1 (2 questions) ---
  AssessmentQuestion(
    id: 'a1_grammar_1',
    text: 'She ___ a student.',
    type: QuestionType.multipleChoice,
    discipline: Discipline.grammar,
    level: CefrLevel.a1,
    options: ['is', 'are', 'am', 'be'],
    correctAnswer: 'is',
  ),
  AssessmentQuestion(
    id: 'a1_reading_1',
    text: 'What does Tom want?',
    type: QuestionType.multipleChoice,
    discipline: Discipline.reading,
    level: CefrLevel.a1,
    options: ['A coffee', 'A book', 'A pen', 'A phone'],
    correctAnswer: 'A coffee',
    context: 'Tom: "Can I have a coffee, please?"\nWaiter: "Of course!"',
  ),

  // --- A2 (3 questions) ---
  AssessmentQuestion(
    id: 'a2_grammar_1',
    text: 'I ___ to the cinema yesterday.',
    type: QuestionType.multipleChoice,
    discipline: Discipline.grammar,
    level: CefrLevel.a2,
    options: ['went', 'go', 'going', 'gone'],
    correctAnswer: 'went',
  ),
  AssessmentQuestion(
    id: 'a2_listening_1',
    text: 'Where is the woman going?',
    type: QuestionType.multipleChoice,
    discipline: Discipline.listening,
    level: CefrLevel.a2,
    options: ['To the bank', 'To the park', 'To the shop', 'To the school'],
    correctAnswer: 'To the shop',
    context:
        'Man: "Where are you going?"\nWoman: "I need to buy some milk. The shop closes at 6."',
  ),
  AssessmentQuestion(
    id: 'a2_reading_1',
    text: 'What time does the library close on Saturday?',
    type: QuestionType.multipleChoice,
    discipline: Discipline.reading,
    level: CefrLevel.a2,
    options: ['3 PM', '5 PM', '6 PM', '9 PM'],
    correctAnswer: '3 PM',
    context:
        'City Library Opening Hours:\nMonday–Friday: 9 AM – 6 PM\nSaturday: 10 AM – 3 PM\nSunday: Closed',
  ),

  // --- B1 (3 questions) ---
  AssessmentQuestion(
    id: 'b1_grammar_1',
    text: 'If I ___ more time, I would travel more.',
    type: QuestionType.multipleChoice,
    discipline: Discipline.grammar,
    level: CefrLevel.b1,
    options: ['had', 'have', 'has', 'would have'],
    correctAnswer: 'had',
  ),
  AssessmentQuestion(
    id: 'b1_reading_1',
    text: 'What is the main reason people move to cities according to the text?',
    type: QuestionType.multipleChoice,
    discipline: Discipline.reading,
    level: CefrLevel.b1,
    options: [
      'Better job opportunities',
      'Cleaner air',
      'Cheaper housing',
      'Less traffic',
    ],
    correctAnswer: 'Better job opportunities',
    context:
        'Every year, millions of people move from rural areas to cities. The main reason is the hope of finding better-paying jobs. While cities offer more employment options, they also bring challenges like higher living costs and crowded transport.',
  ),
  AssessmentQuestion(
    id: 'b1_listening_1',
    text: 'Complete the sentence: "You should ___ an umbrella."',
    type: QuestionType.fillBlank,
    discipline: Discipline.listening,
    level: CefrLevel.b1,
    options: [],
    correctAnswer: 'take',
    context:
        'A: "What\'s the weather forecast for tomorrow?"\nB: "They said it\'s going to rain all day. You should ___ an umbrella."',
  ),

  // --- B2 (3 questions) ---
  AssessmentQuestion(
    id: 'b2_grammar_1',
    text: 'Complete: "By next year, she ___ here for ten years."',
    type: QuestionType.fillBlank,
    discipline: Discipline.grammar,
    level: CefrLevel.b2,
    options: [],
    correctAnswer: 'will have worked',
  ),
  AssessmentQuestion(
    id: 'b2_reading_1',
    text: 'What does the author imply about remote work?',
    type: QuestionType.multipleChoice,
    discipline: Discipline.reading,
    level: CefrLevel.b2,
    options: [
      'It increases productivity but may harm team culture',
      'It is always better than office work',
      'It should be banned by companies',
      'It only works for tech companies',
    ],
    correctAnswer: 'It increases productivity but may harm team culture',
    context:
        'Studies show that remote workers often complete tasks faster without office distractions. However, managers report that spontaneous collaboration and team bonding suffer when employees rarely meet face to face.',
  ),
  AssessmentQuestion(
    id: 'b2_listening_1',
    text: 'What does the speaker suggest about learning languages?',
    type: QuestionType.multipleChoice,
    discipline: Discipline.listening,
    level: CefrLevel.b2,
    options: [
      'Consistency matters more than intensity',
      'Grammar is the most important skill',
      'You need to live abroad to be fluent',
      'Apps are useless for real learning',
    ],
    correctAnswer: 'Consistency matters more than intensity',
    context:
        'Speaker: "I often get asked what the secret to learning a language is. People expect me to say immersion or expensive courses. But honestly, the people who succeed are the ones who show up every day, even if it\'s just for fifteen minutes. It\'s not about marathon study sessions — it\'s about not breaking the chain."',
  ),

  // --- C1 (1 question) ---
  AssessmentQuestion(
    id: 'c1_grammar_1',
    text: 'Complete: "Had he known about the delay, he ___ earlier."',
    type: QuestionType.fillBlank,
    discipline: Discipline.grammar,
    level: CefrLevel.c1,
    options: [],
    correctAnswer: 'would have left',
  ),
];
