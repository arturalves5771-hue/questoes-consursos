-- Catalogo de disciplinas e concursos PCPE, PMPE e PPPE.
-- Migration aplicada no projeto Supabase QUESTOES-CADERNOS.
-- Mantem edital_verticalizado e os codrelacional existentes intactos.

create table if not exists public.edital_disciplina_catalogo (
  id text primary key,
  nome text not null unique,
  concursos text[] not null,
  constraint edital_disciplina_catalogo_concursos_validos
    check (
      cardinality(concursos) between 1 and 3
      and concursos <@ array['PCPE','PMPE','PPPE']::text[]
    )
);

create table if not exists public.edital_disciplina_alias (
  disciplina_origem text primary key,
  disciplina_id text not null references public.edital_disciplina_catalogo(id)
    on update cascade on delete restrict
);

alter table public.edital_disciplina_catalogo enable row level security;
alter table public.edital_disciplina_alias enable row level security;

drop policy if exists "Leitura publica catalogo de disciplinas" on public.edital_disciplina_catalogo;
create policy "Leitura publica catalogo de disciplinas"
  on public.edital_disciplina_catalogo for select to public using (true);

drop policy if exists "Leitura publica aliases de disciplinas" on public.edital_disciplina_alias;
create policy "Leitura publica aliases de disciplinas"
  on public.edital_disciplina_alias for select to public using (true);

grant select on public.edital_disciplina_catalogo, public.edital_disciplina_alias to anon, authenticated;
revoke insert, update, delete, truncate, references, trigger
  on public.edital_disciplina_catalogo, public.edital_disciplina_alias from anon, authenticated;

insert into public.edital_disciplina_catalogo (id, nome, concursos) values
 ('atualidades_discursiva','Atualidades (somente para a prova discursiva)',array['PCPE','PPPE']::text[]),
 ('contabilidade_geral','Contabilidade Geral',array['PCPE']::text[]),
 ('direito_administrativo','Direito Administrativo',array['PCPE','PPPE']::text[]),
 ('direito_constitucional','Direito Constitucional',array['PCPE','PMPE','PPPE']::text[]),
 ('direito_penal','Direito Penal',array['PCPE','PPPE']::text[]),
 ('direito_processual_penal','Direito Processual Penal',array['PCPE','PPPE']::text[]),
 ('direitos_humanos_legislacao_extravagante','Direitos Humanos / Legislação Extravagante',array['PMPE','PPPE']::text[]),
 ('estatistica','Estatística',array['PCPE']::text[]),
 ('execucao_penal','Execução Penal',array['PPPE']::text[]),
 ('historia_pernambuco','História de Pernambuco',array['PMPE']::text[]),
 ('informatica','Informática',array['PCPE','PMPE','PPPE']::text[]),
 ('legislacao_especial','Legislação Especial',array['PPPE']::text[]),
 ('legislacao_estadual','Legislação Estadual',array['PCPE','PPPE']::text[]),
 ('lingua_portuguesa','Língua Portuguesa',array['PCPE','PMPE','PPPE']::text[]),
 ('raciocinio_logico','Raciocínio Lógico',array['PCPE','PMPE']::text[]),
 ('etica_servico_publico','Ética no Serviço Público',array['PPPE']::text[])
on conflict (id) do update set nome = excluded.nome, concursos = excluded.concursos;

insert into public.edital_disciplina_alias (disciplina_origem, disciplina_id) values
 ('Direito Administrativo','direito_administrativo'),
 ('Direito Constitucional','direito_constitucional'),
 ('Direito Penal','direito_penal'),
 ('Direito Processual Penal','direito_processual_penal'),
 ('Direitos Humanos','direitos_humanos_legislacao_extravagante'),
 ('Direitos Humanos e Legislação Extravagante','direitos_humanos_legislacao_extravagante'),
 ('Ética no Serviço Público','etica_servico_publico'),
 ('História de Pernambuco','historia_pernambuco'),
 ('Informática','informatica'),
 ('Legislação Especial','legislacao_especial'),
 ('Legislação Estadual','legislacao_estadual'),
 ('Língua Portuguesa','lingua_portuguesa'),
 ('Raciocínio Lógico','raciocinio_logico')
on conflict (disciplina_origem) do update set disciplina_id = excluded.disciplina_id;
