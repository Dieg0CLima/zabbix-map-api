# Guia de Desenvolvimento Assistido por IA

Este guia define o padrão para uso de agentes de IA neste repositório.
Objetivo: manter contexto atualizado, código limpo e foco contínuo no produto que estamos construindo.

## 1) Norte do projeto

Antes de alterar qualquer código, alinhe sua tarefa com estes objetivos:

- API robusta para mapas de rede e integração com Zabbix;
- segurança e isolamento por organização;
- previsibilidade de contrato para frontend;
- evolução incremental sem quebrar compatibilidade.

Se uma mudança não fortalecer esses pontos, reduza escopo ou proponha alternativa.

## 2) Regra obrigatória: documentação sempre atualizada

Toda alteração funcional **deve** atualizar documentação no mesmo commit/PR.

Checklist mínimo:

1. Atualize comportamento e decisões arquiteturais em `docs/zabbix-map-architecture.md` quando houver impacto de domínio;
2. Atualize payloads, filtros, status HTTP e exemplos em `docs/api-contract.md` quando o contrato mudar;
3. Atualize `README.md` quando o fluxo de setup, execução, variáveis ou escopo do produto mudar;
4. Se a mudança não se encaixar nos docs atuais, crie um novo `.md` em `docs/` e referencie no `README.md`.

> Regra prática: código novo sem documentação correspondente é considerado incompleto.

## 3) Critérios de código limpo

### 3.1 Legibilidade

- Nomes explícitos para classes, métodos e variáveis;
- funções curtas com responsabilidade única;
- condicionais simples; extraia objetos/serviços quando necessário.

### 3.2 Organização

- Controllers: orquestração HTTP e autorização, sem regra de negócio complexa;
- Models: regras de domínio e validações essenciais;
- Services: integrações externas, fluxos de negócio e lógica reutilizável.

### 3.3 Acoplamento e manutenção

- Evite duplicação (DRY), mas sem criar abstrações prematuras;
- prefira composição a hierarquias complexas;
- preserve compatibilidade retroativa em endpoints públicos sempre que possível.

### 3.4 Tratamento de erros

- Retorne erros consistentes em JSON;
- não silencie exceções relevantes;
- logue contexto suficiente para diagnóstico sem expor segredos.

## 4) Boas práticas obrigatórias para agentes de IA

1. Leia os arquivos relevantes antes de editar (controller, model, service e docs relacionados);
2. proponha a menor mudança que resolva o problema com clareza;
3. valide a alteração com testes automáticos ou justificativa explícita quando não for possível;
4. descreva impactos e limitações na mensagem final/PR;
5. nunca remover testes para “fazer passar”; corrija causa raiz.

## 5) Foco no produto (evitar desvio de escopo)

- Priorize tarefas que aumentem confiabilidade da API, qualidade dos dados do mapa e integração com Zabbix;
- evite refactors amplos sem ganho funcional claro;
- prefira entregas pequenas, revisáveis e com rollback simples.

## 6) Definition of Done (DoD)

Uma tarefa só está concluída quando:

- [ ] Código implementado com padrão do projeto;
- [ ] Testes atualizados/criados e executados;
- [ ] Documentação atualizada nos arquivos corretos;
- [ ] Sem segredos hardcoded;
- [ ] Mudança explicada de forma objetiva no PR (o que mudou, por quê, impacto).

## 7) Modelo curto para descrição de PR

Use este formato:

```md
## Contexto
Problema e objetivo da mudança.

## O que foi alterado
- Item 1
- Item 2

## Documentação atualizada
- docs/arquivo-x.md
- README.md

## Validação
- Comandos executados
- Resultado

## Riscos e rollback
Pontos de atenção e como reverter.
```

---

Manter este guia atualizado é responsabilidade de toda mudança relevante no repositório.
