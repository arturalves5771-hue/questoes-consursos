-- Executar depois de supabase/seed/assuntos_equivalentes.sql.
-- Relaciona o assunto consolidado à teoria somente quando o título canônico
-- e o tópico da trilha são iguais após normalização, ou possuem exatamente
-- o mesmo conjunto de palavras (ordem diferente). Não usa tópicos-filhos
-- para criar vínculo com um assunto-pai.
-- Não altera codrelacional, ciclos, atividades ou progresso.
begin;
delete from public.edital_assunto_estudo_vinculo;

with canonical_rows as (
 select e.id equivalencia_id,
  regexp_replace(lower(d.nome),'[^a-z0-9]+','','g') disc,
  trim(regexp_replace(regexp_replace(translate(lower(e.assunto_canonico),'áàâãäéèêëíìîïóòôõöúùûüç','aaaaaeeeeiiiiooooouuuuc'),'^[[:space:]]*[0-9]+([.][0-9]+)*[.)]?[[:space:]]*',''),'[^a-z0-9]+',' ','g')) norm,
  array(select distinct w from unnest(string_to_array(trim(regexp_replace(regexp_replace(translate(lower(e.assunto_canonico),'áàâãäéèêëíìîïóòôõöúùûüç','aaaaaeeeeiiiiooooouuuuc'),'^[[:space:]]*[0-9]+([.][0-9]+)*[.)]?[[:space:]]*',''),'[^a-z0-9]+',' ','g')),' ')) as t(w)
   where length(w)>2 and w not in ('para','como','sobre','entre','pela','pelo','suas','seus','dos','das','com','sem','que','uma','uns','nas','nos','sua','seu','mais','outros','outras','direito','lei','numero','conceito','geral','disposicoes','artigo','art','estado','publica','publico','administracao','federal','estadual','contra','e','no','na','do','da','de','a','o','os','as','em','por','um','n') order by w) terms,
  array(select distinct m.parts[1] from regexp_matches(e.assunto_canonico,'([0-9]{1,2}\\.[0-9]{3}/[0-9]{4}|[0-9]{4,5}/[0-9]{4})','g') as m(parts) order by m.parts[1]) laws
 from public.edital_assunto_equivalencia e
 join public.edital_disciplina_catalogo d on d.id=e.disciplina_id
), study_rows as (
 select s.codrelacional,regexp_replace(lower(s.disciplina),'[^a-z0-9]+','','g') disc,
  trim(regexp_replace(regexp_replace(translate(lower(s.conteudo),'áàâãäéèêëíìîïóòôõöúùûüç','aaaaaeeeeiiiiooooouuuuc'),'^[[:space:]]*[0-9]+([.][0-9]+)*[.)]?[[:space:]]*',''),'[^a-z0-9]+',' ','g')) norm,
  array(select distinct w from unnest(string_to_array(trim(regexp_replace(regexp_replace(translate(lower(s.conteudo),'áàâãäéèêëíìîïóòôõöúùûüç','aaaaaeeeeiiiiooooouuuuc'),'^[[:space:]]*[0-9]+([.][0-9]+)*[.)]?[[:space:]]*',''),'[^a-z0-9]+',' ','g')),' ')) as t(w)
   where length(w)>2 and w not in ('para','como','sobre','entre','pela','pelo','suas','seus','dos','das','com','sem','que','uma','uns','nas','nos','sua','seu','mais','outros','outras','direito','lei','numero','conceito','geral','disposicoes','artigo','art','estado','publica','publico','administracao','federal','estadual','contra','e','no','na','do','da','de','a','o','os','as','em','por','um','n') order by w) terms,
  array(select distinct m.parts[1] from regexp_matches(s.conteudo,'([0-9]{1,2}\\.[0-9]{3}/[0-9]{4}|[0-9]{4,5}/[0-9]{4})','g') as m(parts) order by m.parts[1]) laws
 from public.edital_verticalizado s
), matches as (
 select c.equivalencia_id,s.codrelacional,(c.norm=s.norm) exact_match
 from canonical_rows c join study_rows s on c.disc=s.disc
  and ((cardinality(c.laws)=0 and cardinality(s.laws)=0) or c.laws=s.laws)
  and (c.norm=s.norm or (cardinality(c.terms)>=2 and c.terms=s.terms))
)
insert into public.edital_assunto_estudo_vinculo(equivalencia_id,codrelacional,criterio,confianca)
select equivalencia_id,codrelacional,case when exact_match then 'texto_exato' else 'equivalencia_semantica' end,1.0000
from matches
on conflict(equivalencia_id,codrelacional) do nothing;

commit;
