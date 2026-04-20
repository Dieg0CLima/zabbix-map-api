# Plano de Execução — Integração KMZ (Importação)

## Objetivo

Implementar importação KMZ de forma desacoplada, usando o contrato canônico já definido em `docs/import-providers-architecture-plan.md`, com fluxo seguro de `preview` antes de `apply`.

Objetivo de produto:
- receber um arquivo `.kmz` enviado pelo usuário;
- adaptar esse input para o padrão interno (contrato canônico);
- gerar (ou atualizar) um `NetworkMap` no sistema a partir desse conteúdo.

## Estado atual

- Não existe parser/adapter KMZ no backend.
- Não existem endpoints dedicados de importação.
- O domínio alvo já suporta entidades necessárias (`NetworkMap`, `MapNode`, `NetworkCable`, `NetworkCablePoint`).
- A arquitetura de providers já está documentada, mas ainda não implementada.

## Decisão arquitetural

A integração KMZ será o primeiro provider do pipeline genérico:

1. `ProviderRegistry`
2. `CanonicalNormalizer`
3. `Executor` (`preview`/`apply`)
4. `Providers::KmzAdapter`

Ou seja: **não criar fluxo KMZ isolado** fora da arquitetura de providers.

## Escopo do KMZ MVP (Fase 1)

Entrada:
- upload de arquivo `.kmz` (ou `.kml` puro para debug local).

Saída:
- `preview` com payload normalizado + validações + diffs resumidos.
- `apply` com persistência e relatório final.

Geometria suportada no MVP:
- `Placemark` com `Point` -> `MapNode`
- `Placemark` com `LineString` -> `NetworkCable` + `NetworkCablePoint`

Fora de escopo no MVP:
- `Polygon`, `MultiGeometry`, `GroundOverlay`, `NetworkLink`.
- estilos KML avançados como regra de renderização completa.

## Composição de um arquivo KMZ (referência para implementação)

`KMZ` é um contêiner ZIP com dados KML.

Estrutura típica:
- `doc.kml` (arquivo principal)
- `files/*` (assets opcionais, como ícones/imagens)
- KMLs adicionais opcionais (quando referenciados)

Elementos KML relevantes para o MVP:
- `Document` / `Folder` (organização)
- `Placemark` (entidades)
- `Point` (nós)
- `LineString` (cabos + pontos)
- `ExtendedData` (metadados adicionais)

## Fluxo funcional ponta a ponta

1. Usuário envia arquivo KMZ via endpoint de importação.
2. Backend extrai e parseia o `doc.kml`.
3. `KmzAdapter` converte KML para contrato canônico interno.
4. `CanonicalNormalizer` valida e normaliza o payload.
5. Em `preview`, API retorna diagnóstico/diff sem persistir.
6. Em `apply`, `Executor` cria/atualiza o `NetworkMap` e entidades relacionadas.
7. API retorna resumo da importação e `network_map_id` gerado/atualizado.

## Contrato técnico (KMZ -> canônico)

Mapeamento base:

- `Document.name` -> `map.name` (fallback para nome do arquivo)
- `Placemark.name` (Point) -> `node.label`
- `Placemark.name` (LineString) -> `cable.label`
- `coordinates`:
  - Point: `lng,lat[,alt]`
  - LineString: sequência `lng,lat[,alt] ...`

Regras de normalização:
- `coordinate_system = "geo"` para importação KMZ.
- gerar `external_id` determinístico quando não existir no input (`kmz:<hash>`).
- campos não mapeados vão para `metadata.provider_payload`.

## Mudanças de domínio necessárias

Para suportar KMZ com segurança:

1. Adicionar `coordinate_system` em `network_maps` (`screen|geo`, default `screen`).
2. Validar que importação KMZ em `apply` cria/atualiza mapa em modo `geo`.
3. Preservar suporte atual a mapas `screen` (sem quebra de comportamento existente).

## Endpoints propostos (API v1)

### 1) Preview

`POST /api/v1/network_maps/imports/preview`

Payload multipart:
- `provider=kmz`
- `file=<arquivo.kmz>`
- `organization_id` (quando necessário)
- opcional: `network_map_id` (para merge em mapa existente)

Resposta:
- `data.summary`
- `data.report`
- `data.normalized_payload`
- `data.warnings`
- `data.target_map` (`created`/`updated`, quando inferível no preview)

### 2) Apply

`POST /api/v1/network_maps/imports/apply`

Mesmo payload de preview.
Resposta:
- `data.summary`
- `data.report`
- `data.network_map_id`
- `data.network_map_name`

Observação:
- no MVP, `apply` síncrono apenas para arquivos pequenos.
- evolução posterior: enfileirar job para arquivos grandes.

## Estrutura de código sugerida

```text
app/services/maps/import/
  run.rb
  provider_registry.rb
  canonical_normalizer.rb
  executor.rb
  contracts/import_contract_v1.rb
  providers/base_adapter.rb
  providers/kmz_adapter.rb
  kmz/archive_reader.rb
  kmz/kml_parser.rb
  kmz/geometry_mapper.rb
app/controllers/api/v1/network_map_imports_controller.rb
```

## Estratégia de implementação por fases

## Fase A — Núcleo do pipeline (sem KMZ)

- implementar `ProviderRegistry`, `CanonicalNormalizer`, `Executor`, `Run`.
- suportar apenas payload interno fake para validar fluxo completo.
- adicionar testes de unidade para `preview` e `apply`.

Critério de aceite:
- pipeline funciona com contrato canônico e persiste nós/cabos/pontos.

## Fase B — Adapter KMZ

- ler `.kmz` (ZIP), extrair `.kml` principal.
- parsear KML (Nokogiri).
- mapear `Point` e `LineString` para contrato canônico.

Critério de aceite:
- `preview` de um KMZ real retorna payload válido.

## Fase C — API e autorização

- criar controller `NetworkMapImportsController`.
- garantir `authenticate_user!`, `ensure_organization_access!`, `require_editor_or_admin!`.
- expor endpoints `preview` e `apply`.

Critério de aceite:
- fluxo HTTP completo funcional e coberto por testes de request.

## Fase D — Robustez operacional

- limite de tamanho de arquivo e timeout de parsing.
- validação forte de arquivo inválido/corrompido.
- logs estruturados por `import_id`.

Critério de aceite:
- erros previsíveis com payload consistente.

## Testes obrigatórios

1. Service tests:
- `ProviderRegistry`
- `CanonicalNormalizer`
- `Executor` (`preview` e `apply`)
- `KmzAdapter` (Point/LineString, arquivo inválido, KML vazio)

2. Request tests:
- `preview` sucesso
- `apply` sucesso
- erro de autorização
- erro de validação de arquivo

3. Regressão:
- garantir que CRUD atual de mapas/cabos não sofreu efeito colateral.

## Riscos e mitigação

- Risco: variações de KMZ/KML fora do padrão.
  - Mitigação: parser tolerante + warnings no preview.
- Risco: arquivos grandes degradarem API.
  - Mitigação: limites de tamanho e futura execução assíncrona.
- Risco: inconsistência geométrica (LineString sem nós explícitos).
  - Mitigação: gerar nós endpoint automaticamente com `metadata.generated=true`.

## Critérios de pronto do KMZ MVP

- `preview` obrigatório antes de `apply`.
- importação de Point e LineString funcionando ponta a ponta.
- idempotência por `external_id` no escopo do mapa.
- documentação e contrato atualizados.
- testes passando para serviços e endpoints novos.

## Próximo passo recomendado

Iniciar pela **Fase A (núcleo do pipeline)** e já criar contratos de teste para permitir plugar `KmzAdapter` sem retrabalho nas fases seguintes.
