-- Executar depois de supabase/seed/assuntos_equivalentes.sql.
-- Reconstrói, de forma idempotente, os vínculos entre equivalências e a trilha
-- de teoria já existente. Não altera codrelacional nem dados de progresso.
delete from public.edital_assunto_estudo_vinculo;

with source_rows as (
 select distinct v.equivalencia_id,o.assunto_original,o.disciplina_original,
  trim(regexp_replace(regexp_replace(translate(lower(o.assunto_original),'áàâãäéèêëíìîïóòôõöúùûüç','aaaaaeeeeiiiiooooouuuuc'),'^[[:space:]]*[0-9]+([.][0-9]+)*[.)]?[[:space:]]*',''),'[^a-z0-9]+',' ','g')) norm,
  regexp_replace(lower(o.disciplina_original),'[^a-z0-9]+','','g') disc,
  array(select distinct m.parts[1] from regexp_matches(o.assunto_original,'([0-9]{1,2}\\.[0-9]{3}/[0-9]{4}|[0-9]{4,5}/[0-9]{4})','g') as m(parts)) laws
 from public.edital_assunto_vinculo v
 join public.edital_assunto_origem o on o.id=v.assunto_origem_id
 where o.concurso_code='PPPE'
), source_tokens as (
 select x.*,array(select distinct w from unnest(string_to_array(x.norm,' ')) as t(w)
  where length(w)>2 and w not in ('para','como','sobre','entre','pela','pelo','suas','seus','dos','das','com','sem','que','uma','uns','nas','nos','sua','seu','mais','outros','outras','direito','lei','numero','conceito','geral','disposicoes','artigo','art','estado','publica','publico','administracao','federal','estadual','contra','e','no','na','do','da','de','a','o','os','as','em','por','um','n')) terms
 from source_rows x
), study as (
 select s.codrelacional,s.disciplina,s.conteudo,
  trim(regexp_replace(regexp_replace(translate(lower(s.conteudo),'áàâãäéèêëíìîïóòôõöúùûüç','aaaaaeeeeiiiiooooouuuuc'),'^[[:space:]]*[0-9]+([.][0-9]+)*[.)]?[[:space:]]*',''),'[^a-z0-9]+',' ','g')) norm,
  regexp_replace(lower(s.disciplina),'[^a-z0-9]+','','g') disc,
  array(select distinct m.parts[1] from regexp_matches(s.conteudo,'([0-9]{1,2}\\.[0-9]{3}/[0-9]{4}|[0-9]{4,5}/[0-9]{4})','g') as m(parts)) laws
 from public.edital_verticalizado s
), origin_matches as (
 select a.equivalencia_id,s.codrelacional,
  (select count(*) from unnest(a.terms) t(w) where w=any(string_to_array(s.norm,' '))) shared,
  cardinality(a.terms) total,
  (a.norm=s.norm or a.norm like '%'||s.norm||'%' or s.norm like '%'||a.norm||'%') exact_phrase
 from source_tokens a
 join study s on (a.disc=s.disc or a.disc like '%'||s.disc||'%' or s.disc like '%'||a.disc||'%')
  and (cardinality(a.laws)=0 or a.laws && s.laws)
 where cardinality(a.terms)>=2
), canonical_matches as (
 select e.id equivalencia_id,s.codrelacional
 from public.edital_assunto_equivalencia e
 join public.edital_disciplina_catalogo d on d.id=e.disciplina_id
 join study s on
  regexp_replace(lower(d.nome),'[^a-z0-9]+','','g')=s.disc
  or regexp_replace(lower(d.nome),'[^a-z0-9]+','','g') like '%'||s.disc||'%'
  or s.disc like '%'||regexp_replace(lower(d.nome),'[^a-z0-9]+','','g')||'%'
 where
  trim(regexp_replace(regexp_replace(translate(lower(e.assunto_canonico),'áàâãäéèêëíìîïóòôõöúùûüç','aaaaaeeeeiiiiooooouuuuc'),'^[[:space:]]*[0-9]+([.][0-9]+)*[.)]?[[:space:]]*',''),'[^a-z0-9]+',' ','g')) = s.norm
  or s.norm like '%'||trim(regexp_replace(regexp_replace(translate(lower(e.assunto_canonico),'áàâãäéèêëíìîïóòôõöúùûüç','aaaaaeeeeiiiiooooouuuuc'),'^[[:space:]]*[0-9]+([.][0-9]+)*[.)]?[[:space:]]*',''),'[^a-z0-9]+',' ','g'))||'%'
  or trim(regexp_replace(regexp_replace(translate(lower(e.assunto_canonico),'áàâãäéèêëíìîïóòôõöúùûüç','aaaaaeeeeiiiiooooouuuuc'),'^[[:space:]]*[0-9]+([.][0-9]+)*[.)]?[[:space:]]*',''),'[^a-z0-9]+',' ','g')) like '%'||s.norm||'%'
)
insert into public.edital_assunto_estudo_vinculo(equivalencia_id,codrelacional,criterio,confianca)
select equivalencia_id,codrelacional,
 case when exact_phrase then 'texto_exato' else 'equivalencia_semantica' end,
 round(shared::numeric/nullif(total,0),4)
from origin_matches
where shared>=2 and (exact_phrase or shared::numeric/nullif(total,0)>=0.80)
union
select equivalencia_id,codrelacional,'texto_exato',1.0000 from canonical_matches
on conflict(equivalencia_id,codrelacional) do nothing;

-- Relações de subtópicos cuja correspondência foi conferida pela estrutura do edital.
insert into public.edital_assunto_estudo_vinculo(equivalencia_id,codrelacional,criterio,confianca)
select e.id,s.codrelacional,'subtopico',0.9500
from public.edital_assunto_equivalencia e
join public.edital_verticalizado s on
 (e.id='adm_processo' and (s.conteudo ilike '%Processo administrativo. 11.1%' or s.conteudo ilike '%Processo administrativo disciplinar%'))
 or (e.id in ('port_reescrita','port_substituicao') and s.conteudo ilike '%Reescrita de frases e parágrafos%')
 or (e.id in ('adm_poder_policia','adm_poder_disciplinar','adm_poder_hierarquico','adm_poder_regulamentar','src_pppe2026_885') and s.conteudo ilike '%Poderes da administração pública%')
 or (e.id='const_organizacao_estado' and s.conteudo ilike '%Organização do Estado%')
 or (e.id in ('const_executivo','const_judiciario','const_legislativo') and (s.conteudo ilike '%Organização dos Poderes%' or (e.id='const_executivo' and s.conteudo ilike '%Poder Executivo%') or (e.id='const_judiciario' and s.conteudo ilike '%Poder Judiciário%') or (e.id='const_legislativo' and s.conteudo ilike '%Poder Legislativo%')))
 or (e.id='proc_disposicoes_principios' and s.conteudo ilike '%Disposições preliminares do Código de Processo Penal%')
on conflict(equivalencia_id,codrelacional) do nothing;
