-- ============================================================
-- Langualio: Initial Database Schema
-- ============================================================

-- 1. Profiles (extends auth.users)
create table public.profiles (
  id uuid primary key references auth.users(id) on delete cascade,
  name text not null default '',
  avatar_url text,
  level int not null default 1,
  title text not null default 'Beginner',
  current_xp int not null default 0,
  target_xp int not null default 500,
  streak_days int not null default 0,
  last_active_date date,
  words_learned int not null default 0,
  accuracy int not null default 0,
  created_at timestamptz not null default now()
);

alter table public.profiles enable row level security;

create policy "Users can view own profile"
  on public.profiles for select using (auth.uid() = id);
create policy "Users can update own profile"
  on public.profiles for update using (auth.uid() = id);

-- Auto-create profile on signup
create or replace function public.handle_new_user()
returns trigger as $$
begin
  insert into public.profiles (id, name)
  values (new.id, coalesce(new.raw_user_meta_data->>'name', ''));
  return new;
end;
$$ language plpgsql security definer;

create trigger on_auth_user_created
  after insert on auth.users
  for each row execute function public.handle_new_user();

-- 2. Daily Goals
create table public.daily_goals (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references public.profiles(id) on delete cascade,
  title text not null,
  xp_reward int not null default 10,
  is_completed bool not null default false,
  date date not null default current_date
);

alter table public.daily_goals enable row level security;

create policy "Users can view own goals"
  on public.daily_goals for select using (auth.uid() = user_id);
create policy "Users can insert own goals"
  on public.daily_goals for insert with check (auth.uid() = user_id);
create policy "Users can update own goals"
  on public.daily_goals for update using (auth.uid() = user_id);

-- 3. Grammar Items (content, read-only for users)
create table public.grammar_items (
  id uuid primary key default gen_random_uuid(),
  category text not null,
  title text not null,
  summary text not null default '',
  formula text not null default '',
  examples jsonb not null default '[]',
  sort_order int not null default 0
);

alter table public.grammar_items enable row level security;

create policy "Authenticated users can read grammar"
  on public.grammar_items for select to authenticated using (true);

-- 4. User Grammar Progress
create table public.user_grammar_progress (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references public.profiles(id) on delete cascade,
  grammar_id uuid not null references public.grammar_items(id) on delete cascade,
  status text not null default 'locked' check (status in ('completed', 'unlocked', 'locked')),
  rules_mastered int not null default 0,
  total_rules int not null default 0,
  unique (user_id, grammar_id)
);

alter table public.user_grammar_progress enable row level security;

create policy "Users can view own grammar progress"
  on public.user_grammar_progress for select using (auth.uid() = user_id);
create policy "Users can insert own grammar progress"
  on public.user_grammar_progress for insert with check (auth.uid() = user_id);
create policy "Users can update own grammar progress"
  on public.user_grammar_progress for update using (auth.uid() = user_id);

-- 5. Practice Questions (content, read-only for users)
create table public.practice_questions (
  id uuid primary key default gen_random_uuid(),
  word text not null,
  options jsonb not null default '[]',
  correct_index int not null,
  difficulty int not null default 1 check (difficulty between 1 and 10),
  category text
);

alter table public.practice_questions enable row level security;

create policy "Authenticated users can read questions"
  on public.practice_questions for select to authenticated using (true);

-- 6. Practice Attempts
create table public.practice_attempts (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references public.profiles(id) on delete cascade,
  question_id uuid not null references public.practice_questions(id) on delete cascade,
  selected_index int not null,
  is_correct bool not null,
  xp_earned int not null default 0,
  created_at timestamptz not null default now()
);

alter table public.practice_attempts enable row level security;

create policy "Users can view own attempts"
  on public.practice_attempts for select using (auth.uid() = user_id);
create policy "Users can insert own attempts"
  on public.practice_attempts for insert with check (auth.uid() = user_id);

-- 7. Chat Messages
create table public.chat_messages (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references public.profiles(id) on delete cascade,
  role text not null check (role in ('user', 'assistant')),
  text text not null,
  context_source text check (context_source in ('home', 'grammar', 'practice')),
  context_payload text,
  created_at timestamptz not null default now()
);

alter table public.chat_messages enable row level security;

create policy "Users can view own messages"
  on public.chat_messages for select using (auth.uid() = user_id);
create policy "Users can insert own messages"
  on public.chat_messages for insert with check (auth.uid() = user_id);

-- 8. App Config (admin-only write, authenticated read)
create table public.app_config (
  key text primary key,
  value text not null,
  updated_at timestamptz not null default now()
);

alter table public.app_config enable row level security;

create policy "Authenticated users can read config"
  on public.app_config for select to authenticated using (true);

-- Seed config
insert into public.app_config (key, value) values
  ('daily_message_limit', '20'),
  ('xp_per_correct_answer', '10');

-- 9. User Daily Usage (AI message limit tracking)
create table public.user_daily_usage (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references public.profiles(id) on delete cascade,
  date date not null default current_date,
  message_count int not null default 0,
  unique (user_id, date)
);

alter table public.user_daily_usage enable row level security;

create policy "Users can view own usage"
  on public.user_daily_usage for select using (auth.uid() = user_id);
create policy "Users can insert own usage"
  on public.user_daily_usage for insert with check (auth.uid() = user_id);
create policy "Users can update own usage"
  on public.user_daily_usage for update using (auth.uid() = user_id);

-- 10. Seed grammar items
insert into public.grammar_items (category, title, summary, formula, examples, sort_order) values
  ('Tenses', 'Present Simple', 'Used for habits, routines, and general truths.', 'Subject + V1 (s/es)',
   '[{"before":"She ","highlight":"plays","after":" tennis every Saturday."},{"before":"The sun ","highlight":"rises","after":" in the east."}]', 1),
  ('Tenses', 'Present Continuous', 'Used for actions happening right now or temporary situations.', 'Subject + am/is/are + V-ing',
   '[{"before":"I ","highlight":"am reading","after":" a great book."},{"before":"They ","highlight":"are playing","after":" in the garden."}]', 2),
  ('Modals', 'Can / Could', 'Express ability, possibility, or permission.', 'Subject + can/could + V1',
   '[]', 3);

-- 11. Seed practice questions
insert into public.practice_questions (word, options, correct_index, difficulty) values
  ('Apple', '["Яблоко","Груша","Апельсин","Банан"]', 0, 1),
  ('Beautiful', '["Ужасный","Красивый","Быстрый","Умный"]', 1, 2),
  ('Window', '["Дверь","Стена","Окно","Пол"]', 2, 1);
