# Arquitetura do módulo NetworkCables

## 1) Visão geral

O módulo segue padrão **use-case oriented** em `app/services/network_cables`:

- `NetworkCables::Create`
- `NetworkCables::Update`
- `NetworkCables::Destroy`
- `NetworkCables::PayloadBuilder`

A camada HTTP (`Api::V1::NetworkCablesController`) permanece fina: recebe request, valida shape do payload, delega aos use cases e retorna resposta.

## 2) Contratos

### 2.1 Contrato de erro de domínio

Base:
- `NetworkCables::Errors::DomainError`
  - `code` (string estável)
  - `message` (string)
  - `details` (hash/array estruturado)

Especialização atual:
- `NetworkCables::Errors::InvalidPoints`
  - `code: "invalid_points"`
  - `details` inclui `min_points`, `provided_points`, `reason`

### 2.2 Mapeamento HTTP

`NetworkCablesController` resgata apenas `NetworkCables::Errors::DomainError` e responde `422` com:

```json
{
  "error": {
    "code": "invalid_points",
    "message": "Points payload is invalid",
    "details": {
      "min_points": 2,
      "provided_points": 1,
      "reason": "too_few_points"
    }
  }
}
```

### 2.3 Contrato de eventos

Tipos usados no módulo:
- `created`
- `status_changed`
- `geometry_changed`
- `metadata_updated`
- `updated`
- `deleted`

## 3) Fluxos transacionais

### Create
1. valida pontos (`PointSetValidator`)
2. normaliza pontos (`PointNormalizer`)
3. transação: cria cabo + cria pontos + grava evento `created`

### Update
1. captura snapshot anterior (`EventStateBuilder`)
2. atualiza atributos
3. se `points_provided`: valida + normaliza + substitui pontos
4. captura snapshot atual
5. infere tipo de evento (`EventTypeInferer`)
6. grava evento inferido

### Destroy
1. grava evento `deleted` antes da remoção
2. executa `destroy` (hard delete)

## 4) Regras de domínio explicitadas

- Invariante de pontos: mínimo 2 pontos via `PointSetValidator`.
- Normalização de coordenadas via `PointNormalizer`:
  - precedência: usa `x/y` quando presentes;
  - fallback: usa `lat/lng` mapeando para `x/y`.
- `position` sempre definido (payload ou índice).

## 5) Direção de dependências (pragmática Rails)

- Controller -> Use cases (services)
- Use cases -> POROs de regra (`PointSetValidator`, `PointNormalizer`, `EventTypeInferer`)
- Use cases -> persistência ActiveRecord
- `PointNormalizer` e `EventTypeInferer` não dependem de ActiveRecord.

## 6) Estratégia de testes

- Unit tests (POROs):
  - `PointNormalizerTest`
  - `EventTypeInfererTest`
- Service tests (use cases):
  - `CreateTest`
  - `UpdateTest`
- Request tests:
  - `NetworkCablesControllerTest` (inclui contrato 422 para erro de domínio)

## 7) Decisões e não-decisões

- **Hard delete intencional** em `Destroy` + evento `deleted` para coerência semântica.
- **DomainError no lugar de RecordInvalid fake** para manter contrato explícito e estável para frontend.
- Novos objetos de domínio (validator/normalizer/inferer) são criados quando há regra reutilizável e risco de duplicação.

## Checklist para contribuidores

- [ ] Não colocar regra de negócio em controller.
- [ ] Não espalhar inferência de evento em múltiplos pontos.
- [ ] Não duplicar validação de pontos entre use cases.
- [ ] Não acoplar `PointNormalizer`/`EventTypeInferer` ao ActiveRecord.
- [ ] Manter contrato de erro de domínio (`code/message/details`) estável.
