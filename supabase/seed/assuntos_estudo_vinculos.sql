-- Executar depois de supabase/seed/assuntos_equivalentes.sql.
-- Vínculos estritos com a trilha existente: igualdade textual normalizada ou
-- similaridade lexical >= 0,90, na mesma disciplina e sem divergência de lei.
-- Não cria/edita codrelacional, ciclos, atividades ou progresso.
begin;
delete from public.edital_assunto_estudo_vinculo;

with source_rows as (
 select distinct v.equivalencia_id,o.assunto_original,
  regexp_replace(lower(o.disciplina_equivalente),'[^a-z0-9]+','','g') disc,
  trim(regexp_replace(regexp_replace(translate(lower(o.assunto_original),'áàâãäéèêëíìîïóòôõöúùûüç','aaaaaeeeeiiiiooooouuuuc'),'^[[:space:]]*[0-9]+([.][0-9]+)*[.)]?[[:space:]]*',''),'[^a-z0-9]+',' ','g')) norm,
  array(select distinct m.parts[1] from regexp_matches(o.assunto_original,'([0-9]{1,2}\\.[0-9]{3}/[0-9]{4}|[0-9]{4,5}/[0-9]{4})','g') as m(parts) order by m.parts[1]) laws
 from public.edital_assunto_vinculo v
 join public.edital_assunto_origem o on o.id=v.assunto_origem_id
 where o.concurso_code='PPPE'
), source_tokens as (
 select x.*,array(select distinct w from unnest(string_to_array(x.norm,' ')) as t(w)
  where length(w)>2 and w not in ('para','como','sobre','entre','pela','pelo','suas','seus','dos','das','com','sem','que','uma','uns','nas','nos','sua','seu','mais','outros','outras','direito','lei','numero','conceito','geral','disposicoes','artigo','art','estado','publica','publico','administracao','federal','estadual','contra','e','no','na','do','da','de','a','o','os','as','em','por','um','n')) terms
 from source_rows x
), study_rows as (
 select s.codrelacional,s.disciplina,s.conteudo,
  regexp_replace(lower(s.disciplina),'[^a-z0-9]+','','g') disc,
  trim(regexp_replace(regexp_replace(translate(lower(s.conteudo),'áàâãäéèêëíìîïóòôõöúùûüç','aaaaaeeeeiiiiooooouuuuc'),'^[[:space:]]*[0-9]+([.][0-9]+)*[.)]?[[:space:]]*',''),'[^a-z0-9]+',' ','g')) norm,
  array(select distinct m.parts[1] from regexp_matches(s.conteudo,'([0-9]{1,2}\\.[0-9]{3}/[0-9]{4}|[0-9]{4,5}/[0-9]{4})','g') as m(parts) order by m.parts[1]) laws
 from public.edital_verticalizado s
), study_tokens as (
 select x.*,array(select distinct w from unnest(string_to_array(x.norm,' ')) as t(w)
  where length(w)>2 and w not in ('para','como','sobre','entre','pela','pelo','suas','seus','dos','das','com','sem','que','uma','uns','nas','nos','sua','seu','mais','outros','outras','direito','lei','numero','conceito','geral','disposicoes','artigo','art','estado','publica','publico','administracao','federal','estadual','contra','e','no','na','do','da','de','a','o','os','as','em','por','um','n')) terms
 from study_rows x
), origin_matches as (
 select a.equivalencia_id,s.codrelacional,
  (a.norm=s.norm) exact_phrase,
  (select count(*) from unnest(a.terms) t(w) where w=any(s.terms)) shared,
  cardinality(a.terms) na,cardinality(s.terms) nb
 from source_tokens a
 join study_tokens s on a.disc=s.disc
  and ((cardinality(a.laws)=0 and cardinality(s.laws)=0) or a.laws=s.laws)
 where cardinality(a.terms)>=2 and cardinality(s.terms)>=2
), canonical_matches as (
 select e.id equivalencia_id,s.codrelacional
 from public.edital_assunto_equivalencia e
 join public.edital_disciplina_catalogo d on d.id=e.disciplina_id
 join study_tokens s on regexp_replace(lower(d.nome),'[^a-z0-9]+','','g')=s.disc
 where trim(regexp_replace(regexp_replace(translate(lower(e.assunto_canonico),'áàâãäéèêëíìîïóòôõöúùûüç','aaaaaeeeeiiiiooooouuuuc'),'^[[:space:]]*[0-9]+([.][0-9]+)*[.)]?[[:space:]]*',''),'[^a-z0-9]+',' ','g'))=s.norm
)
insert into public.edital_assunto_estudo_vinculo(equivalencia_id,codrelacional,criterio,confianca)
select equivalencia_id,codrelacional,
 case when exact_phrase then 'texto_exato' else 'equivalencia_semantica' end,
 round(case when exact_phrase then 1.0 else shared::numeric/nullif(na+nb-shared,0) end,4)
from origin_matches
where exact_phrase or (shared>=3 and shared::numeric/nullif(na+nb-shared,0)>=0.90)
union
select equivalencia_id,codrelacional,'texto_exato',1.0000 from canonical_matches
on conflict(equivalencia_id,codrelacional) do nothing;

commit;
