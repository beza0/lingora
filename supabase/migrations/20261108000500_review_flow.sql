-- Lingora · inceleme ve yayımlama akışı (yönetim paneli kullanır)
-- Bir hedefi incelendi/yayımlandı yapmak, ona bağlı anlam, kullanım, sözcük, kalıp ve alıştırmaları da aynı adıma taşır.
-- Hedefin kendisi yine draft → reviewed → published sırasını izlemek zorundadır.

create or replace function public.set_target_status(p_targets uuid[], p_status public.content_status)
returns int
language plpgsql
security definer
set search_path = public
as $$
declare
  v_count int;
  v_senses uuid[];
  v_patterns uuid[];
begin
  if not public.is_admin() then
    raise exception 'Yalnız yöneticiler içerik durumunu değiştirebilir' using errcode = 'insufficient_privilege';
  end if;
  if p_status = 'published' and exists (select 1 from learning_targets where id = any (p_targets) and status = 'draft') then
    raise exception 'İncelenmemiş hedef yayımlanamaz; önce “İncelendi” olarak işaretle' using errcode = 'check_violation';
  end if;

  select coalesce(array_agg(sense_id) filter (where sense_id is not null), '{}'),
         coalesce(array_agg(pattern_id) filter (where pattern_id is not null), '{}')
    into v_senses, v_patterns
    from learning_targets where id = any (p_targets);

  if p_status = 'archived' then
    update learning_targets set status = 'archived' where id = any (p_targets);
    get diagnostics v_count = row_count;
    return v_count;
  end if;

  -- bağlı satırlar: önce taslaktan incelendiye, gerekirse sonra yayımlandıya
  update lexemes set status = 'reviewed' where status = 'draft' and id in (select lexeme_id from senses where id = any (v_senses));
  update senses set status = 'reviewed' where status = 'draft' and id = any (v_senses);
  update sense_usages set status = 'reviewed' where status = 'draft' and sense_id = any (v_senses);
  update patterns set status = 'reviewed' where status = 'draft' and id = any (v_patterns);
  update exercises set status = 'reviewed' where status = 'draft' and target_id = any (p_targets);

  if p_status = 'published' then
    update lexemes set status = 'published' where status = 'reviewed' and id in (select lexeme_id from senses where id = any (v_senses));
    update senses set status = 'published' where status = 'reviewed' and id = any (v_senses);
    update sense_usages set status = 'published' where status = 'reviewed' and sense_id = any (v_senses);
    update patterns set status = 'published' where status = 'reviewed' and id = any (v_patterns);
    update exercises set status = 'published' where status = 'reviewed' and target_id = any (p_targets);
  end if;

  update learning_targets set status = p_status where id = any (p_targets) and status <> p_status;
  get diagnostics v_count = row_count;
  return v_count;
end;
$$;

revoke execute on function public.set_target_status(uuid[], public.content_status) from public, anon;
grant execute on function public.set_target_status(uuid[], public.content_status) to authenticated;
