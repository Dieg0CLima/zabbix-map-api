# Architecture Guidelines (Rails)

## Organizacao recomendada
- `app/controllers`: orquestracao HTTP e autorizacao.
- `app/models`: persistencia e invariantes da entidade.
- `app/services`: casos de uso/workflows.
- `app/jobs`: processamento assincrono.
- `app/serializers` ou builders: shape de resposta.

No repositorio atual:
- Estrutura ja orientada a caso de uso em `app/services/*`.
- Controllers API em `app/controllers/api/v1/*`.
- Padrao de services documentado em `docs/architecture/service-pattern-api-v1.md`.

## Separacao de responsabilidades

### Models
Devem conter:
- associacoes
- validacoes
- regras locais da entidade

Evitar:
- integracao externa
- workflows longos
- orquestracao de varios aggregates

### Controllers
Devem conter:
- autenticacao/autorizacao
- validacao de parametros
- chamada de service/query/presenter
- mapeamento de erros HTTP

Evitar:
- regra de negocio complexa
- SQL ad-hoc relevante

### Services
Usar quando houver:
- fluxos de negocio com multiplos modelos
- transacoes
- integracoes (ex.: Zabbix)
- normalizacao de payload complexo

Evitar:
- criar service para logica trivial de um metodo
- classes genericas sem responsabilidade (ex.: `ManagerService`)

## Quando usar objetos auxiliares
- Form objects: validacao de entrada complexa fora de AR (quando params excedem controller).
- Query objects: consultas complexas, filtros extensos, performance tuning.
- Presenters/Decorators: composicao de resposta para UI sem poluir model/controller.
- Jobs: tarefas lentas, sincronizacao externa, processamento fora do request.

## Sinais de ma arquitetura
- Controller com dezenas de linhas de negocio.
- Model com responsabilidades de varios dominios.
- Dependencias ciclicas entre services.
- Multipla logica duplicada de payload/status.
- Dificuldade de testar sem subir stack inteira.

## Evolucao sem reescrever tudo
1. Identificar hotspot (alto impacto + baixa seguranca).
2. Extrair um fluxo por vez para service/query/presenter.
3. Cobrir com teste na camada apropriada.
4. Remover duplicacoes apos estabilizar.
5. Repetir incrementalmente.

## Pontos de atencao no projeto atual
- Coexistencia de superficies V2 e legado (`config/routes.rb`): manter compatibilidade.
- Regras multi-tenant (`current_organization`, `OrganizationScoped`) nao podem ser quebradas.
- Fluxos de metricas Zabbix devem preservar `Zabbix::LiveValuesFetcher`.

