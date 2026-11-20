-- Tiny pgTAP subset for local runs without the pgTAP extension.
-- Supports: plan, ok, is, isnt, throws_ok, lives_ok, results_eq, has_column,
-- has_table, finish. Output is TAP; failures also raise at finish().
create schema if not exists extensions;
create table if not exists public._tap_state (plan int, n int default 0, failed int default 0);
create or replace function extensions.plan(p int) returns text language plpgsql as $$
begin delete from public._tap_state; insert into public._tap_state values (p, 0, 0); return '1..'||p; end $$;
create or replace function extensions._res(pass boolean, descr text) returns text language plpgsql as $$
declare k int; begin
  update public._tap_state s set n = s.n + 1, failed = s.failed + case when pass then 0 else 1 end returning s.n into k;
  return (case when pass then 'ok ' else 'not ok ' end)||k||' - '||coalesce(descr,''); end $$;
create or replace function extensions.ok(c boolean, descr text default null) returns text language sql as $$ select extensions._res(coalesce(c,false), descr) $$;
create or replace function extensions.is(a anyelement, b anyelement, descr text default null) returns text language sql as $$ select extensions._res(a is not distinct from b, coalesce(descr,'')||case when a is not distinct from b then '' else ' (got '||coalesce(a::text,'NULL')||' want '||coalesce(b::text,'NULL')||')' end) $$;
create or replace function extensions.isnt(a anyelement, b anyelement, descr text default null) returns text language sql as $$ select extensions._res(a is distinct from b, descr) $$;
create or replace function extensions.throws_ok(q text, code text default null, msg text default null, descr text default null) returns text language plpgsql as $$
declare st text; begin
  begin execute q; exception when others then
    get stacked diagnostics st = returned_sqlstate;
    return extensions._res(code is null or st = code, coalesce(descr,msg,'throws')||case when code is null or st=code then '' else ' (got '||st||': '||sqlerrm||')' end);
  end;
  return extensions._res(false, coalesce(descr,msg,'throws')||' (no error)'); end $$;
create or replace function extensions.lives_ok(q text, descr text default null) returns text language plpgsql as $$
begin begin execute q; exception when others then return extensions._res(false, coalesce(descr,'')||' ('||sqlerrm||')'); end;
  return extensions._res(true, descr); end $$;
create or replace function extensions.results_eq(a text, b text, descr text default null) returns text language plpgsql as $$
declare ra text; rb text; begin
  execute 'select coalesce(string_agg(translate(r::text, ''()"'', ''''), E''\n'' order by ord),'''') from (select row_number() over () ord, x as r from ('||a||') x) t' into ra;
  execute 'select coalesce(string_agg(translate(r::text, ''()"'', ''''), E''\n'' order by ord),'''') from (select row_number() over () ord, x as r from ('||b||') x) t' into rb;
  return extensions._res(ra = rb, coalesce(descr,'')||case when ra=rb then '' else E' got:\n'||ra||E'\n want:\n'||rb end); end $$;
create or replace function extensions.results_eq(a text, b anyarray, descr text default null) returns text language plpgsql as $$
declare ra text; rb text; begin
  execute 'select coalesce(string_agg(translate(r::text, ''()"'', ''''), E''\n'' order by ord),'''') from (select row_number() over () ord, x as r from ('||a||') x) t' into ra;
  select coalesce(string_agg(translate(e::text, '()"', ''), E'\n' order by o),'') into rb from unnest(b) with ordinality u(e,o);
  return extensions._res(ra = rb, coalesce(descr,'')||case when ra=rb then '' else E' got:\n'||ra||E'\n want:\n'||rb end); end $$;
create or replace function extensions.has_column(t name, c name, descr text default null) returns text language sql as $$
select extensions._res(exists(select 1 from information_schema.columns where table_name=t and column_name=c), descr) $$;
create or replace function extensions.has_table(t name, descr text default null) returns text language sql as $$
select extensions._res(exists(select 1 from information_schema.tables where table_name=t), descr) $$;
create or replace function extensions.finish() returns setof text language plpgsql as $$
declare s record; begin select * into s from public._tap_state;
  return next '# planned '||s.plan||', ran '||s.n||', failed '||s.failed;
  if s.failed > 0 or s.n <> s.plan then raise exception 'TAP FAILED: planned %, ran %, failed %', s.plan, s.n, s.failed; end if; end $$;
grant usage on schema extensions to public;
grant select, insert, update, delete on public._tap_state to public;
