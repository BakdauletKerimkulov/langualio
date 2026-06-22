-- Add generation_count column to user_daily_usage for word generation rate limiting
alter table public.user_daily_usage
  add column if not exists generation_count int not null default 0;
