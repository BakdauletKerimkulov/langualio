-- Add admin-only write policies on app_config.
-- The initial migration comment said "admin-only write, authenticated read"
-- but only the SELECT policy existed. This adds INSERT/UPDATE/DELETE for admins.

create policy "Admins can update config"
  on public.app_config for update to authenticated
  using (
    (auth.jwt() -> 'app_metadata' ->> 'role') = 'admin'
  )
  with check (
    (auth.jwt() -> 'app_metadata' ->> 'role') = 'admin'
  );

create policy "Admins can insert config"
  on public.app_config for insert to authenticated
  with check (
    (auth.jwt() -> 'app_metadata' ->> 'role') = 'admin'
  );

create policy "Admins can delete config"
  on public.app_config for delete to authenticated
  using (
    (auth.jwt() -> 'app_metadata' ->> 'role') = 'admin'
  );
