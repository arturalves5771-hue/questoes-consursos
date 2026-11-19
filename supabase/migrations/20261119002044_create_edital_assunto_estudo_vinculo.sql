-- Liga cada assunto equivalente dos editais aos tópicos já existentes na trilha de teoria.
-- Não altera edital_verticalizado, codrelacional, ciclos ou progresso.
create table if not exists public.edital_assunto_estudo_vinculo (
  equivalencia_id text not null
    references public.edital_assunto_equivalencia(id) on delete cascade,
  codrelacional uuid not null
    references public.edital_verticalizado(codrelacional) on delete cascade,
  criterio text not null default 'manual',
  confianca numeric(5,4),
  created_at timestamptz not null default now(),
  primary key (equivalencia_id, codrelacional),
  constraint edital_assunto_estudo_vinculo_criterio_chk
    check (criterio in ('texto_exato','equivalencia_semantica','subtopico','manual'))
);

create index if not exists idx_assunto_estudo_vinculo_codrelacional
  on public.edital_assunto_estudo_vinculo(codrelacional);

alter table public.edital_assunto_estudo_vinculo enable row level security;

grant select on public.edital_assunto_estudo_vinculo to anon, authenticated;

drop policy if exists "Leitura pública dos vínculos assunto estudo"
  on public.edital_assunto_estudo_vinculo;

create policy "Leitura pública dos vínculos assunto estudo"
  on public.edital_assunto_estudo_vinculo
  for select to anon, authenticated
  using (true);
