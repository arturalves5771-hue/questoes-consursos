-- Catálogo de equivalências por assunto entre PCPE, PMPE e PPPE.
-- Preserva integralmente edital_verticalizado, codrelacional e o histórico de estudos.
insert into public.edital_disciplina_catalogo (id,nome,concursos)
values ('legislacao_penal_especial','Legislação Penal Especial',array['PCPE','PMPE','PPPE']::text[])
on conflict (id) do update set nome=excluded.nome,concursos=excluded.concursos;

create table if not exists public.edital_assunto_origem (
  id text primary key,
  source_id integer not null,
  source_tag text not null check (source_tag in ('pcpe2026','pmpe2026','pppe2026')),
  concurso_code text not null check (concurso_code in ('PCPE','PMPE','PPPE')),
  concurso_nome text not null,
  disciplina_equivalente text not null,
  disciplina_original text not null,
  assunto_original text not null,
  cargo text,
  bloco text,
  source_order integer not null,
  created_at timestamptz not null default now(),
  unique(source_tag,source_id)
);

create table if not exists public.edital_assunto_equivalencia (
  id text primary key,
  disciplina_id text not null references public.edital_disciplina_catalogo(id) on update cascade on delete restrict,
  assunto_canonico text not null,
  observacao text,
  ordem integer not null default 0,
  created_at timestamptz not null default now()
);

create table if not exists public.edital_assunto_vinculo (
  equivalencia_id text not null references public.edital_assunto_equivalencia(id) on delete cascade,
  assunto_origem_id text not null references public.edital_assunto_origem(id) on delete cascade,
  primary key(equivalencia_id,assunto_origem_id)
);

create index if not exists idx_assunto_origem_concurso on public.edital_assunto_origem(concurso_code);
create index if not exists idx_assunto_origem_disciplina on public.edital_assunto_origem(disciplina_equivalente);
create index if not exists idx_assunto_vinculo_origem on public.edital_assunto_vinculo(assunto_origem_id);
create index if not exists idx_assunto_equivalencia_disciplina on public.edital_assunto_equivalencia(disciplina_id,ordem);

alter table public.edital_assunto_origem enable row level security;
alter table public.edital_assunto_equivalencia enable row level security;
alter table public.edital_assunto_vinculo enable row level security;

drop policy if exists "Leitura publica assuntos origem" on public.edital_assunto_origem;
create policy "Leitura publica assuntos origem" on public.edital_assunto_origem for select to public using(true);
drop policy if exists "Leitura publica assuntos equivalentes" on public.edital_assunto_equivalencia;
create policy "Leitura publica assuntos equivalentes" on public.edital_assunto_equivalencia for select to public using(true);
drop policy if exists "Leitura publica vinculos assuntos" on public.edital_assunto_vinculo;
create policy "Leitura publica vinculos assuntos" on public.edital_assunto_vinculo for select to public using(true);

grant select on public.edital_assunto_origem,public.edital_assunto_equivalencia,public.edital_assunto_vinculo to anon,authenticated;
revoke insert,update,delete,truncate,references,trigger on public.edital_assunto_origem,public.edital_assunto_equivalencia,public.edital_assunto_vinculo from anon,authenticated;

create or replace view public.vw_edital_assuntos_equivalentes
with (security_invoker=true) as
select e.id,e.disciplina_id,e.assunto_canonico,e.observacao,e.ordem,
 count(distinct o.concurso_code)::integer as quantidade_concursos,
 array_agg(distinct o.concurso_code order by o.concurso_code) as concursos,
 jsonb_agg(distinct jsonb_build_object(
  'id',o.id,'concurso_code',o.concurso_code,'concurso_nome',o.concurso_nome,
  'disciplina_equivalente',o.disciplina_equivalente,'disciplina_original',o.disciplina_original,
  'assunto_original',o.assunto_original,'cargo',o.cargo,'bloco',o.bloco,
  'source_id',o.source_id,'source_tag',o.source_tag
 )) as origens
from public.edital_assunto_equivalencia e
join public.edital_assunto_vinculo v on v.equivalencia_id=e.id
join public.edital_assunto_origem o on o.id=v.assunto_origem_id
group by e.id,e.disciplina_id,e.assunto_canonico,e.observacao,e.ordem;

grant select on public.vw_edital_assuntos_equivalentes to anon,authenticated;
