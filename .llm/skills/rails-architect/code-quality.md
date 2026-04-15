# Code Quality Criteria

## Criterios obrigatorios
- Nomes claros, semanticos e consistentes.
- Metodos curtos e focados.
- Fluxo de leitura simples (baixo custo cognitivo).
- Baixa ambiguidade de responsabilidade.
- Clareza > esperteza.

## Diretrizes praticas
- Evitar booleanos obscuros e nomes genericos (`data`, `helper`, `do_it`).
- Extrair logica repetida quando duplicacao for real e recorrente.
- Isolar regras complexas em metodos nomeados.
- Evitar side effects escondidos.
- Preferir codigo explicito ao metaprogramming desnecessario.

## Acoplamento e complexidade
- Reduzir dependencia direta entre camadas.
- Evitar classes “deus”.
- Evitar encadeamento profundo de chamadas sem encapsulamento.

## Performance e previsibilidade
- Revisar consultas para evitar N+1.
- Evitar gerar payload gigante sem necessidade.
- Tratar erro de forma consistente e rastreavel.

## Qualidade no contexto deste repo
- Revisar uso consistente de envelope de resposta em controllers.
- Manter controllers `api/v1` finos e services coesos.
- Preservar contrato documentado em `docs/api-contract.md` quando alterar API.

