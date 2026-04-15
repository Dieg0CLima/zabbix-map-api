# Refactoring Strategy (Incremental e Seguro)

## Objetivo
Refatorar sem quebrar comportamento, priorizando ganho real de manutencao/clareza.

## Regras
- Nao mudar comportamento funcional sem necessidade declarada.
- Preferir mudancas pequenas e reversiveis.
- Priorizar alto impacto com baixo risco.
- Explicitar trade-offs.
- Marcar incerteza como `precisa validacao`.

## Ordem recomendada
1. Identificar problema (ex.: controller inchado, query ineficiente, duplicacao).
2. Cobrir comportamento atual com teste (ou registrar lacuna explicitamente).
3. Extrair/refatorar uma unidade por vez.
4. Validar resultado e contrato.
5. Atualizar docs relevantes.

## Heuristica de priorizacao
- P0: riscos de seguranca/multi-tenant, bugs funcionais, regressao de contrato.
- P1: hotspots de manutenibilidade e performance recorrente.
- P2: limpeza estrutural de baixo impacto imediato.

## Tecnicas seguras
- Extracao de metodo/classe orientada por responsabilidade.
- Query object para consultas complexas.
- Presenter/payload builder para resposta complexa.
- Encapsulamento progressivo (sem big-bang rewrite).

## Evitar
- Reescrita completa sem necessidade.
- Migrar tudo para novo padrao de uma vez.
- Introduzir framework interno paralelo ao Rails.

## Validacao minima
- Testes da area afetada.
- Verificacao de contrato de API.
- Revisao de impactos em legado e multi-org.

