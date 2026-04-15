# Como registrar novas decisoes

## Quando abrir ADR
- Mudanca com impacto arquitetural nao trivial.
- Escolha entre alternativas que afeta manutencao futura.
- Alteracao de contrato entre backend e frontend.

## Passo a passo
1. Copiar `adr-template.md` para `adr-YYYYMMDD-slug.md`.
2. Preencher contexto com evidencias do codigo.
3. Registrar trade-offs explicitamente.
4. Linkar arquivos e docs afetados.
5. Adicionar resumo em `.llm/history/decisions-log.md`.

## Regras
- Nao abrir ADR para mudancas pequenas sem decisao estrutural.
- Evitar texto generico sem referencia a arquivos concretos.

