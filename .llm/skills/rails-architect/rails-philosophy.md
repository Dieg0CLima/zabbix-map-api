# Rails Philosophy

## Principios obrigatorios

### 1) Convention over Configuration
- Seguir naming e organizacao padrao de Rails antes de customizar.
- Evitar configuracoes especiais sem necessidade comprovada.

### 2) DRY com bom senso
- Reduzir duplicacao real.
- Nao criar abstracao antecipada para “talvez no futuro”.

### 3) Fat Model, Skinny Controller (com equilibrio)
- Controller: HTTP, autorizacao, parametros e delegacao.
- Model: persistencia, associacoes, validacoes e invariantes locais.
- Workflows multi-entidade/integracoes: services/casos de uso.

### 4) ActiveRecord bem usado
- Preferir scopes e relacoes expressivas.
- Prevenir N+1 com `includes/preload` quando necessario.
- Manter regras de integridade perto do dado.

### 5) Callbacks com cautela
- Aceitavel para invariantes locais e defaults simples.
- Evitar callback com fluxo de negocio critico ou integracao externa.

### 6) Concerns sem abuso
- Usar apenas para comportamento transversal realmente reutilizavel.
- Evitar concerns que escondem regra central de negocio.

### 7) Native-first
- Antes de criar camada nova, verificar recurso Rails nativo (validation, callbacks, scopes, ActiveJob, etc).

## Quando NAO seguir rigidamente Rails Way
- Quando requisito de dominio exigir isolamento claro de logica complexa.
- Quando integracao externa pedir fronteira explicita (adapters/clients/services).
- Quando performance exigir query object ou estrategia dedicada.

## Como adaptar sem quebrar filosofia
- Introduzir camadas adicionais de forma incremental.
- Garantir que o fluxo continue legivel para desenvolvedor Rails.
- Documentar desvio e motivo.
- Evitar transformar tudo em objetos abstratos sem necessidade.

