# Riscos Conhecidos

## R1 - Divergencia documental
Alguns docs misturam "estado atual" e "arquitetura alvo", podendo induzir implementacao fora do que existe no codigo.

Mitigacao:
- Priorizar codigo real (`app/*`, `config/routes.rb`) e usar docs como apoio.

## R2 - Inconsistencia de envelope de resposta
Parte dos controllers usa `ApiResponse` (`data/meta/errors`), parte responde `render json` direto.

Mitigacao:
- Ao adicionar endpoint, seguir padrao do controller/contexto local e registrar no changelog quando harmonizar.

## R3 - Cobertura de testes por camada
Suite atual aparenta foco maior em `services` e `models`; request tests sao limitados.

Mitigacao:
- Para mudancas de contrato HTTP, incluir testes de request/integracao quando possivel.

## R4 - Dependencia de modos Zabbix
Fluxos variam por `connection_mode`; erros de fallback podem ocultar dados desatualizados.

Mitigacao:
- Testar `api`, `database` e `hybrid` nas mudancas que tocam metricas/historico.

