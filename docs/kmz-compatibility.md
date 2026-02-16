# Compatibilidade KMZ/KML com a modelagem atual

Resumo: **sim, é compatível com ajustes de contrato**.

A modelagem atual (`NetworkMap`, `MapNode`, `NetworkCable`, `NetworkCablePoint`) já representa os conceitos necessários para KML/KMZ:

- `MapNode` -> `Placemark` (Point)
- `NetworkCable` + `NetworkCablePoint` -> `Placemark` (LineString)
- `metadata` -> estilos e atributos estendidos (`ExtendedData`)

## 1) Requisito principal para KMZ/KML

KML/KMZ é geográfico. Portanto, para exportação nativa é necessário que o mapa opere em coordenadas geográficas (`longitude`, `latitude`) ou que exista transformação de coordenadas de tela para geografia.

## 2) Estratégia recomendada

Suportar dois modos de coordenada no mapa:

- `screen`: coordenadas de canvas (x/y em pixels ou unidades lógicas)
- `geo`: coordenadas geográficas (lon/lat)

Com isso:

- mapas `screen` renderizam melhor no frontend de topologia;
- mapas `geo` podem exportar/importar KML/KMZ diretamente.

## 3) Mapeamento de campos sugerido

### Node -> KML Placemark Point

- nome: `map_nodes.label`
- coordenadas: `map_nodes.longitude,map_nodes.latitude`
- dados adicionais: `map_nodes.metadata`

### Cable -> KML Placemark LineString

- nome: `network_cables.label`
- coordenadas:
  1. origem (node origem)
  2. pontos intermediários (`network_cable_points.position`)
  3. destino (node destino)
- estilo:
  - cor/espessura via `network_cables.metadata`
  - estado (`up/down/...`) convertido em estilo visual

## 4) Sobre "correlatos" (GeoJSON, Shapefile, etc.)

- **GeoJSON**: altamente compatível (`Point` e `LineString` mapeiam de forma direta)
- **KMZ/KML**: compatível, desde que coordenadas sejam geográficas
- **Shapefile**: compatível via processo ETL/exportador (menos flexível para metadados complexos)

## 5) Recomendação prática

1. manter a modelagem atual para topologia e editor visual;
2. adicionar no contrato do `NetworkMap` um `coordinate_system` (`screen|geo`);
3. criar serviço de export/import (`Maps::Export::KmlKmz` e `Maps::Import::KmlKmz`);
4. quando `coordinate_system = screen`, exigir georreferenciamento (transformação) antes da exportação KMZ.
