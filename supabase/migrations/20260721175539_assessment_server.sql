-- ============================================================
-- Server-side Assessment (R4)
-- 1. assessment_questions table with seed data
-- 2. complete_assessment RPC — validates answers, computes level,
--    updates profile server-side
-- 3. Revoke client UPDATE on cefr_level and assessment_completed
-- ============================================================

-- ── 1. Assessment questions table ──

CREATE TABLE public.assessment_questions (
  id text PRIMARY KEY,
  question_text text NOT NULL,
  question_type text NOT NULL CHECK (question_type IN ('multipleChoice', 'fillBlank')),
  discipline text NOT NULL CHECK (discipline IN ('grammar', 'reading', 'listening')),
  cefr_level int NOT NULL CHECK (cefr_level BETWEEN 1 AND 5),
  options jsonb NOT NULL DEFAULT '[]',
  correct_answer text NOT NULL,
  context text,
  sort_order int NOT NULL DEFAULT 0,
  created_at timestamptz NOT NULL DEFAULT now()
);

ALTER TABLE public.assessment_questions ENABLE ROW LEVEL SECURITY;

-- Read-only for authenticated users (questions are public content)
CREATE POLICY "Authenticated users can read assessment questions"
  ON public.assessment_questions FOR SELECT TO authenticated USING (true);

-- Seed the 12 questions from the client-side question bank
INSERT INTO public.assessment_questions (id, question_text, question_type, discipline, cefr_level, options, correct_answer, context, sort_order) VALUES
  -- A1 (2 questions)
  ('a1_grammar_1', 'She ___ a student.', 'multipleChoice', 'grammar', 1,
   '["is", "are", "am", "be"]', 'is', NULL, 1),
  ('a1_reading_1', 'What does Tom want?', 'multipleChoice', 'reading', 1,
   '["A coffee", "A book", "A pen", "A phone"]', 'A coffee',
   E'Tom: "Can I have a coffee, please?"\nWaiter: "Of course!"', 2),

  -- A2 (3 questions)
  ('a2_grammar_1', 'I ___ to the cinema yesterday.', 'multipleChoice', 'grammar', 2,
   '["went", "go", "going", "gone"]', 'went', NULL, 3),
  ('a2_listening_1', 'Where is the woman going?', 'multipleChoice', 'listening', 2,
   '["To the bank", "To the park", "To the shop", "To the school"]', 'To the shop',
   E'Man: "Where are you going?"\nWoman: "I need to buy some milk. The shop closes at 6."', 4),
  ('a2_reading_1', 'What time does the library close on Saturday?', 'multipleChoice', 'reading', 2,
   '["3 PM", "5 PM", "6 PM", "9 PM"]', '3 PM',
   E'City Library Opening Hours:\nMonday–Friday: 9 AM – 6 PM\nSaturday: 10 AM – 3 PM\nSunday: Closed', 5),

  -- B1 (3 questions)
  ('b1_grammar_1', 'If I ___ more time, I would travel more.', 'multipleChoice', 'grammar', 3,
   '["had", "have", "has", "would have"]', 'had', NULL, 6),
  ('b1_reading_1', 'What is the main reason people move to cities according to the text?', 'multipleChoice', 'reading', 3,
   '["Better job opportunities", "Cleaner air", "Cheaper housing", "Less traffic"]', 'Better job opportunities',
   'Every year, millions of people move from rural areas to cities. The main reason is the hope of finding better-paying jobs. While cities offer more employment options, they also bring challenges like higher living costs and crowded transport.', 7),
  ('b1_listening_1', 'Complete the sentence: "You should ___ an umbrella."', 'fillBlank', 'listening', 3,
   '[]', 'take',
   E'A: "What''s the weather forecast for tomorrow?"\nB: "They said it''s going to rain all day. You should ___ an umbrella."', 8),

  -- B2 (3 questions)
  ('b2_grammar_1', 'Complete: "By next year, she ___ here for ten years."', 'fillBlank', 'grammar', 4,
   '[]', 'will have worked', NULL, 9),
  ('b2_reading_1', 'What does the author imply about remote work?', 'multipleChoice', 'reading', 4,
   '["It increases productivity but may harm team culture", "It is always better than office work", "It should be banned by companies", "It only works for tech companies"]',
   'It increases productivity but may harm team culture',
   'Studies show that remote workers often complete tasks faster without office distractions. However, managers report that spontaneous collaboration and team bonding suffer when employees rarely meet face to face.', 10),
  ('b2_listening_1', 'What does the speaker suggest about learning languages?', 'multipleChoice', 'listening', 4,
   '["Consistency matters more than intensity", "Grammar is the most important skill", "You need to live abroad to be fluent", "Apps are useless for real learning"]',
   'Consistency matters more than intensity',
   E'Speaker: "I often get asked what the secret to learning a language is. People expect me to say immersion or expensive courses. But honestly, the people who succeed are the ones who show up every day, even if it''s just for fifteen minutes. It''s not about marathon study sessions — it''s about not breaking the chain."', 11),

  -- C1 (1 question)
  ('c1_grammar_1', 'Complete: "Had he known about the delay, he ___ earlier."', 'fillBlank', 'grammar', 5,
   '[]', 'would have left', NULL, 12);


-- ── 2. complete_assessment RPC ──

CREATE OR REPLACE FUNCTION public.complete_assessment(p_answers jsonb)
RETURNS json
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_user_id uuid;
  v_question RECORD;
  v_user_answer text;
  v_correct_by_level int[] := ARRAY[0, 0, 0, 0, 0]; -- indices 0-4 for levels 1-5
  v_total_by_level int[] := ARRAY[0, 0, 0, 0, 0];
  v_total_correct int := 0;
  v_total_questions int := 0;
  v_determined_level int := 1; -- default A1
  v_correct_at_or_below int;
  v_total_at_or_below int;
  v_correct_above int;
  v_total_above int;
  v_ratio numeric;
  v_ratio_above numeric;
  v_lvl int;
BEGIN
  -- Auth guard
  v_user_id := auth.uid();
  IF v_user_id IS NULL THEN
    RAISE EXCEPTION 'Not authenticated';
  END IF;

  -- Validate input: p_answers must be an array of {question_id, answer}
  IF p_answers IS NULL OR jsonb_typeof(p_answers) != 'array' THEN
    RAISE EXCEPTION 'Invalid answers format: expected JSON array';
  END IF;

  -- Score each answer against the question bank
  FOR v_question IN
    SELECT aq.id, aq.cefr_level, aq.correct_answer
    FROM public.assessment_questions aq
    ORDER BY aq.sort_order
  LOOP
    v_total_questions := v_total_questions + 1;
    v_total_by_level[v_question.cefr_level] := v_total_by_level[v_question.cefr_level] + 1;

    -- Find user's answer for this question
    SELECT a.value ->> 'answer' INTO v_user_answer
    FROM jsonb_array_elements(p_answers) AS a(value)
    WHERE a.value ->> 'question_id' = v_question.id;

    -- Check correctness (case-insensitive, trimmed)
    IF v_user_answer IS NOT NULL
       AND lower(trim(v_user_answer)) = lower(trim(v_question.correct_answer)) THEN
      v_correct_by_level[v_question.cefr_level] := v_correct_by_level[v_question.cefr_level] + 1;
      v_total_correct := v_total_correct + 1;
    END IF;
  END LOOP;

  -- Determine CEFR level using the same algorithm as the client:
  -- Highest level X where ≥80% correct at or below X, and <60% above X (or no questions above)
  FOR v_lvl IN 1..5 LOOP
    -- Calculate correct at or below this level
    v_correct_at_or_below := 0;
    v_total_at_or_below := 0;
    FOR i IN 1..v_lvl LOOP
      v_correct_at_or_below := v_correct_at_or_below + v_correct_by_level[i];
      v_total_at_or_below := v_total_at_or_below + v_total_by_level[i];
    END LOOP;

    IF v_total_at_or_below = 0 THEN CONTINUE; END IF;

    v_ratio := v_correct_at_or_below::numeric / v_total_at_or_below;
    IF v_ratio < 0.8 THEN CONTINUE; END IF;

    -- Calculate correct above this level
    v_correct_above := 0;
    v_total_above := 0;
    FOR i IN (v_lvl + 1)..5 LOOP
      v_correct_above := v_correct_above + v_correct_by_level[i];
      v_total_above := v_total_above + v_total_by_level[i];
    END LOOP;

    IF v_total_above = 0 THEN
      v_determined_level := v_lvl;
    ELSE
      v_ratio_above := v_correct_above::numeric / v_total_above;
      IF v_ratio_above < 0.6 THEN
        v_determined_level := v_lvl;
      END IF;
    END IF;
  END LOOP;

  -- Update profile with server-determined level
  UPDATE public.profiles
  SET cefr_level = v_determined_level,
      assessment_completed = true
  WHERE id = v_user_id;

  -- Return result for client display
  RETURN json_build_object(
    'cefr_level', v_determined_level,
    'assessment_completed', true,
    'correct_answers', v_total_correct,
    'total_questions', v_total_questions
  );
END;
$$;

REVOKE EXECUTE ON FUNCTION public.complete_assessment(jsonb) FROM anon, public;
GRANT EXECUTE ON FUNCTION public.complete_assessment(jsonb) TO authenticated;


-- ── 3. Revoke client UPDATE on server-authoritative columns ──
-- The profiles table has a blanket "Users can update own profile" policy.
-- We restrict which columns the authenticated role can actually write.

REVOKE UPDATE ON public.profiles FROM authenticated;
GRANT UPDATE (nickname, avatar_url) ON public.profiles TO authenticated;
-- cefr_level, assessment_completed, level, current_xp, target_xp, streak_days,
-- words_learned, accuracy — all now server-only via RPC/service role.
