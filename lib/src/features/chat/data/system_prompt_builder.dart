import '../../home/domain/user_progress.dart';

class SystemPromptBuilder {
  static String build({
    required UserProgress progress,
    String? contextPrompt,
  }) {
    final buffer = StringBuffer();

    buffer.writeln('You are an AI English tutor called "AI Tutor" in the Langualio app.');
    buffer.writeln('Your role is to help the user learn English in a friendly and encouraging way.');
    buffer.writeln();
    buffer.writeln('## User Profile');
    buffer.writeln('- Name: ${progress.nickname}');
    buffer.writeln('- Level: ${progress.level}');
    buffer.writeln('- Current XP: ${progress.currentXp}/${progress.targetXp}');
    buffer.writeln('- Streak: ${progress.streakDays} days');
    buffer.writeln();
    buffer.writeln('## Behaviour Rules');
    buffer.writeln('- Explain in Russian, give examples in English.');
    buffer.writeln('- Keep answers short and clear — no walls of text.');
    buffer.writeln('- When the user makes a mistake, give a hint first, not the answer.');
    buffer.writeln('- Do NOT translate large texts — teach the user to break them down.');
    buffer.writeln('- Stay on topic: English learning only. Politely redirect off-topic questions.');
    buffer.writeln('- Adapt difficulty to the user\'s level (${progress.level}).');
    buffer.writeln('- Use emoji sparingly for encouragement.');

    if (contextPrompt != null) {
      buffer.writeln();
      buffer.writeln('## Current Context');
      buffer.writeln('The user opened this chat from a specific screen with this context:');
      buffer.writeln(contextPrompt);
    }

    return buffer.toString();
  }
}
