# Plano de Arquitetura — Importação Desacoplada por Providers

## Contexto

Hoje existe direcionamento de compatibilidade para KMZ/KML em `docs/kmz-compatibility.md`, mas não há uma arquitetura formal para múltiplos providers de importação (ex.: KMZ, OzMap, GeoSite) com contrato unificado.

Este plano define um desenho desacoplado para:

- padronizar entrada de diferentes fontes;
- validar em um formato canônico interno;
- executar importação com persistência consistente no domínio atual (`NetworkMap`, `MapNode`, `NetworkCable`, `NetworkCablePoint`).

## Objetivo

Criar uma pipeline de importação em duas camadas:

1. **Camada de provider**: entende formato externo.
2. **Camada canônica**: normaliza para o contrato interno único, independente da origem.

Isso permite adicionar novos providers sem alterar a engine de importação.

## Princípios

1. Provider não conhece ActiveRecord.
2. Persistência não conhece formato externo.
3. Contrato canônico é versionado.
4. Importação deve suportar `preview` e `apply`.
5. Toda execução gera relatório (`warnings`, `errors`, contadores, duração).

## Arquitetura proposta

## 1) Contrato canônico (`ImportContract`)

Todo provider converte seu payload para este formato:

```json
{
  "schema_version": "1.0",
  "provider": "kmz",
  "coordinate_system": "geo",
  "map": {
    "name": "Mapa Importado",
    "external_id": "provider-map-001",
    "metadata": {}
  },
  "nodes": [
    {
      "external_id": "node-1",
      "label": "POP Centro",
      "lat": -23.55,
      "lng": -46.63,
      "node_kind": "site",
      "metadata": {}
    }
  ],
  "cables": [
    {
      "external_id": "cable-1",
      "label": "Enlace A-B",
      "source_external_id": "node-1",
      "target_external_id": "node-2",
      "status": "active",
      "cable_type": "fiber",
      "metadata": {},
      "points": [
        { "position": 1, "lat": -23.56, "lng": -46.62 }
      ]
    }
  ]
}
```

Notas:
- `external_id` é obrigatório para idempotência e reconciliação.
- `coordinate_system` deve ser explícito (`geo|screen`).
- Campos desconhecidos do provider devem ir para `metadata`.

## 2) Provider Adapter (`Maps::Import::Providers::*`)

Interface mínima:

```ruby
module Maps
  module Import
    module Providers
      class BaseAdapter
        def parse(input:) = raise NotImplementedError
        def normalize(parsed:) = raise NotImplementedError
      end
    end
  end
end
```

Implementações iniciais:
- `Providers::KmzAdapter`
- `Providers::OzMapAdapter`
- `Providers::GeoSiteAdapter`

Responsabilidades:
- ler arquivo/payload nativo;
- extrair entidades do provider;
- mapear para `ImportContract`.

## 3) Normalizador/Validador canônico

Serviço central:
- `Maps::Import::CanonicalNormalizer`

Responsabilidades:
- validar `schema_version`;
- garantir presença e unicidade de `external_id`;
- validar referências (`source_external_id`/`target_external_id`);
- normalizar enums para padrão interno (`status`, `cable_type`, `node_kind`);
- retornar contrato canônico pronto para execução.

## 4) Executor de importação

Serviço:
- `Maps::Import::Executor`

Responsabilidades:
- rodar em transação;
- aplicar estratégia `upsert` por `external_id` no escopo do `network_map`;
- criar/atualizar:
  - mapa
  - nós
  - cabos
  - pontos de cabo
- registrar relatório final.

Estratégias de execução:
- `preview`: sem persistência, retorna diffs e validações.
- `apply`: persiste mudanças.

## 5) Orquestrador único

Facade:
- `Maps::Import::Run`

Fluxo:
1. resolver adapter pelo provider;
2. `parse`;
3. `normalize` do adapter;
4. `CanonicalNormalizer.call`;
5. `Executor.call(mode: preview|apply)`.

## 6) Registry de providers

Componente:
- `Maps::Import::ProviderRegistry`

Responsabilidades:
- mapear `provider_key` -> classe adapter;
- permitir extensão sem `case` gigante em controller/service.

## Contrato de execução (API interna)

Entrada:
- `organization_id`
- `network_map_id` opcional (create/update)
- `provider` (`kmz|ozmap|geosite|...`)
- `input` (arquivo ou payload)
- `mode` (`preview|apply`)

Saída:
- `summary` (`created`, `updated`, `skipped`, `errors`, `warnings`)
- `report`
- `normalized_payload` (somente `preview`)

## Multi-tenant e segurança

- sempre escopar por `current_organization`;
- nunca confiar em IDs internos vindos do provider;
- usar somente `external_id` para reconciliação do contrato externo;
- sanitizar logs e não persistir arquivos brutos com dados sensíveis sem política explícita.

## Idempotência e reconciliação

Regras iniciais:
- nó: `network_map_id + external_id`;
- cabo: `network_map_id + external_id`;
- ponto de cabo: reconstrução ordenada por `position` por cabo importado.

Política de remoção:
- fase inicial: não remover automaticamente entidades ausentes (modo conservador);
- fase futura: opção `prune_missing=true` com `preview` obrigatório.

## Observabilidade

Para cada execução:
- `import_job_id`, `provider`, `mode`, `organization_id`, `network_map_id`;
- tempo por etapa (`parse`, `normalize`, `validate`, `persist`);
- contadores (`created`, `updated`, `skipped`, `failed`);
- erros estruturados por entidade (`entity_type`, `external_id`, `reason`).

## Roadmap de implementação

## Fase 1 — Fundação do contrato
- criar `ImportContract` (schema `1.0`);
- criar `CanonicalNormalizer`;
- criar `ProviderRegistry`;
- criar `Run` e `Executor` com `preview`.

## Fase 2 — Provider KMZ
- implementar `KmzAdapter`;
- suportar `apply` com upsert de nós/cabos/pontos;
- testes de integração de ponta a ponta.

## Fase 3 — Providers OzMap e GeoSite
- implementar adapters específicos;
- cobrir diferenças de semântica no normalizador;
- consolidar matriz de compatibilidade por campo.

## Fase 4 — Evolução operacional
- jobs assíncronos para imports pesados;
- relatórios persistidos por execução;
- política opcional de `prune_missing`.

## Estrutura de código sugerida

```text
app/services/maps/import/
  run.rb
  provider_registry.rb
  canonical_normalizer.rb
  executor.rb
  contracts/
    import_contract_v1.rb
  providers/
    base_adapter.rb
    kmz_adapter.rb
    oz_map_adapter.rb
    geo_site_adapter.rb
```

## Decisões já tomadas neste plano

1. Contrato canônico único antes da persistência.
2. Provider adapters isolados por fonte externa.
3. Estratégia `preview` como etapa obrigatória de segurança.
4. Reconciliação por `external_id` no escopo do mapa.

## Próxima ação recomendada

Implementar primeiro o núcleo sem provider específico:

1. `ProviderRegistry`
2. `CanonicalNormalizer`
3. `Executor` (modo `preview`)
4. `Run` (orquestrador)

Depois conectar `KmzAdapter` como provider inicial.
