-- Supabase SQL Editor에서 한 번 실행하세요.
-- Auth 회원이 생성되면 public.game_profiles에도 행을 만들고, 기존 회원도 채웁니다.

begin;

create table if not exists public.game_profiles (
  user_id uuid primary key references auth.users(id) on delete cascade default auth.uid(),
  game_state jsonb not null default '{}'::jsonb,
  updated_at timestamptz not null default now()
);

alter table public.game_profiles enable row level security;
revoke all on table public.game_profiles from anon, authenticated;
grant select, insert, update on table public.game_profiles to authenticated;

drop policy if exists game_profiles_select_own on public.game_profiles;
create policy game_profiles_select_own on public.game_profiles
  for select to authenticated using ((select auth.uid()) = user_id);

drop policy if exists game_profiles_insert_own on public.game_profiles;
create policy game_profiles_insert_own on public.game_profiles
  for insert to authenticated with check ((select auth.uid()) = user_id);

drop policy if exists game_profiles_update_own on public.game_profiles;
create policy game_profiles_update_own on public.game_profiles
  for update to authenticated
  using ((select auth.uid()) = user_id)
  with check ((select auth.uid()) = user_id);

create or replace function public.create_game_profile_for_new_user()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  insert into public.game_profiles (user_id)
  values (new.id)
  on conflict (user_id) do nothing;
  return new;
end;
$$;

drop trigger if exists on_auth_user_created_game_profile on auth.users;
create trigger on_auth_user_created_game_profile
  after insert on auth.users
  for each row execute function public.create_game_profile_for_new_user();

insert into public.game_profiles (user_id)
select id from auth.users
on conflict (user_id) do nothing;

commit;
