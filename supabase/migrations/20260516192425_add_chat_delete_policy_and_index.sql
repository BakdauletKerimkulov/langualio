-- Delete policy for clearHistory
create policy "Users can delete own messages"
  on public.chat_messages for delete using (auth.uid() = user_id);

-- Index for efficient paginated queries (user + newest first)
create index idx_chat_messages_user_created
  on public.chat_messages(user_id, created_at desc);
